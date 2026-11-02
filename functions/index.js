const admin = require("firebase-admin");
const crypto = require("node:crypto");
const xmlbuilder = require("xmlbuilder");
const express = require("express");
/* googleapis is lazy-required inside verifyGooglePlayPurchase to avoid long import time during deploy analysis */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentDeleted, onDocumentCreated, onDocumentUpdated, onDocumentWritten } = require("firebase-functions/v2/firestore");
const { onRequest, onCall, HttpsError } = require("firebase-functions/v2/https");
const { defineSecret } = require("firebase-functions/params");
const logger = require("firebase-functions/logger");
/* nodemailer will be required lazily inside getTransporter to speed up function module load */

admin.initializeApp();
const db = admin.firestore();

// ÖNEMLİ: Burayı kendi alan adınızla değiştirin
const DOMAIN = "https://kisiden.com";
const resendApiKey = defineSecret("RESEND_API_KEY");
const googlePlayServiceAccountJson = defineSecret("GOOGLE_PLAY_SERVICE_ACCOUNT_JSON");
const appleSharedSecret = defineSecret("APPLE_SHARED_SECRET");
const LISTING_ID_PATTERN = /^[A-Za-z0-9_-]{6,128}$/;
const DEFAULT_REWARDED_ANDROID_AD_UNIT_ID = "ca-app-pub-3940256099942544/5224354917";
const DEFAULT_REWARDED_IOS_AD_UNIT_ID = "ca-app-pub-3940256099942544/1712485313";
const trustedNotificationSources = new Set([
  "system",
  "admin_alert",
  "chat_event",
  "listing_event",
  "trade_offer_event",
  "review_event",
]);
const CHAT_RISK_THRESHOLD_MEDIUM = 40;
const CHAT_RISK_THRESHOLD_HIGH = 70;
const CHAT_LEVEL_1_HIGH_24H = 3;
const CHAT_LEVEL_2_HIGH_24H = 5;
const CHAT_LEVEL_3_HIGH_24H = 8;
const CHAT_LEVEL_4_LEVEL3_IN_7D = 3;
const ADMIN_EMAIL_ALLOWLIST = new Set(["hasanmardinn@gmail.com"]);
let admobVerifierKeysCache = { expiresAt: 0, keys: new Map() };

function boundedString(value, maxLength) {
  return typeof value === "string" ? value.trim().slice(0, maxLength) : "";
}

function publicProfileFromUser(userId, user) {
  const proUntil = user.proUntil?.toDate?.() || null;
  const numberOrDefault = (value, fallback = 0) => {
    const number = Number(value);
    return Number.isFinite(number) ? number : fallback;
  };

  return {
    uid: userId,
    name: boundedString(user.name, 120) || "İsimsiz",
    photoUrl: boundedString(user.photoUrl, 2000),
    coverPhotoUrl: boundedString(user.coverPhotoUrl, 2000),
    aboutMe: boundedString(user.aboutMe, 2000),
    contactPreference: ["both", "message_only", "call_only"].includes(user.contactPreference)
      ? user.contactPreference
      : "both",
    instagram: boundedString(user.instagram, 300),
    facebook: boundedString(user.facebook, 300),
    website: boundedString(user.website, 500),
    languageCode: boundedString(user.languageCode, 20) || "tr",
    soldCount: Math.max(0, numberOrDefault(user.soldCount)),
    followerCount: Math.max(0, numberOrDefault(user.followerCount)),
    totalReviewCount: Math.max(0, numberOrDefault(user.totalReviewCount)),
    totalRatingScore: Math.max(0, numberOrDefault(user.totalRatingScore)),
    ratingCount1: Math.max(0, numberOrDefault(user.ratingCount1)),
    ratingCount2: Math.max(0, numberOrDefault(user.ratingCount2)),
    ratingCount3: Math.max(0, numberOrDefault(user.ratingCount3)),
    ratingCount4: Math.max(0, numberOrDefault(user.ratingCount4)),
    ratingCount5: Math.max(0, numberOrDefault(user.ratingCount5)),
    avgResponseHours: Math.max(0, numberOrDefault(user.avgResponseHours, 24)),
    approvalRate: Math.max(0, Math.min(100, numberOrDefault(user.approvalRate, 95))),
    isPro: proUntil !== null && proUntil.getTime() > Date.now(),
    ...(user.createdAt ? { createdAt: user.createdAt } : {}),
  };
}

function isAdminRequest(request) {
  return request.auth?.token?.admin === true || (
    request.auth?.token?.email_verified === true &&
    ADMIN_EMAIL_ALLOWLIST.has(String(request.auth.token.email || "").toLowerCase())
  );
}

exports.syncPublicProfile = onDocumentWritten({
  document: "users/{userId}",
  region: "europe-west1",
}, async (event) => {
  const userId = event.params.userId;
  const userSnapshot = await db.collection("users").doc(userId).get();
  const publicProfileRef = db.collection("public_profiles").doc(userId);
  if (!userSnapshot.exists) {
    await publicProfileRef.delete();
    return;
  }
  await publicProfileRef.set(publicProfileFromUser(userId, userSnapshot.data() || {}));
});

exports.getPublicUserProfile = onCall({
  region: "europe-west1",
  enforceAppCheck: false,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const userId = String(request.data?.userId || "").trim();
  if (!userId || userId.length > 128 || userId.includes("/")) {
    throw new HttpsError("invalid-argument", "Gecersiz kullanici bilgisi.");
  }
  const publicProfileRef = db.collection("public_profiles").doc(userId);
  if (request.data?.refresh !== true) {
    const publicProfileSnapshot = await publicProfileRef.get();
    if (publicProfileSnapshot.exists) {
      return { profile: publicProfileSnapshot.data() };
    }
  }

  const userSnapshot = await db.collection("users").doc(userId).get();
  if (!userSnapshot.exists) return { profile: null };
  const profile = publicProfileFromUser(userId, userSnapshot.data() || {});
  await publicProfileRef.set(profile);
  return {
    profile: {
      ...profile,
      ...(profile.createdAt?.toDate
        ? { createdAt: profile.createdAt.toDate().toISOString() }
        : {}),
    },
  };
});

const WEB_QR_LOGIN_TTL_MS = 2 * 60 * 1000;
const WEB_QR_LOGIN_SESSION_ID_PATTERN = /^[a-f0-9]{64}$/;

function hashWebQrLoginSecret(value) {
  return crypto.createHash("sha256").update(value).digest("hex");
}

function getWebQrLoginInput(request, includeSecret = false) {
  const sessionId = request.data?.sessionId;
  const browserSecret = request.data?.browserSecret;
  if (
    typeof sessionId !== "string" ||
    !WEB_QR_LOGIN_SESSION_ID_PATTERN.test(sessionId)
  ) {
    throw new HttpsError("invalid-argument", "Gecersiz QR oturumu.");
  }
  if (
    includeSecret &&
    (typeof browserSecret !== "string" || !WEB_QR_LOGIN_SESSION_ID_PATTERN.test(browserSecret))
  ) {
    throw new HttpsError("invalid-argument", "Gecersiz web oturum anahtari.");
  }
  return { sessionId, browserSecret };
}

function isValidWebQrLoginSecret(sessionData, browserSecret) {
  const savedHash = sessionData.secretHash;
  if (typeof savedHash !== "string" || !/^[a-f0-9]{64}$/.test(savedHash)) {
    return false;
  }
  const expected = Buffer.from(savedHash, "hex");
  const actual = Buffer.from(hashWebQrLoginSecret(browserSecret), "hex");
  return expected.length === actual.length && crypto.timingSafeEqual(expected, actual);
}

exports.createWebQrLoginSession = onCall({
  region: "europe-west1",
}, async (request) => {
  const ip = request.rawRequest.ip;
  if (typeof ip !== "string" || !ip.trim()) {
    throw new HttpsError("failed-precondition", "QR oturumu baslatilamadi.");
  }

  const now = Date.now();
  const rateLimitId = hashWebQrLoginSecret(ip);
  const rateLimitRef = db.collection("web_qr_login_rate_limits").doc(rateLimitId);
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef);
    const data = snapshot.data() || {};
    const windowStartedAt = data.windowStartedAt?.toMillis?.() || 0;
    const count = now - windowStartedAt < 60_000
      ? Number(data.count) || 0
      : 0;
    if (count >= 10) {
      throw new HttpsError("resource-exhausted", "Cok fazla QR giris istegi.");
    }

    transaction.set(rateLimitRef, {
      count: count + 1,
      windowStartedAt: count === 0
        ? admin.firestore.Timestamp.fromMillis(now)
        : data.windowStartedAt,
      expiresAt: admin.firestore.Timestamp.fromMillis(now + 10 * 60_000),
    });
  });

  const sessionId = crypto.randomBytes(32).toString("hex");
  const browserSecret = crypto.randomBytes(32).toString("hex");
  const expiresAt = admin.firestore.Timestamp.fromMillis(now + WEB_QR_LOGIN_TTL_MS);
  await db.collection("web_qr_login_sessions").doc(sessionId).create({
    secretHash: hashWebQrLoginSecret(browserSecret),
    status: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    expiresAt,
  });

  return { sessionId, browserSecret };
});

exports.approveWebQrLoginSession = onCall({
  region: "europe-west1",
}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId || request.auth.token.firebase?.sign_in_provider === "anonymous") {
    throw new HttpsError("unauthenticated", "Kayitli bir hesapla giris yapin.");
  }
  const { sessionId } = getWebQrLoginInput(request);
  const sessionRef = db.collection("web_qr_login_sessions").doc(sessionId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "QR oturumu bulunamadi.");
    }
    const session = snapshot.data() || {};
    if (!session.expiresAt?.toDate || session.expiresAt.toMillis() <= Date.now()) {
      throw new HttpsError("deadline-exceeded", "QR oturumunun suresi doldu.");
    }
    if (session.status === "approved" && session.approvedUid === userId) return;
    if (session.status !== "pending") {
      throw new HttpsError("failed-precondition", "QR oturumu artik kullanilamiyor.");
    }
    transaction.update(sessionRef, {
      status: "approved",
      approvedUid: userId,
      approvedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { approved: true };
});

exports.completeWebQrLoginSession = onCall({
  region: "europe-west1",
}, async (request) => {
  const { sessionId, browserSecret } = getWebQrLoginInput(request, true);
  const sessionRef = db.collection("web_qr_login_sessions").doc(sessionId);
  const result = await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "QR oturumu bulunamadi.");
    }
    const session = snapshot.data() || {};
    if (!isValidWebQrLoginSecret(session, browserSecret)) {
      throw new HttpsError("permission-denied", "Web oturum anahtari gecersiz.");
    }
    if (!session.expiresAt?.toDate || session.expiresAt.toMillis() <= Date.now()) {
      if (session.status === "pending") {
        transaction.update(sessionRef, { status: "expired" });
      }
      return { status: "expired" };
    }
    if (session.status === "pending") return { status: "pending" };
    if (session.status === "cancelled") return { status: "cancelled" };
    if (session.status === "consumed") return { status: "used" };
    if (session.status === "complete" && typeof session.customToken === "string") {
      return { status: "complete", customToken: session.customToken };
    }
    if (session.status !== "approved" || typeof session.approvedUid !== "string") {
      throw new HttpsError("failed-precondition", "QR oturumu artik kullanilamiyor.");
    }

    const customToken = await admin.auth().createCustomToken(session.approvedUid);
    transaction.update(sessionRef, {
      status: "complete",
      customToken,
      completedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    return { status: "complete", customToken };
  });

  return result;
});

exports.acknowledgeWebQrLoginSession = onCall({
  region: "europe-west1",
}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }
  const { sessionId, browserSecret } = getWebQrLoginInput(request, true);
  const sessionRef = db.collection("web_qr_login_sessions").doc(sessionId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    if (!snapshot.exists) {
      throw new HttpsError("not-found", "QR oturumu bulunamadi.");
    }
    const session = snapshot.data() || {};
    if (!isValidWebQrLoginSecret(session, browserSecret)) {
      throw new HttpsError("permission-denied", "Web oturum anahtari gecersiz.");
    }
    if (session.approvedUid !== userId) {
      throw new HttpsError("permission-denied", "QR oturumu bu hesaba ait degil.");
    }
    if (session.status === "consumed") return;
    if (session.status !== "complete") {
      throw new HttpsError("failed-precondition", "QR oturumu tamamlanmadi.");
    }
    transaction.update(sessionRef, {
      status: "consumed",
      customToken: admin.firestore.FieldValue.delete(),
      consumedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  return { acknowledged: true };
});

exports.cancelWebQrLoginSession = onCall({
  region: "europe-west1",
}, async (request) => {
  const { sessionId, browserSecret } = getWebQrLoginInput(request, true);
  const sessionRef = db.collection("web_qr_login_sessions").doc(sessionId);

  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(sessionRef);
    if (!snapshot.exists) return;
    const session = snapshot.data() || {};
    if (!isValidWebQrLoginSecret(session, browserSecret)) {
      throw new HttpsError("permission-denied", "Web oturum anahtari gecersiz.");
    }
    if (
      session.status === "pending" ||
      session.status === "approved" ||
      session.status === "complete"
    ) {
      transaction.update(sessionRef, {
        status: "cancelled",
        customToken: admin.firestore.FieldValue.delete(),
        cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

  return { cancelled: true };
});

exports.cleanupExpiredWebQrLoginSessions = onSchedule({
  schedule: "every 5 minutes",
  region: "europe-west1",
  timeZone: "UTC",
}, async () => {
  const now = admin.firestore.Timestamp.now();
  for (const collectionName of [
    "web_qr_login_sessions",
    "web_qr_login_rate_limits",
  ]) {
    const collection = db.collection(collectionName);
    let expired = await collection.where("expiresAt", "<=", now).limit(400).get();
    while (!expired.empty) {
      const batch = db.batch();
      expired.docs.forEach((document) => batch.delete(document.ref));
      await batch.commit();
      if (expired.size < 400) break;
      expired = await collection.where("expiresAt", "<=", now).limit(400).get();
    }
  }
});

exports.searchListingTransferRecipients = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  const userId = request.auth?.uid;
  if (!userId) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const searchTerm = boundedString(request.data?.query, 254);
  if (searchTerm.length < 2) {
    throw new HttpsError("invalid-argument", "Aramak icin en az 2 karakter girin.");
  }

  const limitRef = db.collection("listing_transfer_search_limits").doc(userId);
  const dateKey = new Date().toISOString().slice(0, 10);
  await db.runTransaction(async (transaction) => {
    const limitSnapshot = await transaction.get(limitRef);
    const limitData = limitSnapshot.data() || {};
    const lastSearchAt = limitData.lastSearchAt?.toDate?.() || null;
    const dailyCount = limitData.dateKey === dateKey
      ? Number(limitData.dailyCount) || 0
      : 0;

    if (
      dailyCount >= 120 ||
      (lastSearchAt && Date.now() - lastSearchAt.getTime() < 500)
    ) {
      throw new HttpsError("resource-exhausted", "Arama limiti asildi.");
    }

    transaction.set(limitRef, {
      dateKey,
      dailyCount: dailyCount + 1,
      lastSearchAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  const normalizedEmail = searchTerm.toLowerCase();
  const digitsOnly = searchTerm.replace(/\D/g, "");
  const recipients = new Map();
  const addUser = (userId, userData = {}) => {
    if (!userId || userId === request.auth.uid || recipients.has(userId)) return;
    recipients.set(userId, {
      uid: userId,
      name: boundedString(userData.name, 120) || "Isimsiz",
      photoUrl: boundedString(userData.photoUrl, 2000),
    });
  };

  const titleCasedName = searchTerm
    .split(/\s+/)
    .map((part) => part.length === 0
      ? part
      : part[0].toLocaleUpperCase("tr-TR") +
        part.slice(1).toLocaleLowerCase("tr-TR"))
    .join(" ");
  const nameQueries = new Set([
    searchTerm,
    searchTerm.toLocaleLowerCase("tr-TR"),
    searchTerm.toLocaleUpperCase("tr-TR"),
    titleCasedName,
  ]);
  const nameSnapshots = await Promise.all(
    [...nameQueries].map((nameQuery) => db.collection("users")
      .orderBy("name")
      .startAt(nameQuery)
      .endAt(`${nameQuery}\uf8ff`)
      .limit(10)
      .get()),
  );
  for (const snapshot of nameSnapshots) {
    for (const userDoc of snapshot.docs) {
      addUser(userDoc.id, userDoc.data() || {});
    }
  }

  const exactUserIds = new Set();
  if (normalizedEmail.includes("@")) {
    const emailSnapshots = await Promise.all(
      [...new Set([
        searchTerm,
        normalizedEmail,
        normalizedEmail.toLocaleUpperCase("en-US"),
      ])].map((email) => db.collection("users")
        .where("email", "==", email)
        .limit(5)
        .get()),
    );
    for (const snapshot of emailSnapshots) {
      for (const userDoc of snapshot.docs) exactUserIds.add(userDoc.id);
    }
    try {
      const authUser = await admin.auth().getUserByEmail(normalizedEmail);
      exactUserIds.add(authUser.uid);
    } catch (error) {
      if (error.code !== "auth/user-not-found") throw error;
    }
  }

  if (digitsOnly.length >= 7) {
    const phoneCandidates = new Set([searchTerm, digitsOnly, `+${digitsOnly}`]);
    let e164PhoneNumber = "";
    if (searchTerm.startsWith("+") && /^\+[1-9]\d{7,14}$/.test(`+${digitsOnly}`)) {
      e164PhoneNumber = `+${digitsOnly}`;
    } else if (digitsOnly.startsWith("0") && digitsOnly.length === 11) {
      e164PhoneNumber = `+90${digitsOnly.slice(1)}`;
    } else if (digitsOnly.startsWith("90") && digitsOnly.length === 12) {
      e164PhoneNumber = `+${digitsOnly}`;
    } else if (digitsOnly.length === 10) {
      e164PhoneNumber = `+90${digitsOnly}`;
    }
    if (e164PhoneNumber) phoneCandidates.add(e164PhoneNumber);

    const phoneSnapshots = await Promise.all(
      [...phoneCandidates].map((phoneNumber) => db.collection("users")
        .where("phoneNumber", "==", phoneNumber)
        .limit(5)
        .get()),
    );
    for (const snapshot of phoneSnapshots) {
      for (const userDoc of snapshot.docs) exactUserIds.add(userDoc.id);
    }
    if (e164PhoneNumber) {
      try {
        const authUser = await admin.auth().getUserByPhoneNumber(e164PhoneNumber);
        exactUserIds.add(authUser.uid);
      } catch (error) {
        if (error.code !== "auth/user-not-found") throw error;
      }
    }
  }

  if (exactUserIds.size > 0) {
    const exactUserDocs = await db.getAll(
      ...[...exactUserIds].map((id) => db.collection("users").doc(id)),
    );
    for (const userDoc of exactUserDocs) {
      if (userDoc.exists) addUser(userDoc.id, userDoc.data() || {});
    }
  }

  return { users: [...recipients.values()].slice(0, 10) };
});

exports.isPhoneNumberRegistered = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const phoneNumber = String(request.data?.phoneNumber || "").trim();
  if (phoneNumber.length < 7 || phoneNumber.length > 20 || !/^\+?\d+$/.test(phoneNumber)) {
    throw new HttpsError("invalid-argument", "Gecersiz telefon numarasi.");
  }
  const rateLimitRef = db.collection("phone_lookup_limits").doc(request.auth.uid);
  const dateKey = new Date().toISOString().slice(0, 10);
  await db.runTransaction(async (transaction) => {
    const rateLimitSnapshot = await transaction.get(rateLimitRef);
    const rateLimit = rateLimitSnapshot.data() || {};
    const lastLookupAt = rateLimit.lastLookupAt?.toDate?.() || null;
    const dailyCount = rateLimit.dateKey === dateKey
      ? Number(rateLimit.dailyCount) || 0
      : 0;
    if (
      dailyCount >= 20 ||
      (lastLookupAt && Date.now() - lastLookupAt.getTime() < 1500)
    ) {
      throw new HttpsError("resource-exhausted", "Lutfen telefon kontrolu icin bekleyin.");
    }
    transaction.set(rateLimitRef, {
      dateKey,
      dailyCount: dailyCount + 1,
      lastLookupAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });

  const candidates = new Set([phoneNumber]);
  if (phoneNumber.startsWith("+90")) candidates.add(phoneNumber.replace(/^\+90/, "0"));
  if (phoneNumber.startsWith("0") && phoneNumber.length > 10) {
    candidates.add(phoneNumber.replace(/^0/, "+90"));
  }

  for (const candidate of candidates) {
    const match = await db.collection("users")
      .where("phoneNumber", "==", candidate)
      .limit(5)
      .get();
    if (match.docs.some((doc) => doc.id !== request.auth.uid)) {
      return { registered: true };
    }
  }
  return { registered: false };
});

exports.getAdminUserIds = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const adminIds = new Set();
  for (const email of ADMIN_EMAIL_ALLOWLIST) {
    const snapshot = await db.collection("users").where("email", "==", email).get();
    snapshot.docs.forEach((doc) => adminIds.add(doc.id));
  }
  return { userIds: [...adminIds] };
});

exports.setUserBlocked = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const uid = request.auth.uid;
  const blockedUid = String(request.data?.blockedUid || "").trim();
  const blocked = request.data?.blocked;
  if (!blockedUid || blockedUid.length > 128 || blockedUid.includes("/") ||
      blockedUid === uid || typeof blocked !== "boolean") {
    throw new HttpsError("invalid-argument", "Gecersiz engelleme bilgisi.");
  }

  const userRef = db.collection("users").doc(uid);
  const blockedUserRef = db.collection("users").doc(blockedUid);
  const blockedRef = userRef.collection("blocked").doc(blockedUid);
  await db.runTransaction(async (transaction) => {
    const [userSnapshot, blockedUserSnapshot] = await Promise.all([
      transaction.get(userRef),
      transaction.get(blockedUserRef),
    ]);
    if (!userSnapshot.exists || !blockedUserSnapshot.exists) {
      throw new HttpsError("not-found", "Kullanici bulunamadi.");
    }

    transaction.set(userRef, {
      blockedUsers: blocked
        ? admin.firestore.FieldValue.arrayUnion(blockedUid)
        : admin.firestore.FieldValue.arrayRemove(blockedUid),
    }, { merge: true });
    transaction.set(blockedUserRef, {
      blockedBy: blocked
        ? admin.firestore.FieldValue.arrayUnion(uid)
        : admin.firestore.FieldValue.arrayRemove(uid),
    }, { merge: true });
    if (blocked) {
      transaction.set(blockedRef, {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.delete(blockedRef);
    }
  });

  return { success: true };
});

exports.toggleSellerFollow = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const followerId = request.auth.uid;
  const sellerId = String(request.data?.sellerId || "").trim();
  const following = request.data?.following;
  if (!sellerId || sellerId.length > 128 || sellerId.includes("/") ||
      sellerId === followerId || typeof following !== "boolean") {
    throw new HttpsError("invalid-argument", "Gecersiz takip bilgisi.");
  }

  const sellerRef = db.collection("users").doc(sellerId);
  const followerRef = sellerRef.collection("followers").doc(followerId);
  await db.runTransaction(async (transaction) => {
    const [sellerSnapshot, followerSnapshot] = await Promise.all([
      transaction.get(sellerRef),
      transaction.get(followerRef),
    ]);
    if (!sellerSnapshot.exists) {
      throw new HttpsError("not-found", "Satici bulunamadi.");
    }

    const isFollowing = followerSnapshot.exists;
    if (following === isFollowing) return;
    const currentCount = Number(sellerSnapshot.data()?.followerCount) || 0;
    transaction.set(sellerRef, {
      followerCount: Math.max(0, currentCount + (following ? 1 : -1)),
    }, { merge: true });
    if (following) {
      transaction.set(followerRef, {
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      transaction.delete(followerRef);
    }
  });

  return { following };
});

exports.markListingSold = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const sellerId = request.auth.uid;
  const listingId = sanitizeListingId(request.data?.listingId);
  const buyerId = String(request.data?.buyerId || "").trim();
  if (!listingId || !buyerId || buyerId.length > 128 || buyerId.includes("/") ||
      buyerId === sellerId) {
    throw new HttpsError("invalid-argument", "Gecersiz satis bilgisi.");
  }

  const listingRef = db.collection("listings").doc(listingId);
  const sellerRef = db.collection("users").doc(sellerId);
  const buyerRef = db.collection("users").doc(buyerId);
  const permissionRef = sellerRef.collection("review_permissions").doc(buyerId);
  const result = await db.runTransaction(async (transaction) => {
    const [listingSnapshot, sellerSnapshot, buyerSnapshot, permissionSnapshot] =
      await Promise.all([
        transaction.get(listingRef),
        transaction.get(sellerRef),
        transaction.get(buyerRef),
        transaction.get(permissionRef),
      ]);
    if (!listingSnapshot.exists || listingSnapshot.data()?.sellerId !== sellerId) {
      throw new HttpsError("permission-denied", "Bu ilana erisiminiz yok.");
    }
    if (!sellerSnapshot.exists || !buyerSnapshot.exists) {
      throw new HttpsError("not-found", "Satici veya alici bulunamadi.");
    }
    if (permissionSnapshot.exists) {
      if (permissionSnapshot.data()?.listingId !== listingId) {
        throw new HttpsError("already-exists", "Bu alici icin yorum hakki zaten verildi.");
      }
      return {
        sellerName: boundedString(sellerSnapshot.data()?.name, 120) || "Satici",
        listingTitle: boundedString(listingSnapshot.data()?.title, 150),
      };
    }

    const listing = listingSnapshot.data() || {};
    transaction.set(permissionRef, {
      listingId,
      listingTitle: boundedString(listing.title, 150),
      grantedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    transaction.set(sellerRef, {
      soldCount: admin.firestore.FieldValue.increment(1),
    }, { merge: true });
    return {
      sellerName: boundedString(sellerSnapshot.data()?.name, 120) || "Satici",
      listingTitle: boundedString(listing.title, 150),
    };
  });

  return result;
});

exports.aggregateSellerReview = onDocumentCreated({
  document: "users/{sellerId}/reviews/{reviewId}",
  region: "europe-west1",
}, async (event) => {
  const review = event.data?.data();
  const rating = Number(review?.rating);
  if (!Number.isFinite(rating) || rating < 1 || rating > 5) return;

  const sellerId = event.params.sellerId;
  const reviewId = event.params.reviewId;
  const sellerRef = db.collection("users").doc(sellerId);
  const aggregationRef = db.collection("seller_review_aggregations")
    .doc(sha256(`${sellerId}:${reviewId}`));
  await db.runTransaction(async (transaction) => {
    const [sellerSnapshot, aggregationSnapshot] = await Promise.all([
      transaction.get(sellerRef),
      transaction.get(aggregationRef),
    ]);
    if (!sellerSnapshot.exists || aggregationSnapshot.exists) return;

    const ratingCountField = `ratingCount${Math.round(rating)}`;
    const seller = sellerSnapshot.data() || {};
    const currentCount = Number(seller[ratingCountField]) || 0;
    const totalReviewCount = Number(seller.totalReviewCount) || 0;
    const totalRatingScore = Number(seller.totalRatingScore) || 0;
    transaction.set(sellerRef, {
      [ratingCountField]: currentCount + 1,
      totalReviewCount: totalReviewCount + 1,
      totalRatingScore: totalRatingScore + rating,
    }, { merge: true });
    transaction.create(aggregationRef, {
      sellerId,
      reviewId,
      rating,
      aggregatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
});

const chatRiskPatterns = {
  paymentKeyword: /\b(iban|havale|eft)\b/i,
  iban: /\bTR\d{2}\s?(?:\d{4}\s?){5}\d{2}\b/i,
  url: /((https?:\/\/)|(www\.))[^\s]+/i,
  shortener: /\b(bit\.ly|tinyurl\.com|t\.co|shorturl\.at|cutt\.ly)\b/i,
  deposit: /\b(kapora|on\s*odeme|ön\s*ödeme|once\s*havale|önce\s*havale|eft\s*(at|gonder)|havale\s*(at|gonder)|parayi\s*(gonder|at))\b/i,
  offPlatform: /\b(whatsapp|telegram|instagram|dm|baska\s*uygulama|uygulama\s*disi|uygulama\s*disi)\b/i,
  urgency: /\b(hemen\s*gonder|acil\s*odeme|son\s*dakika|firsat\s*kacmasin|fırsat\s*kaçmasın)\b/i,
};

function escapeHtml(raw) {
  return String(raw || "")
    .replace(/&/g, "&amp;")
    .replace(/</g, "&lt;")
    .replace(/>/g, "&gt;")
    .replace(/\"/g, "&quot;")
    .replace(/'/g, "&#39;");
}

function sanitizeListingId(raw) {
  const value = String(raw || "").trim();
  if (!LISTING_ID_PATTERN.test(value)) {
    return null;
  }
  return value;
}

function sha256(value) {
  return crypto.createHash("sha256").update(String(value)).digest("hex");
}

async function getAdMobVerifierKey(keyId, forceRefresh = false) {
  if (forceRefresh || Date.now() >= admobVerifierKeysCache.expiresAt) {
    const response = await fetch("https://www.gstatic.com/admob/reward/verifier-keys.json", {
      signal: AbortSignal.timeout(10000),
    });
    if (!response.ok) {
      throw new Error(`AdMob verifier key request failed (${response.status}).`);
    }
    const payload = await response.json();
    const keys = new Map(
      (Array.isArray(payload.keys) ? payload.keys : [])
        .filter((entry) => Number.isSafeInteger(Number(entry.keyId)) && typeof entry.pem === "string")
        .map((entry) => [String(entry.keyId), entry.pem]),
    );
    if (keys.size === 0) {
      throw new Error("AdMob verifier key response contained no usable keys.");
    }
    admobVerifierKeysCache = {
      expiresAt: Date.now() + 6 * 60 * 60 * 1000,
      keys,
    };
  }
  return admobVerifierKeysCache.keys.get(String(keyId)) || null;
}

function verifyAdMobRewardedCallback(rawQuery, params, publicKey) {
  const signatureIndex = rawQuery.lastIndexOf("&signature=");
  const keyIdIndex = rawQuery.lastIndexOf("&key_id=");
  if (signatureIndex < 0 || keyIdIndex <= signatureIndex) {
    return false;
  }

  const signature = params.get("signature");
  const keyId = params.get("key_id");
  if (
    !signature ||
    !keyId ||
    params.getAll("signature").length !== 1 ||
    params.getAll("key_id").length !== 1 ||
    !rawQuery.slice(signatureIndex, keyIdIndex).startsWith("&signature=") ||
    rawQuery.slice(keyIdIndex + "&key_id=".length).includes("&")
  ) {
    return false;
  }

  const signatureBytes = Buffer.from(signature, "base64url");
  if (signatureBytes.length === 0) {
    return false;
  }
  try {
    return crypto.verify(
      "sha256",
      Buffer.from(rawQuery.slice(0, signatureIndex), "utf8"),
      publicKey,
      signatureBytes,
    );
  } catch {
    return false;
  }
}

function analyzeChatRisk(text) {
  const message = String(text || "").trim();
  if (!message) {
    return { score: 0, level: "none", signals: [] };
  }

  let score = 0;
  const signals = [];

  const paymentKeywordMatches = new Set(
    Array.from(message.matchAll(chatRiskPatterns.paymentKeyword)).map((m) => (m[0] || "").toLowerCase()),
  );

  if (paymentKeywordMatches.size >= 2) {
    score += 45;
    signals.push("IBAN/havale/EFT kombinasyonu tespit edildi");
  } else if (paymentKeywordMatches.size === 1) {
    score += 20;
    signals.push("Ödeme anahtar kelimesi tespit edildi");
  }

  if (chatRiskPatterns.iban.test(message)) {
    score += 45;
    signals.push("IBAN bilgisi tespit edildi");
  }
  if (chatRiskPatterns.url.test(message)) {
    score += 25;
    signals.push("Mesajda dış bağlantı var");
  }
  if (chatRiskPatterns.shortener.test(message)) {
    score += 20;
    signals.push("Kısa link kullanımı tespit edildi");
  }
  if (chatRiskPatterns.deposit.test(message)) {
    score += 35;
    signals.push("Kapora/ön ödeme isteği kalıbı bulundu");
  }
  if (chatRiskPatterns.offPlatform.test(message)) {
    score += 20;
    signals.push("Uygulama dışına yönlendirme ifadesi bulundu");
  }
  if (chatRiskPatterns.urgency.test(message)) {
    score += 10;
    signals.push("Acil ödeme baskısı oluşturan ifade bulundu");
  }

  if (score > 100) score = 100;
  const level = score >= CHAT_RISK_THRESHOLD_HIGH
    ? "high"
    : (score >= CHAT_RISK_THRESHOLD_MEDIUM ? "medium" : (score > 0 ? "low" : "none"));

  return { score, level, signals };
}

function keepRecentMs(values, nowMs, windowMs) {
  return values
    .map((v) => Number(v))
    .filter((v) => Number.isFinite(v) && nowMs - v <= windowMs);
}

async function pushScamShieldNotification(userId, title, message) {
  try {
    await db.collection("users").doc(userId).collection("notifications").add({
      title,
      message,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: "general",
      targetId: "",
      source: "system",
    });
  } catch (e) {
    logger.warn("scam shield notification write failed", e?.message || e);
  }
}

function normalizePurchasePlatform(platformRaw, verificationSourceRaw) {
  const joined = `${String(platformRaw || "")} ${String(verificationSourceRaw || "")}`
    .toLowerCase()
    .trim();
  if (joined.includes("google") || joined.includes("play") || joined.includes("android")) {
    return "android";
  }
  if (joined.includes("app_store") || joined.includes("ios") || joined.includes("apple")) {
    return "ios";
  }
  return "";
}

async function verifyGooglePlayPurchase({ packageName, productId, purchaseToken }) {
  // Lazy-require googleapis to avoid heavy module loading during CLI deploy-time analysis
  const { google } = require("googleapis");

  const rawSecret = googlePlayServiceAccountJson.value();
  if (!rawSecret) {
    throw new HttpsError("failed-precondition", "Google Play servis hesabi sirri tanimli degil.");
  }

  async function consumeGooglePlayPurchase({ packageName, productId, purchaseToken }) {
    const { google } = require("googleapis");
    const rawSecret = googlePlayServiceAccountJson.value();
    if (!rawSecret) {
      throw new HttpsError("failed-precondition", "Google Play servis hesabi sirri tanimli degil.");
    }

    async function acknowledgeGooglePlayPurchase({ packageName, productId, purchaseToken }) {
      const { google } = require("googleapis");
      const credentials = JSON.parse(googlePlayServiceAccountJson.value());
      const auth = new google.auth.GoogleAuth({
        credentials,
        scopes: ["https://www.googleapis.com/auth/androidpublisher"],
      });
      const androidpublisher = google.androidpublisher({ version: "v3", auth });
      await androidpublisher.purchases.products.acknowledge({
        packageName,
        productId,
        token: purchaseToken,
      }, {});
    }
    let credentials;
    try {
      credentials = JSON.parse(rawSecret);
    } catch {
      throw new HttpsError("failed-precondition", "Google Play servis hesabi JSON'i gecersiz.");
    }
    const auth = new google.auth.GoogleAuth({
      credentials,
      scopes: ["https://www.googleapis.com/auth/androidpublisher"],
    });
    const androidpublisher = google.androidpublisher({ version: "v3", auth });
    try {
      await androidpublisher.purchases.products.consume({
        packageName,
        productId,
        token: purchaseToken,
      });
    } catch (error) {
      logger.error("Google Play consume hatasi:", error?.message || error);
      throw new HttpsError("unavailable", "Google Play satin alma tamamlanamadi.");
    }
  }

  let credentials;
  try {
    credentials = JSON.parse(rawSecret);
  } catch {
    throw new HttpsError("failed-precondition", "Google Play servis hesabi JSON'i gecersiz.");
  }

  const auth = new google.auth.GoogleAuth({
    credentials,
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });

  const androidpublisher = google.androidpublisher({ version: "v3", auth });

  let response;
  try {
    response = await androidpublisher.purchases.products.get({
      packageName,
      productId,
      token: purchaseToken,
    });
  } catch (error) {
    logger.error("Google Play dogrulama hatasi:", error?.message || error);
    throw new HttpsError("permission-denied", "Google Play satin alma dogrulanamadi.");
  }

  const data = response?.data || {};
  // 0: Purchased
  if (Number(data.purchaseState) !== 0) {
    throw new HttpsError("permission-denied", "Google Play satin alma durumu gecerli degil.");
  }

  return {
    verificationKey: `gp_${sha256(`${packageName}:${productId}:${purchaseToken}`)}`,
    externalId: String(data.orderId || purchaseToken),
    payload: {
      kind: data.kind || "",
      orderId: data.orderId || "",
      purchaseTimeMillis: data.purchaseTimeMillis || "",
      purchaseState: Number(data.purchaseState || 0),
      acknowledgementState: Number(data.acknowledgementState || 0),
      consumptionState: Number(data.consumptionState || 0),
      regionCode: data.regionCode || "",
    },
  };
}

async function postJson(url, body) {
  const response = await fetch(url, {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
  return response.json();
}

async function verifyApplePurchase({ bundleId, productId, receiptData }) {
  const sharedSecret = appleSharedSecret.value();
  if (!sharedSecret) {
    throw new HttpsError("failed-precondition", "Apple shared secret tanimli degil.");
  }

  const requestBody = {
    "receipt-data": receiptData,
    password: sharedSecret,
    "exclude-old-transactions": true,
  };

  let data = await postJson("https://buy.itunes.apple.com/verifyReceipt", requestBody);
  if (Number(data?.status) === 21007) {
    data = await postJson("https://sandbox.itunes.apple.com/verifyReceipt", requestBody);
  }

  if (Number(data?.status) !== 0) {
    throw new HttpsError("permission-denied", `Apple satin alma dogrulama basarisiz (status=${data?.status ?? "?"}).`);
  }

  const candidates = [
    ...(Array.isArray(data?.latest_receipt_info) ? data.latest_receipt_info : []),
    ...(Array.isArray(data?.receipt?.in_app) ? data.receipt.in_app : []),
  ];

  const matched = candidates.find((entry) =>
    entry &&
    String(entry.product_id || "") === productId &&
    !entry.cancellation_date
  );

  if (!matched) {
    throw new HttpsError("permission-denied", "Apple satin alma kaydi urun ile eslesmedi.");
  }

  const receiptBundleId = String(data?.receipt?.bundle_id || "");
  if (bundleId && receiptBundleId && bundleId !== receiptBundleId) {
    throw new HttpsError("permission-denied", "Apple receipt bundle id eslesmiyor.");
  }

  const txId = String(matched.transaction_id || matched.original_transaction_id || "");
  if (!txId) {
    throw new HttpsError("permission-denied", "Apple transaction kimligi okunamadi.");
  }

  return {
    verificationKey: `as_${sha256(`${bundleId}:${productId}:${txId}`)}`,
    externalId: txId,
    payload: {
      bundleId: receiptBundleId,
      productId: String(matched.product_id || ""),
      transactionId: txId,
      originalTransactionId: String(matched.original_transaction_id || ""),
      purchaseDateMs: String(matched.purchase_date_ms || ""),
      expiresDateMs: String(matched.expires_date_ms || ""),
      environment: String(data?.environment || ""),
    },
  };
}

// --- E-POSTA GÖNDERİMİ (Nodemailer Yapılandırması) ---
function getTransporter() {
  const apiKey = resendApiKey.value();
  if (!apiKey) {
    logger.warn("RESEND_API_KEY secret is not configured; email delivery is skipped.");
    return null;
  }

  // Require nodemailer lazily to avoid heavy module load during functions module import
  const nodemailer = require("nodemailer");

  return nodemailer.createTransport({
    host: "smtp.resend.com",
    port: 465,
    secure: true,
    auth: {
      user: "resend",
      pass: apiKey,
    },
  });
}

function normalizeSupportRequest(data) {
  const input = data && typeof data === "object" ? data : {};
  const name = typeof input.name === "string" ? input.name.trim() : "";
  const email = typeof input.email === "string" ? input.email.trim() : "";
  const topic = typeof input.topic === "string" ? input.topic.trim() : "";
  const message = typeof input.message === "string" ? input.message.trim() : "";

  if (
    name.length < 2 || name.length > 120 ||
    email.length > 254 || !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    topic.length < 2 || topic.length > 120 ||
    message.length < 5 || message.length > 5000
  ) {
    return null;
  }
  return {name, email, topic, message};
}

async function enforceSupportRequestRateLimit(ipAddress) {
  const normalizedIp = String(ipAddress || "").trim();
  if (!normalizedIp) {
    throw new HttpsError("failed-precondition", "Request source could not be verified.");
  }

  const windowKey = new Date().toISOString().slice(0, 13);
  const rateLimitRef = db.collection("support_request_limits").doc(sha256(normalizedIp));
  await db.runTransaction(async (transaction) => {
    const snapshot = await transaction.get(rateLimitRef);
    const data = snapshot.data() || {};
    const requestCount = data.windowKey === windowKey
      ? Number(data.requestCount) || 0
      : 0;
    if (requestCount >= 5) {
      throw new HttpsError(
        "resource-exhausted",
        "Too many support requests. Please try again later.",
      );
    }
    transaction.set(rateLimitRef, {
      windowKey,
      requestCount: requestCount + 1,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
}

async function deliverSupportRequestEmail(supportRequest, requestId) {
  const transporter = getTransporter();
  if (!transporter) return false;

  const escapeHtml = (value) => value.replace(/[&<>"']/g, (character) => ({
    "&": "&amp;",
    "<": "&lt;",
    ">": "&gt;",
    '"': "&quot;",
    "'": "&#39;",
  }[character]));
  await transporter.sendMail({
    from: '"Kisiden Destek" <info@kisiden.com>',
    to: "info@kisiden.com",
    replyTo: supportRequest.email,
    subject: `[Bize Ulaşın] ${supportRequest.topic}`,
    text: `Talep No: ${requestId}\nAd: ${supportRequest.name}\nE-posta: ${supportRequest.email}\nKonu: ${supportRequest.topic}\n\n${supportRequest.message}`,
    html: `
      <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17233d">
        <h2>Yeni Kişiden Bize Ulaşın talebi</h2>
        <p><b>Talep No:</b> ${escapeHtml(requestId)}</p>
        <p><b>Ad:</b> ${escapeHtml(supportRequest.name)}</p>
        <p><b>E-posta:</b> ${escapeHtml(supportRequest.email)}</p>
        <p><b>Konu:</b> ${escapeHtml(supportRequest.topic)}</p>
        <hr>
        <p style="white-space:pre-wrap">${escapeHtml(supportRequest.message)}</p>
      </div>
    `,
  });
  return true;
}

async function createContactRequest(supportRequest, ipAddress) {
  await enforceSupportRequestRateLimit(ipAddress);

  const requestRef = db.collection("contact_requests").doc();
  await requestRef.set({
    name: supportRequest.name,
    email: supportRequest.email,
    topic: supportRequest.topic,
    message: supportRequest.message,
    source: "contact_us",
    status: "open",
    notificationEmailStatus: "pending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  let notificationEmailStatus = "sent";
  try {
    const sent = await deliverSupportRequestEmail(
      supportRequest,
      requestRef.id,
    );
    if (!sent) notificationEmailStatus = "unconfigured";
  } catch (error) {
    notificationEmailStatus = "failed";
    logger.error("Contact request notification email failed", {
      requestId: requestRef.id,
      error,
    });
  }

  if (notificationEmailStatus !== "sent") {
    try {
      await requestRef.update({
        notificationEmailStatus,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (error) {
      logger.error("Contact request notification status update failed", {
        requestId: requestRef.id,
        error,
      });
    }
  }
  return requestRef.id;
}

exports.submitSupportRequest = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
  secrets: [resendApiKey],
}, async (request) => {
  const supportRequest = normalizeSupportRequest(request.data);
  if (!supportRequest) {
    throw new HttpsError("invalid-argument", "Invalid support request.");
  }

  try {
    const requestId = await createContactRequest(
      supportRequest,
      request.rawRequest.ip,
    );
    return {success: true, requestId};
  } catch (error) {
    if (error instanceof HttpsError) throw error;
    logger.error("Contact request could not be stored", error);
    throw new HttpsError("internal", "Unable to send support request.");
  }
});

exports.replyToContactRequest = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
  secrets: [resendApiKey],
}, async (request) => {
  if (!request.auth?.uid || !isAdminRequest(request)) {
    throw new HttpsError("permission-denied", "Admin access required.");
  }

  const requestId = String(request.data?.requestId || "").trim();
  const message = typeof request.data?.message === "string"
    ? request.data.message.trim()
    : "";
  if (
    !/^[A-Za-z0-9_-]{20,128}$/.test(requestId) ||
    message.length < 1 ||
    message.length > 5000
  ) {
    throw new HttpsError("invalid-argument", "Invalid contact request reply.");
  }

  const requestRef = db.collection("contact_requests").doc(requestId);
  const requestSnapshot = await requestRef.get();
  if (!requestSnapshot.exists) {
    throw new HttpsError("not-found", "Contact request not found.");
  }

  const supportRequest = requestSnapshot.data() || {};
  const email = String(supportRequest.email || "").trim();
  const topic = String(supportRequest.topic || "Bize Ulaşın").trim();
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) {
    throw new HttpsError("failed-precondition", "Contact email is invalid.");
  }

  const replyRef = requestRef.collection("replies").doc();
  await replyRef.set({
    message,
    senderId: request.auth.uid,
    status: "sending",
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
  });

  try {
    const transporter = getTransporter();
    if (!transporter) {
      throw new HttpsError("unavailable", "Email service is not configured.");
    }
    const escapeHtml = (value) => value.replace(/[&<>"']/g, (character) => ({
      "&": "&amp;",
      "<": "&lt;",
      ">": "&gt;",
      '"': "&quot;",
      "'": "&#39;",
    }[character]));
    await transporter.sendMail({
      from: '"Kisiden Destek" <info@kisiden.com>',
      to: email,
      replyTo: "info@kisiden.com",
      subject: `[Kişiden Destek] ${topic}`,
      text: `Merhaba ${supportRequest.name || ""},\n\n${message}\n\nÖnceki talebiniz: ${supportRequest.message || ""}\n\nKişiden Destek`,
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17233d">
          <h2>Kişiden Destek yanıtı</h2>
          <p>Merhaba ${escapeHtml(String(supportRequest.name || ""))},</p>
          <p style="white-space:pre-wrap">${escapeHtml(message)}</p>
          <hr>
          <p><b>Önceki talebiniz:</b></p>
          <p style="white-space:pre-wrap">${escapeHtml(String(supportRequest.message || ""))}</p>
          <p>Kişiden Destek</p>
        </div>
      `,
    });

  } catch (error) {
    try {
      await replyRef.update({
        status: "failed",
        failureCode: error instanceof HttpsError ? error.code : "email-failed",
      });
    } catch (statusError) {
      logger.error("Contact request reply status update failed", {
        requestId,
        error: statusError,
      });
    }
    if (error instanceof HttpsError) throw error;
    logger.error("Contact request reply email failed", {requestId, error});
    throw new HttpsError("internal", "Unable to send contact request reply.");
  }

  try {
    const batch = db.batch();
    batch.update(replyRef, {
      status: "sent",
      sentAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batch.update(requestRef, {
      status: "answered",
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastReplyAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    await batch.commit();
  } catch (error) {
    logger.error("Contact request reply sent but status update failed", {
      requestId,
      error,
    });
  }
  return {success: true};
});

exports.supportRequestEmail = onRequest({
  region: "europe-west1",
  secrets: [resendApiKey],
}, async (request, response) => {
  const allowedOrigins = new Set([
    "https://kisiden.com",
    "https://www.kisiden.com",
    "https://kisiden-projesi.web.app",
    "https://kisiden-projesi.firebaseapp.com",
  ]);
  const requestOrigin = request.get("origin");
  if (allowedOrigins.has(requestOrigin)) {
    response.set("Access-Control-Allow-Origin", requestOrigin);
    response.set("Vary", "Origin");
  }
  response.set("Access-Control-Allow-Methods", "POST, OPTIONS");
  response.set("Access-Control-Allow-Headers", "Content-Type");

  if (request.method === "OPTIONS") {
    response.status(204).send("");
    return;
  }
  if (request.method !== "POST") {
    response.status(405).json({error: "Method not allowed"});
    return;
  }

  const body = request.body || {};
  const website = String(body.website || "").trim();

  // Honeypot alanı botların formu kötüye kullanmasını engeller.
  if (website) {
    response.status(204).send("");
    return;
  }
  const supportRequest = normalizeSupportRequest(body);
  if (!supportRequest) {
    response.status(400).json({error: "Invalid support request"});
    return;
  }

  try {
    const requestId = await createContactRequest(supportRequest, request.ip);
    response.status(200).json({success: true, requestId});
  } catch (error) {
    if (error instanceof HttpsError) {
      const status = error.code === "resource-exhausted" ? 429 : 503;
      response.status(status).json({error: error.code});
      return;
    }
    logger.error("Support request email failed", error);
    response.status(500).json({error: "Unable to send support request"});
  }
});

const app = express();

// --- GÜVENLİK KALKANI (Express.js Security Headers) ---
// 1. X-Powered-By bilgisini gizleyerek sunucunun kullandığı teknolojileri hackerlardan saklarız.
app.disable("x-powered-by");

// 2. Sıkı Güvenlik Kuralları (CORS ve XSS Koruması)
app.use((req, res, next) => {
  res.setHeader("Access-Control-Allow-Origin", DOMAIN); // Sadece sizin sitenizden gelen isteklere izin ver
  res.setHeader("Access-Control-Allow-Methods", "GET, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  res.setHeader("X-Content-Type-Options", "nosniff"); // MIME-type sniffing engellemesi
  res.setHeader("X-Frame-Options", "DENY"); // Sitenizin başka bir sitede sahte pencereyle (iframe) açılmasını engeller
  res.setHeader("Referrer-Policy", "strict-origin-when-cross-origin");
  res.setHeader("Permissions-Policy", "geolocation=(), microphone=(), camera=() ");
  res.setHeader("Cross-Origin-Resource-Policy", "same-origin");
  res.setHeader("Content-Security-Policy", "default-src 'self'; img-src 'self' https: data:; style-src 'self' 'unsafe-inline'; script-src 'self' 'unsafe-inline'; frame-ancestors 'none'; base-uri 'self'; form-action 'self'");
  res.setHeader("Strict-Transport-Security", "max-age=31536000; includeSubDomains"); // Zorunlu HTTPS
  if (req.method === "OPTIONS") {
    return res.status(204).send("");
  }
  next();
});

// Basit in-memory rate limiter (instance bazlı) ile aşırı istekleri frenler.
const requestHits = new Map();
app.use((req, res, next) => {
  const now = Date.now();
  const windowMs = 60 * 1000;
  const maxPerWindow = 120;
  const ip = String(req.headers["x-forwarded-for"] || req.ip || "unknown")
    .split(",")[0]
    .trim();

  const entry = requestHits.get(ip) || { count: 0, resetAt: now + windowMs };
  if (now > entry.resetAt) {
    entry.count = 0;
    entry.resetAt = now + windowMs;
  }
  entry.count += 1;
  requestHits.set(ip, entry);

  if (entry.count > maxPerWindow) {
    res.setHeader("Retry-After", "60");
    return res.status(429).send("Too many requests");
  }

  if (requestHits.size > 5000) {
    for (const [k, v] of requestHits.entries()) {
      if (now > v.resetAt) requestHits.delete(k);
    }
  }

  next();
});

// Gelen isteğin bir bot olup olmadığını kontrol eden fonksiyon
const isBot = (userAgent) => {
    if (!userAgent) return false;
    // Yaygın kullanılan botların user-agent listesi
    const botAgents = [
        "googlebot", "bingbot", "yahoo", "duckduckbot", "baiduspider",
        "google-firebase", "yandex", "sogou", "exabot", "facebot", "facebookexternalhit",
        "twitterbot", "linkedinbot", "pinterest", "whatsapp", "telegrambot",
    ];
    return botAgents.some((bot) => userAgent.toLowerCase().includes(bot));
};

function isListingAvailableForSeo(listing, now = new Date()) {
    if (listing.status !== "active") {
        return false;
    }

    const listingRightExpiresAt = listing.listingRightExpiresAt;
    if (
        listingRightExpiresAt &&
        typeof listingRightExpiresAt.toDate === "function"
    ) {
        return !(listingRightExpiresAt.toDate() <= now);
    }

    const createdAt = listing.createdAt;
    if (!createdAt || typeof createdAt.toDate !== "function") {
        return true;
    }

    const thirtyDaysAgo = new Date(now.getTime());
    thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);
    return !(createdAt.toDate() <= thirtyDaysAgo);
}

function seoImageUrl(value) {
    if (typeof value !== "string" || !value.trim()) {
        return null;
    }

    try {
        const imageUrl = new URL(value.trim());
        return imageUrl.protocol === "https:" ? imageUrl.href : null;
    } catch (error) {
        return null;
    }
}

// İlan sayfası için sunucu taraflı render (SSR for Bots)
const renderListingPage = async (req, res) => {
    res.set("Cache-Control", "private, no-store, max-age=0");
    res.vary("User-Agent");

    // Eğer istek bir bottan geliyorsa, SEO için özel HTML oluştur
    if (isBot(req.headers["user-agent"])) {
    const listingId = sanitizeListingId(req.query.id);
        if (!listingId) {
            // ID yoksa ana sayfaya yönlendir
            return res.redirect(301, "/");
        }

        try {
            const doc = await db.collection("listings").doc(listingId).get();
            if (!doc.exists) {
                return res.status(404).send("<!DOCTYPE html><html><head><title>İlan Bulunamadı</title></head><body><h1>404 - İlan Bulunamadı</h1></body></html>");
            }

            const data = doc.data() || {};
            if (!isListingAvailableForSeo(data)) {
                return res.status(404).send(
                    "<!DOCTYPE html><html lang=\"tr\"><head>" +
                    "<meta charset=\"UTF-8\"><title>İlan Bulunamadı</title>" +
                    "</head><body><h1>404 - İlan Bulunamadı</h1></body></html>"
                );
            }

            const url = `${DOMAIN}/ilan?id=${listingId}`;
            const rawTitle = boundedString(data.title, 300) || "Kişiden İlanı";
            const title = escapeHtml(rawTitle);
            let rawDescription = boundedString(data.description, 10000) ||
                "Bu ilanı Kişiden uygulamasında inceleyin.";
            if (rawDescription.length > 160) {
                rawDescription = rawDescription.substring(0, 157) + "...";
            }
            rawDescription = rawDescription.replace(/\r?\n|\r/g, " ");
            const description = escapeHtml(rawDescription);

            const productImageUrl = seoImageUrl(data.imageUrl);
            const imageUrl = escapeHtml(
                productImageUrl || `${DOMAIN}/icons/Icon-512.png`
            );
            const priceValue = typeof data.price === "string"
                ? data.price.trim()
                : data.price;
            const hasPrice = typeof priceValue === "number" ||
                (typeof priceValue === "string" && priceValue.length > 0);
            const price = hasPrice ? Number(priceValue) : NaN;
            const rawSellerName = boundedString(data.sellerName, 120) ||
                "Kişiden Satıcısı";

            // Google Zengin Sonuçlar (Rich Snippets) için JSON-LD Yapısal Verisi
            const jsonLd = {
                "@context": "https://schema.org",
                "@type": "Product",
                "name": rawTitle,
                "description": rawDescription,
                "sku": listingId,
            };
            if (productImageUrl) {
                jsonLd.image = productImageUrl;
            }
            if (Number.isFinite(price) && price >= 0) {
                jsonLd.offers = {
                    "@type": "Offer",
                    "url": url,
                    "priceCurrency": "TRY",
                    "price": price,
                    "availability": "https://schema.org/InStock",
                    "seller": { "@type": "Person", "name": rawSellerName },
                };
            }
            const jsonLdScript = JSON.stringify(jsonLd).replace(/</g, "\\u003c");

            // Bota özel tam HTML sayfası döndür
            const html = `
                <!DOCTYPE html>
                <html lang="tr">
                <head>
                    <meta charset="UTF-8">
                    <title>${title}</title>
                    <meta name="description" content="${description}">
                    <link rel="canonical" href="${url}" />
                    <meta property="og:type" content="product">
                    <meta property="og:title" content="${title}">
                    <meta property="og:description" content="${description}">
                    <meta property="og:image" content="${imageUrl}">
                    <meta property="og:url" content="${url}">
                    <meta name="twitter:card" content="summary_large_image">
                    <meta name="twitter:title" content="${title}">
                    <meta name="twitter:description" content="${description}">
                    <meta name="twitter:image" content="${imageUrl}">
                    <script type="application/ld+json">${jsonLdScript}</script>
                </head>
                <body>
                    <h1>${title}</h1>
                    <img src="${imageUrl}" alt="${title}" />
                    <p>${description}</p>
                    <a href="${url}">İlana git</a>
                </body>
                </html>`;
            return res.status(200).send(html);
        } catch (error) {
            logger.error("SSR Hatası (ilan):", error);
            return res.redirect(302, "/");
        }
    } else {
        // Eğer istek normal bir kullanıcıdan geliyorsa (Bot değilse):
        // Cloud Functions üzerinden "index.html" sunmak "Not Found" hatası verir, 
        // bu yüzden kullanıcıyı mobil intent / mağaza yönlendirmesi yapan bir sayfaya alıyoruz.
        const listingId = sanitizeListingId(req.query.id) || "";
        const html = `
<!DOCTYPE html>
<html lang="tr">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kişiden'e Yönlendiriliyorsunuz...</title>
    <style>
        body { display: flex; justify-content: center; align-items: center; height: 100vh; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; background-color: #f4f6f8; margin: 0; text-align: center; }
        .container { background-color: #fff; padding: 40px; border-radius: 12px; box-shadow: 0 4px 12px rgba(0,0,0,0.1); max-width: 400px; width: 90%; }
        h2 { color: #1a73e8; margin-bottom: 10px; }
        p { color: #555; line-height: 1.5; }
        .spinner { border: 4px solid #f3f3f3; border-top: 4px solid #1a73e8; border-radius: 50%; width: 40px; height: 40px; animation: spin 1s linear infinite; margin: 20px auto; }
        @keyframes spin { 0% { transform: rotate(0deg); } 100% { transform: rotate(360deg); } }
    </style>
    <script>
        const playStoreUrl = "https://play.google.com/store/apps/details?id=com.kisidencom.app";
        const appStoreUrl = "https://apps.apple.com/tr/app/kisiden/id123456789";
        
        const isIOS = /iPad|iPhone|iPod/.test(navigator.userAgent) && !window.MSStream;
        const isAndroid = /Android/.test(navigator.userAgent);
        const listingId = "${listingId}";
        
        window.onload = function() {
            if (isAndroid) {
                // Android Intent: Uygulama yüklüyse ilanı açar, yoksa Play Store'a atar
                let intentUrl = "intent://kisiden.com/ilan?id=" + listingId + "#Intent;scheme=https;package=com.kisidencom.app;S.browser_fallback_url=" + encodeURIComponent(playStoreUrl) + ";end";
                window.location.replace(intentUrl);
            } else if (isIOS) {
                // iOS Scheme: Uygulama yüklüyse açar, yoksa App Store'a atar
                window.location.replace("kisiden://ilan?id=" + listingId);
                setTimeout(function() {
                    window.location.replace(appStoreUrl);
                }, 2500);
            } else {
                // Masaüstü vb. cihazlardan girildiyse Flutter Web anasayfasına yönlendir
                window.location.replace("/?id=" + listingId);
            }
        };
    </script>
</head>
<body>
    <div class="container">
        <div class="spinner"></div>
        <h2>Kişiden</h2>
        <p>İlana yönlendiriliyorsunuz...<br><small>Uygulama yüklü değilse mağazaya yönlendirileceksiniz.</small></p>
    </div>
</body>
</html>
        `;
        return res.status(200).send(html);
    }
};

// Dinamik sitemap.xml oluşturma
const generateSitemap = async (req, res) => {
    res.set("Content-Type", "text/xml");
    const root = xmlbuilder.create("urlset", { version: "1.0", encoding: "UTF-8" });
    root.att("xmlns", "http://www.sitemaps.org/schemas/sitemap/0.9");

    root.ele("url").ele("loc", `${DOMAIN}/`).up().ele("changefreq", "daily").up().ele("priority", "1.0");
    root.ele("url").ele("loc", `${DOMAIN}/privacy.html`).up().ele("changefreq", "monthly").up().ele("priority", "0.8");

    try {
        const snapshot = await db.collection("listings").where("status", "==", "active").get();
        const now = new Date();
        snapshot.forEach((doc) => {
            const listingId = sanitizeListingId(doc.id);
            const listing = doc.data() || {};
            if (!listingId || !isListingAvailableForSeo(listing, now)) {
                return;
            }

            const url = root.ele("url").ele("loc", `${DOMAIN}/ilan?id=${listingId}`).up();
            const lastModified = listing.updatedAt ||
                listing.lastEditChangeSummary?.updatedAt ||
                listing.createdAt;
            if (lastModified && typeof lastModified.toDate === "function") {
                const lastModifiedDate = lastModified.toDate();
                if (Number.isFinite(lastModifiedDate.getTime())) {
                    url.ele("lastmod", lastModifiedDate.toISOString().split("T")[0]);
                }
            }
        });

    } catch (error) {
        logger.error("Sitemap oluşturma hatası:", error);
        return res.status(500).send("Sitemap oluşturulamadı.");
    }

    return res.status(200).send(root.end({ pretty: true }));
};

// Rota tanımlamaları
app.get("/ilan", renderListingPage);
app.get("/sitemap.xml", generateSitemap);

// Ana Cloud Function
exports.seoHandler = onRequest({
  region: "europe-west1",
  cors: false,
  maxInstances: 25,
  timeoutSeconds: 20,
}, app);

// --- YENİ: PRO PAKET YENİLEME HATIRLATICISI (GÜNLÜK CRON JOB) ---
// Her gün Türkiye saati ile 12:00'da çalışır
exports.checkProRenewals = onSchedule({
  schedule: 'every day 12:00',
  timeZone: 'Europe/Istanbul'
}, async (event) => {
  const now = new Date();
  // Şu andan itibaren 3 ile 4 gün arası bir süresi kalanları bul (Tam 3 günü kalanlar)
  const threeDaysLater = new Date(now.getTime() + (3 * 24 * 60 * 60 * 1000));
  const fourDaysLater = new Date(now.getTime() + (4 * 24 * 60 * 60 * 1000));

  try {
    const usersSnap = await admin.firestore().collection('users')
      .where('proUntil', '>=', admin.firestore.Timestamp.fromDate(threeDaysLater))
      .where('proUntil', '<', admin.firestore.Timestamp.fromDate(fourDaysLater))
      .get();

    const promises = [];
    
    usersSnap.forEach(doc => {
      const user = doc.data();
      
      promises.push(admin.firestore().collection('users').doc(doc.id).collection('notifications').add({
        title: "Pro Paketiniz Sona Eriyor! ⏳",
        message: "Pro Mağaza ayrıcalıklarınızın bitmesine sadece 3 gün kaldı. Limitlerinizi kaybetmemek için Pro Mağaza sekmesinden paketinizi yenileyebilirsiniz.",
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: 'general',
        targetId: '',
        source: 'system',
      }));
    });

    await Promise.all(promises);
    console.log(`${usersSnap.size} kullanıcıya yenileme hatırlatması gönderildi.`);
    return null;
  } catch (error) {
    console.error("Zamanlanmış görev hatası:", error);
    return null;
  }
});

// Pro süresi biten kullanıcıların ilanlarındaki eski Pro işaretini temizler.
// Ekranlar yine proUntil tarihini esas alır; bu görev yalnızca denormalize alanı
// güncel tutar.
exports.cleanupExpiredProListings = onSchedule({
  schedule: "every day 01:00",
  timeZone: "Europe/Istanbul",
}, async () => {
  const now = admin.firestore.Timestamp.now();

  try {
    const expiredUsers = await db.collection("users")
      .where("proUntil", "<=", now)
      .get();

    let updatedListings = 0;
    for (const userDoc of expiredUsers.docs) {
      const listings = await db.collection("listings")
        .where("sellerId", "==", userDoc.id)
        .where("isPro", "==", true)
        .get();

      for (let start = 0; start < listings.docs.length; start += 450) {
        const batch = db.batch();
        const chunk = listings.docs.slice(start, start + 450);
        chunk.forEach((listingDoc) => {
          batch.update(listingDoc.ref, { isPro: false });
        });
        await batch.commit();
        updatedListings += chunk.length;
      }
    }

    logger.info("Süresi biten Pro ilanları temizlendi.", {
      expiredUsers: expiredUsers.size,
      updatedListings,
    });
  } catch (error) {
    logger.error("Süresi biten Pro ilanları temizlenemedi.", error);
    throw error;
  }
});

async function deleteDocsByQuery(query, pageSize = 300) {
  while (true) {
    const snap = await query.limit(pageSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    if (snap.size < pageSize) break;
  }
}

async function deleteSubcollectionDocs(parentRef, subcollection, pageSize = 300) {
  while (true) {
    const snap = await parentRef.collection(subcollection).limit(pageSize).get();
    if (snap.empty) break;

    const batch = db.batch();
    snap.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();

    if (snap.size < pageSize) break;
  }
}

async function deleteStoragePrefix(prefix) {
  try {
    await admin.storage().bucket().deleteFiles({ prefix });
  } catch (error) {
    logger.warn(`Storage prefix temizlenemedi (${prefix}):`, error.message || error);
  }
}

exports.deleteMyAccountHard = onCall({
  region: "europe-west1",
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Giris yapilmamis.");
  }

  const uid = request.auth.uid;
  const userRef = db.collection("users").doc(uid);

  // 1) Kullanicinin ilanlarini sil (onListingDeleted tetigi resimleri de temizler)
  const listingsSnap = await db.collection("listings").where("sellerId", "==", uid).get();
  for (const listingDoc of listingsSnap.docs) {
    await deleteSubcollectionDocs(listingDoc.ref, "questions");
    await listingDoc.ref.delete();
  }

  // 1b) Kullanicinin baska ilanlardaki sorularini ve cevaplarini temizle.
  // Cevaplar soru dokumaninda dizi olarak tutuldugu icin tum sorular taranir.
  const questionsGroup = await db.collectionGroup("questions").get();
  let questionBatch = db.batch();
  let questionBatchCount = 0;
  const commitQuestionBatch = async () => {
    if (questionBatchCount === 0) return;
    await questionBatch.commit();
    questionBatch = db.batch();
    questionBatchCount = 0;
  };

  for (const questionDoc of questionsGroup.docs) {
    const question = questionDoc.data() || {};
    const replies = Array.isArray(question.replies) ? question.replies : [];
    const filteredReplies = replies.filter(
      (reply) => !reply || reply.userId !== uid,
    );
    const questionWasAskedByUser = question.userId === uid;
    const repliesChanged = filteredReplies.length !== replies.length;

    if (questionWasAskedByUser) {
      questionBatch.delete(questionDoc.ref);
      questionBatchCount += 1;
    } else if (repliesChanged) {
      questionBatch.update(questionDoc.ref, { replies: filteredReplies });
      questionBatchCount += 1;
    }
    if (questionBatchCount >= 450) {
      await commitQuestionBatch();
    }
  }
  await commitQuestionBatch();

  // 2) Ust seviye kullaniciya bagli kayitlar
  await deleteDocsByQuery(db.collection("search_alarms").where("userId", "==", uid));
  await deleteDocsByQuery(db.collection("reports").where("reporterId", "==", uid));
  await deleteDocsByQuery(db.collection("purchases").where("userId", "==", uid));

  await deleteDocsByQuery(db.collection("trade_offers").where("senderId", "==", uid));
  await deleteDocsByQuery(db.collection("trade_offers").where("receiverId", "==", uid));

  // 3) Ticket + mesajlar
  const ticketSnap = await db.collection("tickets").where("userId", "==", uid).get();
  for (const ticketDoc of ticketSnap.docs) {
    await deleteSubcollectionDocs(ticketDoc.ref, "messages");
    await ticketDoc.ref.delete();
  }

  // 4) Kullaniciyi iceren chat odalari + mesajlar
  const chatSnap = await db.collection("chats").where("participants", "array-contains", uid).get();
  for (const chatDoc of chatSnap.docs) {
    await deleteSubcollectionDocs(chatDoc.ref, "messages");
    await chatDoc.ref.delete();
  }

  // 5) users/{uid} alt koleksiyonlari
  await deleteSubcollectionDocs(userRef, "favorites");
  await deleteSubcollectionDocs(userRef, "blocked");
  await deleteSubcollectionDocs(userRef, "notifications");
  await deleteSubcollectionDocs(userRef, "followers");
  await deleteSubcollectionDocs(userRef, "review_permissions");
  await deleteSubcollectionDocs(userRef, "reviews");

  // 6) Diger kullanicilarin alt koleksiyonlarinda uid ile eslesen kayitlar
  try {
    const followerGroup = await db.collectionGroup("followers").get();
    const batch = db.batch();
    let count = 0;
    followerGroup.docs.forEach((doc) => {
      if (doc.id === uid) {
        batch.delete(doc.ref);
        count += 1;
      }
    });
    if (count > 0) await batch.commit();
  } catch (error) {
    logger.warn("followers collectionGroup temizligi atlandi:", error.message || error);
  }

  try {
    const permsGroup = await db.collectionGroup("review_permissions").get();
    const batch = db.batch();
    let count = 0;
    permsGroup.docs.forEach((doc) => {
      if (doc.id === uid) {
        batch.delete(doc.ref);
        count += 1;
      }
    });
    if (count > 0) await batch.commit();
  } catch (error) {
    logger.warn("review_permissions collectionGroup temizligi atlandi:", error.message || error);
  }

  // 7) Diger kullanicilarin blocked listelerinden cikar
  try {
    const usersSnap = await db.collection("users").get();
    const updates = [];
    usersSnap.docs.forEach((doc) => {
      const data = doc.data() || {};
      const blockedUsers = Array.isArray(data.blockedUsers) ? data.blockedUsers : [];
      const blockedBy = Array.isArray(data.blockedBy) ? data.blockedBy : [];
      if (blockedUsers.includes(uid) || blockedBy.includes(uid)) {
        updates.push(
          doc.ref.set({
            blockedUsers: admin.firestore.FieldValue.arrayRemove(uid),
            blockedBy: admin.firestore.FieldValue.arrayRemove(uid),
          }, { merge: true })
        );
      }
    });
    if (updates.length > 0) {
      await Promise.all(updates);
    }
  } catch (error) {
    logger.warn("blocked listeleri temizlenemedi:", error.message || error);
  }

  // 8) Storage klasorleri
  await deleteStoragePrefix(`listing_images/${uid}/`);
  await deleteStoragePrefix(`tickets/${uid}/`);

  // 9) User doc + Auth user sil
  await userRef.delete().catch(() => null);
  await admin.auth().deleteUser(uid).catch(() => null);

  return { success: true };
});

// --- YENİ: İLAN SÜRESİ (30 GÜN) DOLANLARI VE OTOMATİK YENİLEMELERİ KONTROL EDEN GÖREV ---
// Her gün gece 02:00'da çalışır
exports.checkListingExpirations = onSchedule({
  schedule: 'every day 02:00',
  timeZone: 'Europe/Istanbul'
}, async (event) => {
  const db = admin.firestore();
  const now = new Date();
  const thirtyDaysAgo = new Date(now.getTime());
  thirtyDaysAgo.setDate(thirtyDaysAgo.getDate() - 30);

  try {
    const activeListingsSnap = await db.collection('listings')
      .where('status', '==', 'active')
      .get();

    const expiredListingsSnap = activeListingsSnap.docs.filter(doc => {
      const listing = doc.data();
      const rightExpiresAt = listing.listingRightExpiresAt;
      if (rightExpiresAt && typeof rightExpiresAt.toDate === 'function') {
        return rightExpiresAt.toDate() <= now;
      }
      const createdAt = listing.createdAt;
      if (!createdAt || typeof createdAt.toDate !== 'function') {
        return false;
      }
      return createdAt.toDate() <= thirtyDaysAgo;
    });

    if (expiredListingsSnap.length === 0) {
      console.log("Süresi dolan ilan bulunamadı.");
      return null;
    }

    const batch = db.batch();
    const notificationPromises = [];
    let renewedCount = 0;
    let expiredCount = 0;

    expiredListingsSnap.forEach(doc => {
      const listing = doc.data();
      const sellerId = listing.sellerId;
      const title = listing.title;
      const hasListingRightExpiry = listing.listingRightExpiresAt != null;
      const autoRenew = listing.autoRenew === true;

      if (hasListingRightExpiry) {
        batch.update(doc.ref, {
          status: 'passive',
          listingRightExpiresAt: admin.firestore.FieldValue.delete(),
          listingRightSource: admin.firestore.FieldValue.delete(),
        });
        expiredCount++;
        notificationPromises.push(sendNotification(sellerId, 'İlan Süresi Doldu', `"${title}" başlıklı ek ilan hakkı süresi doldu ve pasife alındı. Tekrar yayınlamak için yeni ilan hakkı satın almanız veya reklam izleyip hak kazanmanız gerekir.`, 'listing', doc.id));
        return;
      }

      if (autoRenew) {
        batch.update(doc.ref, {
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        renewedCount++;
        notificationPromises.push(sendNotification(sellerId, 'İlanınız Yenilendi', `"${title}" başlıklı ilanınızın 30 günlük süresi dolduğu için otomatik olarak yeniden yayına alındı.`, 'listing', doc.id));
      } else {
        batch.update(doc.ref, {
          status: 'passive'
        });
        expiredCount++;
        notificationPromises.push(sendNotification(sellerId, 'İlan Süresi Doldu', `"${title}" başlıklı ilanınızın 30 günlük süresi doldu ve pasife alındı. İsterseniz tekrar yayına alabilirsiniz.`, 'listing', doc.id));
      }
    });

    await batch.commit();
    await Promise.all(notificationPromises);

    console.log(`Otomatik yenilenen ilan sayısı: ${renewedCount}`);
    console.log(`Süresi dolup pasife alınan ilan sayısı: ${expiredCount}`);
    return null;
  } catch (error) {
    console.error("İlan süresi kontrol hatası:", error);
    return null;
  }
});

// Bildirim göndermek için yardımcı fonksiyon
async function sendNotification(userId, title, message, type = 'general', targetId = '') {
  const db = admin.firestore();
  return db.collection('users').doc(userId).collection('notifications').add({
    'title': title, 
    'message': message, 
    'isRead': false, 
    'timestamp': admin.firestore.FieldValue.serverTimestamp(), 
    'type': type, 
    'targetId': targetId,
    'source': 'system',
  });
}

exports.notifyInterestedBuyersAfterListingTransfer = onDocumentUpdated(
  "listing_transfers/{transferId}",
  async (event) => {
    const before = event.data.before.data();
    const after = event.data.after.data();
    if (!before || !after || before.status !== "pending" || after.status !== "accepted") {
      return null;
    }

    const listingId = String(after.listingId || "");
    const listingSnapshot = await db.collection("listings").doc(listingId).get();
    if (!listingSnapshot.exists || listingSnapshot.data()?.sellerId !== after.receiverId) {
      return null;
    }

    const listing = listingSnapshot.data() || {};
    const interestedUserIds = new Set(
      Array.isArray(listing.favoritedBy) ? listing.favoritedBy.filter((id) => typeof id === "string") : [],
    );
    const questions = await db.collection("listings").doc(listingId)
      .collection("questions").limit(100).get();
    for (const question of questions.docs) {
      const userId = question.data().userId;
      if (typeof userId === "string") interestedUserIds.add(userId);
    }
    interestedUserIds.delete(after.senderId);
    interestedUserIds.delete(after.receiverId);

    const recipientIds = [...interestedUserIds].slice(0, 200);
    if (recipientIds.length === 0) return null;
    const userSnapshots = await db.getAll(
      ...recipientIds.map((userId) => db.collection("users").doc(userId)),
    );
    const titleByLanguage = {
      tr: "İlanın yeni satıcısı var",
      en: "This listing has a new seller",
      ar: "أصبح للإعلان بائع جديد",
    };
    const messageByLanguage = {
      tr: `"${String(listing.title || after.listingTitle || "").slice(0, 150)}" ilanı artık başka bir kullanıcı tarafından yönetiliyor. İlgileniyorsanız ilanı açıp yeni satıcıya mesaj gönderebilirsiniz.`,
      en: `"${String(listing.title || after.listingTitle || "").slice(0, 150)}" is now managed by another user. Open the listing if you would like to contact the new seller.`,
      ar: `أصبح الإعلان "${String(listing.title || after.listingTitle || "").slice(0, 150)}" لدى بائع جديد. افتحه إذا كنت ترغب في التواصل معه.`,
    };
    const batch = db.batch();
    userSnapshots.forEach((userSnapshot) => {
      if (!userSnapshot.exists) return;
      const language = String(userSnapshot.data()?.languageCode || "tr");
      const notificationRef = userSnapshot.ref.collection("notifications").doc();
      batch.set(notificationRef, {
        title: titleByLanguage[language] || titleByLanguage.tr,
        message: messageByLanguage[language] || messageByLanguage.tr,
        isRead: false,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "listing",
        targetId: listingId,
        source: "listing_event",
      });
    });
    await batch.commit();
    return null;
  },
);

// --- YENİ: İLAN SİLİNDİĞİNDE STORAGE'DAKİ RESİMLERİ OTOMATİK TEMİZLEYEN GÖREV ---
// Veritabanından (Firestore) bir ilan silindiği an tetiklenir ve o ilana ait tüm fotoğrafları Storage'dan siler.
exports.onListingDeleted = onDocumentDeleted("listings/{listingId}", async (event) => {
  const deletedListing = event.data.data();
  if (!deletedListing) return;

  const allImages = [];
  
  // Ana resmi listeye ekle
  if (deletedListing.imageUrl && typeof deletedListing.imageUrl === 'string') {
    allImages.push(deletedListing.imageUrl);
  }
  
  // Ek resimleri listeye ekle
  if (deletedListing.additionalImages && Array.isArray(deletedListing.additionalImages)) {
    deletedListing.additionalImages.forEach(img => {
      if (img && typeof img === 'string') allImages.push(img);
    });
  }

  if (allImages.length === 0) return;

  const bucket = admin.storage().bucket();
  const deletePromises = [];

  allImages.forEach(url => {
    // Firebase Storage Download URL'sinden dosyanın gerçek yolunu (Path) çıkartıyoruz
    if (url.includes('/o/')) {
      try {
        const decodedUrl = decodeURIComponent(url);
        const filePath = decodedUrl.split('/o/')[1].split('?')[0];
        if (filePath) {
          // Silme işlemini listeye ekle (hata verirse logla ama süreci durdurma)
          deletePromises.push(bucket.file(filePath).delete().catch(e => console.log(`Storage silme hatası (${filePath}):`, e.message)));
        }
      } catch (err) {
        console.error("URL ayrıştırma hatası:", err);
      }
    }
  });

  if (deletePromises.length > 0) {
    await Promise.all(deletePromises);
    console.log(`İlan (${event.params.listingId}) silindi. Toplam ${deletePromises.length} adet resim Storage'dan temizlendi.`);
  }
});

// --- YENİ: FIRESTORE'A EKLENEN BİLDİRİMLERİ FCM (PUSH NOTIFICATION) OLARAK GÖNDEREN GÖREV ---
// Veritabanında bir kullanıcıya yeni bir bildirim eklendiğinde bunu yakalar ve telefona yüksek öncelikli push bildirimi atar.
exports.sendPushNotification = onDocumentCreated({
  document: "users/{userId}/notifications/{notificationId}",
  secrets: [resendApiKey],
}, async (event) => {
  const notificationData = event.data.data();
  const userId = event.params.userId;

  if (!notificationData) return null;
  const source = String(notificationData.source || "");
  if (!trustedNotificationSources.has(source)) {
    logger.warn(`Untrusted notification source blocked: ${source || "(empty)"}`);
    return null;
  }

  try {
    const db = admin.firestore();
    const userDoc = await db.collection("users").doc(userId).get();
    
    if (userDoc.exists) {
      const user = userDoc.data();
      // Kullanıcının FCM token'ı varsa bildirimi gönder
      if (user.fcmToken) {
        const message = {
          notification: {
            title: notificationData.title || "Kişiden",
            body: notificationData.message || "Yeni bir bildiriminiz var.",
            ...(notificationData.imageUrl ? { image: notificationData.imageUrl } : {}),
          },
          android: {
            priority: "high", // Ekran kapalıysa telefonu uyandırır
            notification: {
              sound: "default",
              ...(notificationData.imageUrl ? { imageUrl: notificationData.imageUrl } : {}),
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "default"
              }
            },
            ...(notificationData.imageUrl
              ? { fcm_options: { image: notificationData.imageUrl } }
              : {}),
          },
          data: {
            type: notificationData.type || "general",
            targetId: notificationData.targetId || "",
            messageId: notificationData.messageId || "",
            imageUrl: notificationData.imageUrl || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          token: user.fcmToken
        };

        await admin.messaging().send(message);
      }

      // --- KULLANICIYA E-POSTA İLE BİLDİRİM GÖNDERME ---
      // Eğer kullanıcı e-posta bildirimlerini kapatmamışsa (false değilse) gönder
      if (notificationData.type !== "chat" &&
          user.email && user.email.includes("@") &&
          user.emailNotificationsEnabled !== false) {
        const transporter = getTransporter();
        let actionButton = "";
        const safeTargetId = sanitizeListingId(notificationData.targetId);
        if (notificationData.type === "listing" && safeTargetId) {
          const listingUrl = `${DOMAIN}/ilan?id=${encodeURIComponent(safeTargetId)}`;
          actionButton = `
            <div style="margin-top: 30px; text-align: center;">
              <a href="${escapeHtml(listingUrl)}" style="background-color: #1a73e8; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold; font-size: 16px;">İlanı Görüntüle</a>
            </div>
          `;
        }

        let reasonBlock = "";
        if (notificationData.reason) {
          reasonBlock = `
            <div style="margin: 20px 0; padding: 15px; background-color: #ffebee; border-left: 4px solid #f44336; border-radius: 4px;">
              <p style="margin: 0; color: #d32f2f; font-size: 14px;"><strong>İşlem Detayı/Nedeni:</strong><br>${escapeHtml(notificationData.reason)}</p>
            </div>
          `;
        }

        let imageBlock = "";
        if (notificationData.imageUrl) {
          try {
            const imageUrl = new URL(String(notificationData.imageUrl));
            if (imageUrl.protocol === "https:") {
              imageBlock = `
                <div style="margin: 18px 0 12px;">
                  <img src="${escapeHtml(imageUrl.toString())}" alt="Bildirim görseli" style="width:100%; max-height:260px; object-fit:cover; border-radius:10px; border:1px solid #eeeeee;" />
                </div>
              `;
            }
          } catch (error) {
            logger.warn("Ignoring invalid notification image URL", error?.message || error);
          }
        }

        const emailName = escapeHtml(user.name || "Kullanıcı");
        const emailTitle = escapeHtml(notificationData.title || "Yeni Bildirim");
        const emailMessage = escapeHtml(notificationData.message || "Uygulamada yeni bir bildiriminiz var.");
        const mailOptions = {
          from: '"Kişiden" <info@kisiden.com>',
          to: user.email,
          subject: String(notificationData.title || "Kişiden'den Yeni Bildirim")
            .replace(/[\r\n]+/g, " ")
            .slice(0, 120),
          html: `
            <div style="background-color: #f4f6f8; padding: 30px 10px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.6; color: #333;">
              <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05);">
                <div style="background-color: #1a73e8; padding: 25px; text-align: center;">
                  <img src="${DOMAIN}/icons/Icon-512.png" alt="Kişiden Logo" style="height: 48px; vertical-align: middle; margin-right: 10px; border-radius: 8px;">
                  <h1 style="color: #ffffff; margin: 0; font-size: 26px; letter-spacing: 1px; display: inline-block; vertical-align: middle;">Kişiden</h1>
                </div>
                <div style="padding: 35px 30px;">
                  <p style="font-size: 16px; margin-top: 0;">Merhaba <b>${emailName}</b>,</p>
                  <h3 style="color: #1a73e8; margin-top: 25px; margin-bottom: 10px; font-size: 18px;">${emailTitle}</h3>
                  <p style="font-size: 15px; color: #555; margin-bottom: 30px;">${emailMessage}</p>
                  ${imageBlock}
                  ${reasonBlock}
                  ${actionButton}
                </div>
                <div style="background-color: #f9fafb; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
                  <p style="margin: 0; font-size: 12px; color: #888888;">© ${new Date().getFullYear()} Kişiden. Tüm hakları saklıdır.</p>
                  <p style="margin: 5px 0 0; font-size: 12px; color: #888888;">Bu e-posta uygulamamız tarafından otomatik olarak gönderilmiştir.</p>
                  <p style="margin: 5px 0 0; font-size: 10px; color: #f9fafb;">ID: ${Date.now()}</p>
                </div>
              </div>
            </div>
          `
        };
        if (transporter) {
          transporter.sendMail(mailOptions).catch(e => console.error("E-posta Gönderim Hatası:", e));
        }
      }
    }
  } catch (error) {
    console.error(`FCM Gönderim Hatası (${userId}):`, error);
  }
  return null;
});

// --- YENİ: SOHBET MESAJLARI İÇİN PUSH BİLDİRİMİ GÖNDEREN GÖREV ---
// Veritabanına yeni bir mesaj kaydedildiğinde karşı tarafa sessiz kalmaması için bildirim atar.
exports.sendChatPushNotification = onDocumentCreated({
  document: "chats/{chatId}/messages/{messageId}",
  secrets: [resendApiKey],
}, async (event) => {
  const messageData = event.data.data();
  const chatId = event.params.chatId;

  if (!messageData) return null;
  // 'offer' tipli teklif mesajları zaten üstteki tetikleyici ile genel bildirimlere düşüyor. Çift bildirim gitmemesi için atlıyoruz.
  if (messageData.type === "offer") return null; 

  try {
    const db = admin.firestore();
    const chatDoc = await db.collection("chats").doc(chatId).get();
    if (!chatDoc.exists) return null;
    
    const chatData = chatDoc.data();
    const participants = chatData.participants || [];
    const receiverId = participants.find(id => id !== messageData.senderId);
    
    if (receiverId) {
      const userDoc = await db.collection("users").doc(receiverId).get();
      if (userDoc.exists) {
        const receiverUser = userDoc.data();
        const messageId = event.params.messageId;
        await db.collection("users")
          .doc(receiverId)
          .collection("notifications")
          .doc(`chat_${chatId}_${messageId}`)
          .set({
            type: "chat",
            source: "chat_event",
            targetId: chatId,
            messageId,
            title: messageData.senderName || "Yeni Mesaj",
            message: messageData.message || "Size bir mesaj gönderdi.",
            senderId: messageData.senderId || "",
            isRead: false,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
          });

        // --- KARŞI TARAFA YENİ MESAJI E-POSTA İLE DE BİLDİRME ---
        // Karşı taraf e-posta bildirimlerini kapatmamışsa (false değilse) gönder
        if (receiverUser.email && receiverUser.email.includes("@") && receiverUser.emailNotificationsEnabled !== false) {
          const transporter = getTransporter();
          const listingTitle = chatData.listingTitle || "";
          const listingInfoText = listingTitle ? `<b>"${listingTitle}"</b> başlıklı ilanınızla ilgili ` : '';

          const mailOptions = {
            from: '"Kişiden" <iletisim@kisiden.com>',
            to: receiverUser.email,
            subject: `Kişiden: ${messageData.senderName || "Yeni Mesaj"}`,
            html: `
              <div style="background-color: #f4f6f8; padding: 30px 10px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.6; color: #333;">
                <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05);">
                  <div style="background-color: #1a73e8; padding: 25px; text-align: center;">
                    <img src="${DOMAIN}/icons/Icon-512.png" alt="Kişiden Logo" style="height: 48px; vertical-align: middle; margin-right: 10px; border-radius: 8px;">
                    <h1 style="color: #ffffff; margin: 0; font-size: 26px; letter-spacing: 1px; display: inline-block; vertical-align: middle;">Kişiden</h1>
                  </div>
                  <div style="padding: 35px 30px;">
                    <p style="font-size: 16px; margin-top: 0;">Merhaba <b>${receiverUser.name || 'Kullanıcı'}</b>,</p>
                    <p style="font-size: 15px;"><strong>${messageData.senderName || "Bir kullanıcı"}</strong> size ${listingInfoText}yeni bir mesaj gönderdi:</p>
                    <div style="margin: 25px 0; border-left: 4px solid #1a73e8; background-color: #f8f9fa; padding: 15px 20px; border-radius: 0 6px 6px 0; color: #444; font-style: italic;">
                      "${messageData.message || "Sana Kişiden üzerinden bir mesaj gönderdi."}"
                    </div>
                    <div style="margin-top: 35px; text-align: center;">
                      <a href="${DOMAIN}" style="background-color: #1a73e8; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold; font-size: 16px;">Mesajı Yanıtla</a>
                    </div>
                    <p style="margin-top: 20px; font-size: 13px; color: #777; text-align: center;">
                      Mesajı yanıtlamak için Kişiden uygulamasına giriş yapın.
                    </p>
                  </div>
                  <div style="background-color: #f9fafb; padding: 20px; text-align: center; border-top: 1px solid #eeeeee;">
                    <p style="margin: 0; font-size: 12px; color: #888888;">© ${new Date().getFullYear()} Kişiden. Tüm hakları saklıdır.</p>
                    <p style="margin: 5px 0 0; font-size: 12px; color: #888888;">Lütfen bu e-postaya doğrudan yanıt vermeyin.</p>
                    <p style="margin: 5px 0 0; font-size: 10px; color: #f9fafb;">ID: ${Date.now()}</p>
                  </div>
                </div>
              </div>
            `
          };
          if (transporter) {
            transporter.sendMail(mailOptions).catch(e => console.error("Sohbet E-posta Hatası:", e));
          }
        }
      }
    }
  } catch (error) {
    console.error(`Sohbet FCM Gönderim Hatası:`, error);
  }
  return null;
});

exports.monitorChatRiskAndRestrict = onDocumentCreated({
  document: "chats/{chatId}/messages/{messageId}",
}, async (event) => {
  const messageData = event.data?.data();
  if (!messageData) return null;

  const senderId = String(messageData.senderId || "").trim();
  const rawMessage = String(messageData.message || "");
  if (!senderId || !rawMessage) return null;

  const risk = analyzeChatRisk(rawMessage);
  const messageRef = event.data.ref;

  try {
    await messageRef.set({
      riskScore: risk.score,
      riskLevel: risk.level,
      riskSignals: risk.signals,
      riskAnalyzedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  } catch (e) {
    logger.warn("message risk metadata update failed", e?.message || e);
  }

  if (risk.score < CHAT_RISK_THRESHOLD_MEDIUM) {
    return null;
  }

  const nowMs = Date.now();
  const userRef = db.collection("users").doc(senderId);
  let nextLevel = 0;
  let high24hCount = 0;
  let medium24hCount = 0;
  let action = "warn_only";
  let reportForAdmin = false;

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) return;

    const data = userSnap.data() || {};
    const previousLevel = Number(data.scamShieldLevel || 0);
    const highEvents = keepRecentMs(data.scamShieldHighEvents || [], nowMs, 24 * 60 * 60 * 1000);
    const mediumEvents = keepRecentMs(data.scamShieldMediumEvents || [], nowMs, 24 * 60 * 60 * 1000);
    const level3Events = keepRecentMs(data.scamShieldLevel3Events || [], nowMs, 7 * 24 * 60 * 60 * 1000);

    if (risk.score >= CHAT_RISK_THRESHOLD_HIGH) {
      highEvents.push(nowMs);
    } else {
      mediumEvents.push(nowMs);
    }

    high24hCount = highEvents.length;
    medium24hCount = mediumEvents.length;

    let mutedUntilDate = data.chatMutedUntil?.toDate ? data.chatMutedUntil.toDate() : null;
    let newChatBlockedUntilDate = data.chatNewThreadBlockedUntil?.toDate
      ? data.chatNewThreadBlockedUntil.toDate()
      : null;

    const setMutedUntil = (futureDate) => {
      if (!mutedUntilDate || futureDate.getTime() > mutedUntilDate.getTime()) {
        mutedUntilDate = futureDate;
      }
      if (!newChatBlockedUntilDate || futureDate.getTime() > newChatBlockedUntilDate.getTime()) {
        newChatBlockedUntilDate = futureDate;
      }
    };

    let reviewRequired = data.scamShieldReviewRequired === true;

    if (high24hCount >= CHAT_LEVEL_3_HIGH_24H) {
      nextLevel = Math.max(nextLevel, 3);
      if (previousLevel < 3) {
        level3Events.push(nowMs);
      }
      setMutedUntil(new Date(nowMs + 24 * 60 * 60 * 1000));
      action = "mute_24h";
      reportForAdmin = previousLevel < 3;
    } else if (high24hCount >= CHAT_LEVEL_2_HIGH_24H) {
      nextLevel = Math.max(nextLevel, 2);
      setMutedUntil(new Date(nowMs + 30 * 60 * 1000));
      action = "cooldown_30m";
    } else if (high24hCount >= CHAT_LEVEL_1_HIGH_24H) {
      nextLevel = Math.max(nextLevel, 1);
      action = "confirm_required";
    }

    const recentLevel3Count = level3Events.length;
    if (recentLevel3Count >= CHAT_LEVEL_4_LEVEL3_IN_7D) {
      nextLevel = 4;
      reviewRequired = true;
      setMutedUntil(new Date(nowMs + 7 * 24 * 60 * 60 * 1000));
      action = "review_required";
      reportForAdmin = true;
    }

    const finalLevel = Math.max(previousLevel, nextLevel);

    const patch = {
      scamShieldLevel: finalLevel,
      scamShieldHighEvents: highEvents.slice(-100),
      scamShieldMediumEvents: mediumEvents.slice(-120),
      scamShieldLevel3Events: level3Events.slice(-30),
      scamShieldLastRiskScore: risk.score,
      scamShieldLastRiskLevel: risk.level,
      scamShieldLastRiskSignals: risk.signals,
      scamShieldLastRiskAt: admin.firestore.FieldValue.serverTimestamp(),
      scamShieldHighRiskCount24h: highEvents.length,
      scamShieldMediumRiskCount24h: mediumEvents.length,
      scamShieldReviewRequired: reviewRequired,
      scamShieldLastAction: action,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (mutedUntilDate) {
      patch.chatMutedUntil = admin.firestore.Timestamp.fromDate(mutedUntilDate);
    }
    if (newChatBlockedUntilDate) {
      patch.chatNewThreadBlockedUntil = admin.firestore.Timestamp.fromDate(newChatBlockedUntilDate);
    }

    tx.set(userRef, patch, { merge: true });
  });

  if (action === "confirm_required") {
    await pushScamShieldNotification(
      senderId,
      "Güvenlik Uyarısı",
      "Son mesajlarınızda riskli ifadeler tespit edildi. Uygulama dışı ödeme ve kapora taleplerinden kaçının.",
    );
  } else if (action === "cooldown_30m") {
    await pushScamShieldNotification(
      senderId,
      "Sohbet Koruma Modu",
      "Tekrarlayan riskli mesajlar nedeniyle sohbetiniz 30 dakika kısıtlandı.",
    );
  } else if (action === "mute_24h") {
    await pushScamShieldNotification(
      senderId,
      "24 Saat Kısıt",
      "Yüksek riskli mesaj tekrarlarından dolayı sohbet erişiminiz 24 saat kısıtlandı.",
    );
  } else if (action === "review_required") {
    await pushScamShieldNotification(
      senderId,
      "Hesap İncelemesi",
      "Tekrarlayan yüksek riskli davranış nedeniyle hesabınız güvenlik incelemesine alındı.",
    );
  }

  if (reportForAdmin) {
    await db.collection("reports").add({
      reporterId: senderId,
      listingId: "",
      reason: `ScamShield auto report: level=${nextLevel}, high24h=${high24hCount}, medium24h=${medium24hCount}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: "scam_shield",
      systemGenerated: true,
      riskScore: risk.score,
      riskSignals: risk.signals,
    });
  }

  return null;
});

exports.checkChatRestrictions = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Giris yapilmamis.");
  }

  const uid = request.auth.uid;
  const userSnap = await db.collection("users").doc(uid).get();
  if (!userSnap.exists) {
    return {
      canSend: true,
      canStartNewChat: true,
      level: 0,
      reasonKey: "",
      reason: "",
      secondsLeft: 0,
    };
  }

  const data = userSnap.data() || {};
  const nowMs = Date.now();
  const mutedUntil = data.chatMutedUntil?.toDate ? data.chatMutedUntil.toDate().getTime() : 0;
  const blockedUntil = data.chatNewThreadBlockedUntil?.toDate
    ? data.chatNewThreadBlockedUntil.toDate().getTime()
    : 0;
  const reviewRequired = data.scamShieldReviewRequired === true;
  const level = Number(data.scamShieldLevel || 0);

  const canSend = !reviewRequired && mutedUntil <= nowMs;
  const canStartNewChat = !reviewRequired && blockedUntil <= nowMs;
  const activeUntil = Math.max(mutedUntil, blockedUntil);
  const secondsLeft = activeUntil > nowMs ? Math.ceil((activeUntil - nowMs) / 1000) : 0;

  let reasonKey = "";
  let reason = "";
  if (reviewRequired) {
    reasonKey = "chat_restriction_review_required";
    reason = "Hesabınız güvenlik incelemesinde. Lütfen destek ile iletişime geçin.";
  } else if (!canSend) {
    reasonKey = "chat_restriction_temporary_active";
    reason = "Geçici sohbet kısıtı aktif. Bir süre sonra tekrar deneyin.";
  } else if (level >= 1) {
    reasonKey = "chat_restriction_safety_notice";
    reason = "Güvenlik nedeniyle uygulama dışı ödeme ve kapora taleplerinden kaçının.";
  }

  return {
    canSend,
    canStartNewChat,
    level,
    reasonKey,
    reason,
    secondsLeft,
  };
});

exports.startListingRewardChallenge = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const uid = request.auth.uid;
  const adUnitId = String(request.data?.adUnitId || "").trim();
  const settingsSnap = await db.collection("settings").doc("listing_rights").get();
  const settings = settingsSnap.exists ? (settingsSnap.data() || {}) : {};
  if (settings.rewardedAdsEnabled === false) {
    throw new HttpsError("failed-precondition", "Odullu reklamlar su anda kapali.");
  }
  const allowedAdUnits = new Set([
    String(settings.rewardedAndroidAdUnitId || DEFAULT_REWARDED_ANDROID_AD_UNIT_ID).trim(),
    String(settings.rewardedIosAdUnitId || DEFAULT_REWARDED_IOS_AD_UNIT_ID).trim(),
  ].filter(Boolean));
  if (!adUnitId || !allowedAdUnits.has(adUnitId)) {
    throw new HttpsError("permission-denied", "Gecersiz odullu reklam birimi.");
  }

  const userRef = db.collection("users").doc(uid);
  const challengeId = crypto.randomBytes(24).toString("hex");
  const challengeRef = db.collection("listing_reward_challenges").doc(challengeId);
  const now = new Date();
  const dailyMax = Math.max(1, Math.min(50, Number(settings.rewardDailyMax) || 3));
  const cooldownMinutes = Math.max(1, Math.min(1440, Number(settings.rewardCooldownMinutes) || 1));
  const dateKey = now.toISOString().slice(0, 10);

  await db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Kullanici bulunamadi.");
    }
    const user = userSnap.data() || {};
    const lastChallengeAt = user.lastRewardChallengeAt?.toDate?.() || null;
    if (lastChallengeAt && now.getTime() - lastChallengeAt.getTime() < 5000) {
      throw new HttpsError("resource-exhausted", "Cok hizli istek atildi. Lutfen tekrar deneyin.");
    }
    const lastListingGrantAt = user.lastListingRightsGrantAt?.toDate?.() || null;
    if (lastListingGrantAt && now.getTime() - lastListingGrantAt.getTime() < 5000) {
      throw new HttpsError("resource-exhausted", "Cok hizli istek atildi. Lutfen tekrar deneyin.");
    }

    const dailyCount = user.rewardAdDailyDate === dateKey
      ? Number(user.rewardAdDailyCount) || 0
      : 0;
    if (dailyCount >= dailyMax) {
      throw new HttpsError("resource-exhausted", `Gunluk reklam hakkinizi doldurdunuz (${dailyMax}).`);
    }
    const lastGrantAt = user.rewardAdLastGrantAt?.toDate?.() || null;
    if (lastGrantAt && now.getTime() - lastGrantAt.getTime() < cooldownMinutes * 60 * 1000) {
      throw new HttpsError("resource-exhausted", `Yeni reklam hakki icin ${cooldownMinutes} dakika bekleyin.`);
    }

    tx.set(challengeRef, {
      userId: uid,
      challengeId,
      adUnitId,
      status: "pending",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      expiresAt: admin.firestore.Timestamp.fromDate(new Date(now.getTime() + 24 * 60 * 60 * 1000)),
    });
    tx.set(userRef, {
      lastRewardChallengeAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { challengeId, customData: challengeId };
});

exports.cancelListingRewardChallenge = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const challengeId = String(request.data?.challengeId || "").trim();
  if (!/^[a-f0-9]{48}$/.test(challengeId)) {
    throw new HttpsError("invalid-argument", "Gecersiz reklam oturumu.");
  }

  const challenges = db.collection("listing_reward_challenges");
  const challengeRef = challenges.doc(challengeId);
  const legacyChallengeRef = challenges.doc(request.auth.uid);
  await db.runTransaction(async (tx) => {
    const [challengeSnap, legacyChallengeSnap] = await Promise.all([
      tx.get(challengeRef),
      tx.get(legacyChallengeRef),
    ]);
    const activeChallengeRef = challengeSnap.exists
      ? challengeRef
      : legacyChallengeRef;
    const activeChallengeSnap = challengeSnap.exists
      ? challengeSnap
      : legacyChallengeSnap;
    if (!activeChallengeSnap.exists) return;

    const challenge = activeChallengeSnap.data() || {};
    if (
      challenge.userId === request.auth.uid &&
      challenge.challengeId === challengeId &&
      challenge.status === "pending"
    ) {
      tx.delete(activeChallengeRef);
    }
  });

  return { success: true };
});

exports.cleanupExpiredListingRewardChallenges = onSchedule({
  schedule: "every 24 hours",
  region: "europe-west1",
  timeZone: "Etc/UTC",
}, async () => {
  const now = admin.firestore.Timestamp.now();
  let deletedCount = 0;
  while (deletedCount < 5000) {
    const expiredChallenges = await db.collection("listing_reward_challenges")
      .where("expiresAt", "<=", now)
      .orderBy("expiresAt")
      .limit(500)
      .get();
    if (expiredChallenges.empty) break;

    const batch = db.batch();
    expiredChallenges.docs.forEach((challenge) => batch.delete(challenge.ref));
    await batch.commit();
    deletedCount += expiredChallenges.size;
    if (expiredChallenges.size < 500) break;
  }
  logger.info("Expired listing reward challenges cleaned up", { deletedCount });
});

exports.admobRewardedSsv = onRequest({
  region: "europe-west1",
  cors: false,
}, async (request, response) => {
  if (request.method !== "GET") {
    response.status(405).send("Method not allowed");
    return;
  }

  const rawQuery = String(request.originalUrl || "").split("?").slice(1).join("?");
  const params = new URLSearchParams(rawQuery);
  const keyId = params.get("key_id");
  const signature = params.get("signature");
  if (!keyId || !signature) {
    response.status(400).send("Missing signature parameters");
    return;
  }

  let publicKey;
  try {
    publicKey = await getAdMobVerifierKey(keyId);
    if (!publicKey) {
      publicKey = await getAdMobVerifierKey(keyId, true);
    }
  } catch (error) {
    logger.error("Unable to retrieve AdMob verifier keys", error);
    response.status(503).send("Verifier keys unavailable");
    return;
  }
  if (!publicKey || !verifyAdMobRewardedCallback(rawQuery, params, publicKey)) {
    response.status(403).send("Invalid AdMob signature");
    return;
  }

  const uid = String(params.get("user_id") || "").trim();
  const challengeId = String(params.get("custom_data") || "").trim();
  const adUnitId = String(params.get("ad_unit") || "").trim();
  const transactionId = String(params.get("transaction_id") || "").trim();
  if (
    !uid ||
    uid.length > 128 ||
    uid.includes("/") ||
    !/^[a-f0-9]{48}$/.test(challengeId) ||
    !adUnitId ||
    !transactionId ||
    transactionId.length > 256
  ) {
    logger.warn("Verified AdMob callback is missing required reward fields.");
    response.status(200).send("Ignored");
    return;
  }

  const settingsSnap = await db.collection("settings").doc("listing_rights").get();
  const settings = settingsSnap.exists ? (settingsSnap.data() || {}) : {};
  const dailyMax = Math.max(1, Math.min(50, Number(settings.rewardDailyMax) || 3));
  const cooldownMinutes = Math.max(1, Math.min(1440, Number(settings.rewardCooldownMinutes) || 1));
  const challengeRef = db.collection("listing_reward_challenges").doc(challengeId);
  const legacyChallengeRef = db.collection("listing_reward_challenges").doc(uid);
  const userRef = db.collection("users").doc(uid);
  const transactionRef = db.collection("admob_reward_transactions").doc(sha256(transactionId));
  const purchaseRef = db.collection("purchases").doc(`admob_${sha256(transactionId)}`);
  const now = new Date();
  const dateKey = now.toISOString().slice(0, 10);

  try {
    const result = await db.runTransaction(async (tx) => {
      const [
        challengeSnap,
        legacyChallengeSnap,
        userSnap,
        transactionSnap,
      ] = await Promise.all([
        tx.get(challengeRef),
        tx.get(legacyChallengeRef),
        tx.get(userRef),
        tx.get(transactionRef),
      ]);
      if (transactionSnap.exists) {
        return "duplicate";
      }
      const activeChallengeRef = challengeSnap.exists
        ? challengeRef
        : legacyChallengeRef;
      const activeChallengeSnap = challengeSnap.exists
        ? challengeSnap
        : legacyChallengeSnap;
      if (!activeChallengeSnap.exists || !userSnap.exists) {
        return "invalid";
      }

      const challenge = activeChallengeSnap.data() || {};
      const user = userSnap.data() || {};
      const expiresAt = challenge.expiresAt?.toDate?.();
      if (
        challenge.status !== "pending" ||
        challenge.userId !== uid ||
        challenge.challengeId !== challengeId ||
        ![
          challenge.adUnitId,
          String(challenge.adUnitId || "").split("/").pop(),
        ].includes(adUnitId) ||
        !expiresAt ||
        expiresAt.getTime() < now.getTime()
      ) {
        return "invalid";
      }

      const dailyCount = user.rewardAdDailyDate === dateKey
        ? Number(user.rewardAdDailyCount) || 0
        : 0;
      if (dailyCount >= dailyMax) {
        tx.update(activeChallengeRef, { status: "rejected", rejectionReason: "daily_limit" });
        return "limit";
      }
      const lastGrantAt = user.rewardAdLastGrantAt?.toDate?.() || null;
      if (lastGrantAt && now.getTime() - lastGrantAt.getTime() < cooldownMinutes * 60 * 1000) {
        tx.update(activeChallengeRef, { status: "rejected", rejectionReason: "cooldown" });
        return "limit";
      }

      const lastGenericGrantAt = user.lastListingRightsGrantAt?.toDate?.() || null;
      if (lastGenericGrantAt && now.getTime() - lastGenericGrantAt.getTime() < 5000) {
        tx.update(activeChallengeRef, { status: "rejected", rejectionReason: "rate_limit" });
        return "limit";
      }

      const proUntil = user.proUntil?.toDate?.() || null;
      const hasActivePro = !!proUntil && proUntil.getTime() > now.getTime();
      const proLimit = Number(user.proListingLimit) || 10;
      const baseLimit = hasActivePro ? Math.max(10, proLimit) : 10;
      const adminListingLimitRaw = Number(user.adminListingLimit) || 0;
      const adminExtraListingLimit = Number(user.adminExtraListingLimit) || 0;
      const derivedExtraFromLimit = adminListingLimitRaw > 0
        ? Math.max(0, adminListingLimitRaw - baseLimit)
        : 0;
      const nextExtraBalance = Math.max(adminExtraListingLimit, derivedExtraFromLimit) + 1;
      const newTotalLimit = baseLimit + nextExtraBalance;

      tx.set(userRef, {
        adminListingLimit: newTotalLimit,
        adminExtraListingLimit: nextExtraBalance,
        rewardAdDailyDate: dateKey,
        rewardAdDailyCount: dailyCount + 1,
        rewardAdLastGrantAt: admin.firestore.FieldValue.serverTimestamp(),
        lastListingRightsGrantAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, { merge: true });
      tx.create(transactionRef, {
        userId: uid,
        challengeId,
        adUnitId,
        transactionId,
        rewardedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      tx.create(purchaseRef, {
        userId: uid,
        userName: user.name || "Isimsiz",
        userEmail: user.email || "",
        packageId: "rewarded_ad_1",
        price: "Rewarded Ad",
        days: 0,
        addedListingLimit: 1,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        type: "Reklam Izleme Ilan Hakki",
        mode: "rewarded_ssv",
        purchaseId: transactionId,
        purchasePlatform: "admob",
        verifiedByServer: true,
      });
      tx.delete(activeChallengeRef);
      return "granted";
    });

    response.status(200).send(result === "granted" ? "Reward granted" : "Ignored");
  } catch (error) {
    logger.error("AdMob rewarded SSV processing failed", error);
    response.status(500).send("Reward processing failed");
  }
});

// --- YENI: UCRETLI ILAN HAKKI TANIMLAMA (GUVENLI CALLABLE) ---
exports.grantListingRights = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
  secrets: [googlePlayServiceAccountJson, appleSharedSecret],
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const uid = request.auth.uid;
  const isAdmin = request.auth.token?.admin === true;
  const mode = String(request.data?.mode || "");
  const requestedProductId = String(request.data?.productId || "");
  const requestedPriceText = String(request.data?.priceText || "");
  const purchaseId = String(request.data?.purchaseId || "").trim();
  const purchasePlatformInput = String(request.data?.purchasePlatform || "").trim();
  const verificationData = request.data?.verificationData || {};
  const verificationSource = String(verificationData.source || "");
  const purchasePlatform = normalizePurchasePlatform(purchasePlatformInput, verificationSource);
  const serverVerificationData = String(verificationData.serverVerificationData || "").trim();
  const localVerificationData = String(verificationData.localVerificationData || "").trim();

  if (requestedProductId.length > 120 || requestedPriceText.length > 120) {
    throw new HttpsError("invalid-argument", "Gecersiz paket parametresi.");
  }

  let grantCount = 0;
  let packageId = "";
  let actionType = "";
  let priceText = "";
  let verificationRef = null;
  let verificationPayload = null;
  let externalPurchaseId = purchaseId;

  const listingRightsSettingsSnap = await db.collection("settings").doc("listing_rights").get();
  const listingRightsSettings = listingRightsSettingsSnap.exists
    ? (listingRightsSettingsSnap.data() || {})
    : {};

  if (mode === "paid_package") {
    if (!isAdmin && !purchasePlatform) {
      throw new HttpsError("invalid-argument", "Satin alma platformu anlasilamadi.");
    }

    const rawPackages = Array.isArray(listingRightsSettings.paidPackages)
      ? listingRightsSettings.paidPackages
      : [];

    const matched = rawPackages.find((p) =>
      p &&
      typeof p === "object" &&
      String(p.productId || "").trim() === requestedProductId
    );

    if (!matched) {
      throw new HttpsError("permission-denied", "Bu paket aktif degil veya tanimli degil.");
    }

    grantCount = Number(matched.grantCount || 0);
    if (!Number.isFinite(grantCount) || grantCount <= 0 || grantCount > 20) {
      throw new HttpsError("invalid-argument", "Paket ilan hakki tanimi gecersiz.");
    }

    packageId = requestedProductId;
    actionType = "Ilan Hakki Paketi";
    priceText = requestedPriceText || "Play Billing";

    if (!isAdmin) {
      if (purchasePlatform === "android") {
        if (!serverVerificationData) {
          throw new HttpsError("invalid-argument", "Google Play satin alma token'i eksik.");
        }
        const packageName = String(listingRightsSettings.androidPackageName || "com.kisidencom.app").trim();
        const verified = await verifyGooglePlayPurchase({
          packageName,
          productId: requestedProductId,
          purchaseToken: serverVerificationData,
        });
        verificationRef = db.collection("purchase_verifications").doc(verified.verificationKey);
        verificationPayload = verified.payload;
        externalPurchaseId = verified.externalId || externalPurchaseId;
      } else if (purchasePlatform === "ios") {
        const receiptData = localVerificationData || serverVerificationData;
        if (!receiptData) {
          throw new HttpsError("invalid-argument", "Apple receipt verisi eksik.");
        }
        const bundleId = String(listingRightsSettings.iosBundleId || "com.kisidencom.app").trim();
        const verified = await verifyApplePurchase({
          bundleId,
          productId: requestedProductId,
          receiptData,
        });
        verificationRef = db.collection("purchase_verifications").doc(verified.verificationKey);
        verificationPayload = verified.payload;
        externalPurchaseId = verified.externalId || externalPurchaseId;
      } else {
        throw new HttpsError("invalid-argument", "Desteklenmeyen satin alma platformu.");
      }
    }
  } else {
    throw new HttpsError("invalid-argument", "Gecersiz hak tanimlama modu.");
  }

  const userRef = db.collection("users").doc(uid);
  const purchasesRef = db.collection("purchases").doc();

  const result = await db.runTransaction(async (tx) => {
    if (verificationRef) {
      const verificationSnap = await tx.get(verificationRef);
      if (verificationSnap.exists) {
        const existing = verificationSnap.data() || {};
        if (existing.usedBy) {
          throw new HttpsError("already-exists", "Bu satin alma daha once kullanildi.");
        }
      }
    }

    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) {
      throw new HttpsError("not-found", "Kullanici bulunamadi.");
    }

    const user = userSnap.data() || {};

    const nowDate = new Date();
    const lastGenericGrantAt = user.lastListingRightsGrantAt
      ? user.lastListingRightsGrantAt.toDate()
      : null;
    if (lastGenericGrantAt) {
      const diffMs = nowDate.getTime() - lastGenericGrantAt.getTime();
      if (diffMs < 5000) {
        throw new HttpsError("resource-exhausted", "Cok hizli istek atildi. Lutfen tekrar deneyin.");
      }
    }

    const adminListingLimitRaw = Number(user.adminListingLimit || 0);
    const adminExtraListingLimit = Number(user.adminExtraListingLimit || 0);
    const proLimit = Number(user.proListingLimit || 10);
    const hasActivePro =
      !!user.proUntil && user.proUntil.toDate && user.proUntil.toDate().getTime() > Date.now();

    const baseLimit = hasActivePro ? Math.max(10, proLimit) : 10;
    const adminListingLimit = adminListingLimitRaw > 0 ? adminListingLimitRaw : null;
    const derivedExtraFromLimit = adminListingLimit == null ? 0 : Math.max(0, adminListingLimit - baseLimit);
    const currentExtraBalance = Math.max(adminExtraListingLimit, derivedExtraFromLimit);
    const nextExtraBalance = currentExtraBalance + grantCount;
    const newTotalLimit = baseLimit + nextExtraBalance;

    const updatePayload = {
      adminListingLimit: newTotalLimit,
      adminExtraListingLimit: nextExtraBalance,
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastListingRightsGrantAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    tx.set(userRef, updatePayload, { merge: true });
    tx.set(purchasesRef, {
      userId: uid,
      userName: user.name || "Isimsiz",
      userEmail: user.email || "",
      packageId,
      price: priceText,
      days: 0,
      addedListingLimit: grantCount,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: actionType,
      mode,
      purchaseId: externalPurchaseId,
      purchasePlatform: purchasePlatform || "",
      verifiedByServer: !!verificationRef,
    });

    if (verificationRef) {
      tx.set(verificationRef, {
        usedBy: uid,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        packageId,
        purchaseId: externalPurchaseId,
        purchasePlatform,
        ...(verificationPayload ? { verificationPayload } : {}),
      }, { merge: true });
    }

    return { newTotalLimit, grantCount };
  });

  if (mode === "paid_package" && purchasePlatform === "android") {
    await consumeGooglePlayPurchase({
      packageName: String(listingRightsSettings.androidPackageName || "com.kisidencom.app").trim(),
      productId: requestedProductId,
      purchaseToken: serverVerificationData,
    });
  }

  return {
    success: true,
    granted: result.grantCount,
    newTotalLimit: result.newTotalLimit,
  };
});

// Vitrin/acil ilan haklarini, ilan sahibi ve satin alma dogrulamasi ile birlikte
// tek bir transaction icinde uygular.
exports.activateListingPromotion = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
  secrets: [googlePlayServiceAccountJson, appleSharedSecret],
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const uid = request.auth.uid;
  const listingId = String(request.data?.listingId || "").trim();
  const promotionType = String(request.data?.promotionType || "").trim();
  const mode = String(request.data?.mode || "").trim();
  const productId = String(request.data?.productId || "").trim();
  const verificationData = request.data?.verificationData || {};
  const purchasePlatform = normalizePurchasePlatform(
    String(request.data?.purchasePlatform || ""),
    String(verificationData.source || ""),
  );
  const serverVerificationData = String(verificationData.serverVerificationData || "").trim();
  const localVerificationData = String(verificationData.localVerificationData || "").trim();

  const promotionConfig = {
    showcase: {
      products: { vitrin_1_gun: 1, vitrin_1_hafta: 7, vitrin_1_ayy: 30 },
      until: "showcaseUntil",
      at: "showcasedAt",
    },
    category_showcase: {
      products: { kat_vitrin_1_gun: 1, kat_vitrin_1_hafta: 7, kat_vitrin_1_ay: 30 },
      until: "categoryShowcaseUntil",
      at: "categoryShowcasedAt",
    },
    urgent: {
      products: { acil_2_gun: 2, acil_3_gun: 3, acil_7_gun: 7 },
      until: "urgentUntil",
      at: "urgentAt",
    },
  }[promotionType];

  if (!listingId || !promotionConfig || !["free", "paid"].includes(mode)) {
    throw new HttpsError("invalid-argument", "Gecersiz vitrin parametreleri.");
  }

  const days = mode === "paid" ? promotionConfig.products[productId] : 1;
  if (!days) {
    throw new HttpsError("permission-denied", "Bu vitrin paketi aktif degil.");
  }

  let verificationRef = null;
  let verificationPayload = null;
  let externalPurchaseId = String(request.data?.purchaseId || "").trim();
  if (mode === "paid") {
    if (!purchasePlatform) {
      throw new HttpsError("invalid-argument", "Satin alma platformu anlasilamadi.");
    }
    if (purchasePlatform === "android") {
      if (!serverVerificationData) {
        throw new HttpsError("invalid-argument", "Google Play satin alma token'i eksik.");
      }
      const verified = await verifyGooglePlayPurchase({
        packageName: "com.kisidencom.app",
        productId,
        purchaseToken: serverVerificationData,
      });
      verificationRef = db.collection("purchase_verifications").doc(verified.verificationKey);
      verificationPayload = verified.payload;
      externalPurchaseId = verified.externalId || externalPurchaseId;
    } else if (purchasePlatform === "ios") {
      const receiptData = localVerificationData || serverVerificationData;
      if (!receiptData) {
        throw new HttpsError("invalid-argument", "Apple receipt verisi eksik.");
      }
      const verified = await verifyApplePurchase({
        bundleId: "com.kisidencom.appim",
        productId,
        receiptData,
      });
      verificationRef = db.collection("purchase_verifications").doc(verified.verificationKey);
      verificationPayload = verified.payload;
      externalPurchaseId = verified.externalId || externalPurchaseId;
    } else {
      throw new HttpsError("invalid-argument", "Desteklenmeyen satin alma platformu.");
    }
  }

  const listingRef = db.collection("listings").doc(listingId);
  const userRef = db.collection("users").doc(uid);
  const purchaseRef = db.collection("purchases").doc();
  const result = await db.runTransaction(async (tx) => {
    const listingSnap = await tx.get(listingRef);
    const userSnap = await tx.get(userRef);
    const verificationSnap = verificationRef ? await tx.get(verificationRef) : null;
    if (!listingSnap.exists) throw new HttpsError("not-found", "Ilan bulunamadi.");
    if (!userSnap.exists) throw new HttpsError("not-found", "Kullanici bulunamadi.");

    const listing = listingSnap.data() || {};
    const user = userSnap.data() || {};
    if (listing.sellerId !== uid && request.auth.token?.admin !== true) {
      throw new HttpsError("permission-denied", "Bu ilana erisim yetkiniz yok.");
    }

    const update = {
      [promotionConfig.until]: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + days * 24 * 60 * 60 * 1000),
      ),
      [promotionConfig.at]: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    if (mode === "free") {
      const countField = promotionType === "showcase"
        ? "freeHomeShowcaseCount"
        : promotionType === "category_showcase"
          ? "freeCategoryShowcaseCount"
          : "freeUrgentCount";
      const count = Number(user[countField] || 0);
      if (count < 1) throw new HttpsError("resource-exhausted", "Ucretsiz hakkiniz bulunmuyor.");
      tx.update(userRef, {
        [countField]: admin.firestore.FieldValue.increment(-1),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } else {
      tx.set(purchaseRef, {
        userId: uid,
        listingId,
        packageId: productId,
        days,
        type: promotionType,
        mode,
        purchaseId: externalPurchaseId,
        purchasePlatform,
        verifiedByServer: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    tx.update(listingRef, update);
    if (verificationRef) {
      if (verificationSnap.exists && verificationSnap.data()?.usedBy) {
        throw new HttpsError("already-exists", "Bu satin alma daha once kullanildi.");
      }
      tx.set(verificationRef, {
        usedBy: uid,
        usedAt: admin.firestore.FieldValue.serverTimestamp(),
        listingId,
        productId,
        ...(verificationPayload ? { verificationPayload } : {}),
      }, { merge: true });
    }
    return { days };
  });

  if (mode === "paid" && purchasePlatform === "android") {
    await consumeGooglePlayPurchase({
      packageName: "com.kisidencom.app",
      productId,
      purchaseToken: serverVerificationData,
    });
  }

  return { success: true, days: result.days };
});

exports.activateProPurchase = onCall({
  region: "europe-west1",
  enforceAppCheck: true,
  secrets: [googlePlayServiceAccountJson],
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapmaniz gerekiyor.");
  }

  const uid = request.auth.uid;
  const productId = String(request.data?.productId || "").trim();
  const verificationData = request.data?.verificationData || {};
  const purchasePlatform = normalizePurchasePlatform(
    String(request.data?.purchasePlatform || ""),
    String(verificationData.source || ""),
  );
  const purchaseToken = String(verificationData.serverVerificationData || "").trim();
  const receiptData = String(
    verificationData.localVerificationData || verificationData.serverVerificationData || "",
  ).trim();
  const packages = {
    pro_3_ay: { days: 90, limit: 25, home: 2, category: 2, urgent: 2 },
    pro_6_ay: { days: 180, limit: 60, home: 10, category: 10, urgent: 10 },
    pro_12_ay: { days: 365, limit: 250, home: 25, category: 25, urgent: 25 },
  };
  const selected = packages[productId];
  if (!selected || !["android", "ios"].includes(purchasePlatform)) {
    throw new HttpsError("invalid-argument", "Gecersiz Pro satin alma bilgisi.");
  }

  let verified;
  if (purchasePlatform === "android") {
    if (!purchaseToken) {
      throw new HttpsError("invalid-argument", "Google Play satin alma token'i eksik.");
    }
    verified = await verifyGooglePlayPurchase({
      packageName: "com.kisidencom.app",
      productId,
      purchaseToken,
    });
  } else {
    if (!receiptData) {
      throw new HttpsError("invalid-argument", "Apple receipt verisi eksik.");
    }
    verified = await verifyApplePurchase({
      bundleId: "com.kisidencom.appim",
      productId,
      receiptData,
    });
  }
  const verificationRef = db.collection("purchase_verifications").doc(verified.verificationKey);
  const userRef = db.collection("users").doc(uid);
  const purchaseRef = db.collection("purchases").doc();
  const result = await db.runTransaction(async (tx) => {
    const [userSnap, verificationSnap] = await Promise.all([
      tx.get(userRef),
      tx.get(verificationRef),
    ]);
    if (!userSnap.exists) throw new HttpsError("not-found", "Kullanici bulunamadi.");
    if (verificationSnap.exists && verificationSnap.data()?.usedBy) {
      throw new HttpsError("already-exists", "Bu satin alma daha once kullanildi.");
    }
    const user = userSnap.data() || {};
    const now = new Date();
    const currentUntil = user.proUntil?.toDate?.() || now;
    const base = currentUntil > now ? currentUntil : now;
    const proUntil = new Date(base.getTime() + selected.days * 24 * 60 * 60 * 1000);
    tx.set(userRef, {
      proUntil: admin.firestore.Timestamp.fromDate(proUntil),
      proListingLimit: selected.limit,
      freeHomeShowcaseCount: admin.firestore.FieldValue.increment(selected.home),
      freeCategoryShowcaseCount: admin.firestore.FieldValue.increment(selected.category),
      freeUrgentCount: admin.firestore.FieldValue.increment(selected.urgent),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
    tx.set(purchaseRef, {
      userId: uid,
      packageId: productId,
      days: selected.days,
      limit: selected.limit,
      purchaseId: verified.externalId,
      purchasePlatform,
      verifiedByServer: true,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type: "Pro Paket",
    });
    tx.set(verificationRef, {
      usedBy: uid,
      usedAt: admin.firestore.FieldValue.serverTimestamp(),
      packageId: productId,
      verificationPayload: verified.payload,
    }, { merge: true });
    return { proUntil };
  });

  const listings = await db.collection("listings")
    .where("sellerId", "==", uid)
    .get();
  const batch = db.batch();
  listings.docs.forEach((doc) => batch.update(doc.ref, {
    isPro: true,
    proUntil: admin.firestore.Timestamp.fromDate(result.proUntil),
  }));
  if (!listings.empty) await batch.commit();
  if (purchasePlatform === "android") {
    await acknowledgeGooglePlayPurchase({
      packageName: "com.kisidencom.app",
      productId,
      purchaseToken,
    });
  }
  return { success: true, proUntil: result.proUntil.toISOString() };
});

async function isAdminUid(userId) {
  let authUser;
  try {
    authUser = await admin.auth().getUser(userId);
  } catch (error) {
    if (error?.code === "auth/user-not-found") return false;
    throw error;
  }
  return authUser.customClaims?.admin === true || (
    authUser.emailVerified === true &&
    ADMIN_EMAIL_ALLOWLIST.has(String(authUser.email || "").toLowerCase())
  );
}

async function canSendListingEvent({ senderId, receiverId, targetId, eventId, isAdmin }) {
  const listingSnap = await db.collection("listings").doc(targetId).get();
  if (!listingSnap.exists) return false;
  if (isAdmin) return true;

  const listing = listingSnap.data() || {};
  if (
    listing.sellerId === senderId &&
    Array.isArray(listing.favoritedBy) &&
    listing.favoritedBy.includes(receiverId)
  ) {
    return true;
  }

  if (
    listing.sellerId === senderId &&
    (await db.collection("users").doc(senderId).collection("followers").doc(receiverId).get()).exists
  ) {
    return true;
  }

  if (eventId) {
    const transferSnap = await db.collection("listing_transfers").doc(eventId).get();
    const transfer = transferSnap.exists ? (transferSnap.data() || {}) : {};
    if (
      transferSnap.exists &&
      transfer.listingId === targetId &&
      transfer.senderId === senderId &&
      transfer.receiverId === receiverId &&
      transfer.status === "pending"
    ) {
      return true;
    }

    const questionSnap = await db.collection("listings").doc(targetId)
      .collection("questions").doc(eventId).get();
    if (questionSnap.exists) {
      const question = questionSnap.data() || {};
      const questionOwnerId = String(question.userId || "");
      const replies = Array.isArray(question.replies) ? question.replies : [];
      const hasReplyFromSender = replies.some((reply) =>
        reply && typeof reply === "object" && reply.userId === senderId
      );
      if (
        (senderId === questionOwnerId && receiverId === listing.sellerId) ||
        (
          hasReplyFromSender &&
          ((senderId === listing.sellerId && receiverId === questionOwnerId) ||
            (senderId === questionOwnerId && receiverId === listing.sellerId))
        )
      ) {
        return true;
      }
    }
  }
  return false;
}

exports.sendUserNotification = onCall({
  region: "europe-west1",
}, async (request) => {
  if (!request.auth?.uid) {
    throw new HttpsError("unauthenticated", "Giris yapilmamis.");
  }

  const senderId = request.auth.uid;
  const receiverId = String(request.data?.receiverId || "").trim();
  const title = String(request.data?.title || "").trim();
  const message = String(request.data?.message || "").trim();
  const type = String(request.data?.type || "general").trim();
  const targetId = String(request.data?.targetId || "").trim();
  const eventId = String(request.data?.eventId || "").trim();
  const reason = String(request.data?.reason || "").trim();
  const source = String(request.data?.source || "system").trim();
  const callerIsAdmin = request.auth.token?.admin === true || (
    request.auth.token?.email_verified === true &&
    ADMIN_EMAIL_ALLOWLIST.has(String(request.auth.token?.email || "").toLowerCase())
  );

  if (
    !receiverId ||
    receiverId.length > 128 ||
    receiverId === senderId ||
    targetId.length > 128 ||
    eventId.length > 128
  ) {
    throw new HttpsError("invalid-argument", "Gecersiz alici bilgisi.");
  }
  if (!title || title.length > 120 || !message || message.length > 1000 || reason.length > 1000) {
    throw new HttpsError("invalid-argument", "Bildirim icerigi gecersiz.");
  }
  if (!["general", "chat", "listing", "trade_offer", "review", "ticket"].includes(type)) {
    throw new HttpsError("invalid-argument", "Desteklenmeyen bildirim tipi.");
  }
  if (!trustedNotificationSources.has(source)) {
    throw new HttpsError("permission-denied", "Gecersiz bildirim kaynagi.");
  }

  let authorized = false;
  if (source === "system") {
    authorized = callerIsAdmin;
  } else if (source === "admin_alert") {
    const receiverIsAdmin = await isAdminUid(receiverId);
    if (receiverIsAdmin && callerIsAdmin) {
      authorized = true;
    } else if (receiverIsAdmin && eventId) {
      if (type === "ticket") {
        const ticketSnap = await db.collection("tickets").doc(eventId).get();
        authorized = ticketSnap.exists &&
          (ticketSnap.data() || {}).userId === senderId &&
          eventId === targetId;
      } else if (type === "listing") {
        const reportSnap = await db.collection("reports").doc(eventId).get();
        if (reportSnap.exists) {
          const report = reportSnap.data() || {};
          authorized = report.reporterId === senderId && report.listingId === targetId;
        } else {
          const listingSnap = await db.collection("listings").doc(targetId).get();
          authorized = listingSnap.exists &&
            (listingSnap.data() || {}).sellerId === senderId &&
            eventId === targetId;
        }
      }
    }
  } else if (source === "chat_event" && type === "chat" && targetId) {
    const chatSnap = await db.collection("chats").doc(targetId).get();
    const participants = chatSnap.exists ? (chatSnap.data() || {}).participants : null;
    authorized = Array.isArray(participants) &&
      participants.includes(senderId) &&
      participants.includes(receiverId);
  } else if (source === "listing_event" && type === "listing" && targetId) {
    authorized = await canSendListingEvent({
      senderId,
      receiverId,
      targetId,
      eventId,
      isAdmin: callerIsAdmin,
    });
  } else if (source === "trade_offer_event" && type === "trade_offer" && eventId) {
    const offerSnap = await db.collection("trade_offers").doc(eventId).get();
    const offer = offerSnap.exists ? (offerSnap.data() || {}) : {};
    const partiesMatch = (
      offer.senderId === senderId && offer.receiverId === receiverId
    ) || (
      offer.senderId === receiverId && offer.receiverId === senderId &&
      ["accepted", "rejected", "cancelled", "expired"].includes(offer.status)
    );
    authorized = offerSnap.exists && partiesMatch &&
      (targetId === eventId || targetId === offer.receiverListingId);
  } else if (source === "review_event" && type === "review" && targetId === senderId) {
    authorized = (
      await db.collection("users").doc(senderId)
        .collection("review_permissions").doc(receiverId).get()
    ).exists;
  }

  if (!authorized) {
    throw new HttpsError("permission-denied", "Bu bildirim icin gonderen-alici iliskisi dogrulanamadi.");
  }

  const receiverSnap = await db.collection("users").doc(receiverId).get();
  if (!receiverSnap.exists) {
    throw new HttpsError("not-found", "Bildirim alicisi bulunamadi.");
  }

  const senderRef = db.collection("users").doc(senderId);
  const notificationRef = db.collection("users").doc(receiverId)
    .collection("notifications").doc();
  await db.runTransaction(async (tx) => {
    const senderSnap = await tx.get(senderRef);
    if (!senderSnap.exists) {
      throw new HttpsError("not-found", "Bildirim gondericisi bulunamadi.");
    }
    const lastAt = senderSnap.data()?.lastNotificationSentAt?.toDate?.() || null;
    if (lastAt && Date.now() - lastAt.getTime() < 1500) {
      throw new HttpsError("resource-exhausted", "Cok hizli bildirim gonderimi engellendi.");
    }

    tx.create(notificationRef, {
      title,
      message,
      isRead: false,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      type,
      targetId,
      ...(reason ? { reason } : {}),
      source,
    });
    tx.set(senderRef, {
      lastNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
    }, { merge: true });
  });

  return { success: true };
});