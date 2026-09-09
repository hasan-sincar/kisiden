const admin = require("firebase-admin");
const crypto = require("node:crypto");
const xmlbuilder = require("xmlbuilder");
const express = require("express");
/* googleapis is lazy-required inside verifyGooglePlayPurchase to avoid long import time during deploy analysis */
const { onSchedule } = require("firebase-functions/v2/scheduler");
const { onDocumentDeleted, onDocumentCreated } = require("firebase-functions/v2/firestore");
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
  const name = String(body.name || "").trim();
  const email = String(body.email || "").trim();
  const topic = String(body.topic || "Genel destek").trim();
  const message = String(body.message || "").trim();
  const website = String(body.website || "").trim();

  // Honeypot alanı botların formu kötüye kullanmasını engeller.
  if (website) {
    response.status(204).send("");
    return;
  }
  if (
    name.length < 2 || name.length > 120 ||
    !/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email) ||
    topic.length < 2 || topic.length > 120 ||
    message.length < 5 || message.length > 5000
  ) {
    response.status(400).json({error: "Invalid support request"});
    return;
  }

  const transporter = getTransporter();
  if (!transporter) {
    response.status(503).json({error: "Email service is not configured"});
    return;
  }

  try {
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
      replyTo: email,
      subject: `[Destek] ${topic}`,
      text: `Ad: ${name}\nE-posta: ${email}\nKonu: ${topic}\n\n${message}`,
      html: `
        <div style="font-family:Arial,sans-serif;line-height:1.6;color:#17233d">
          <h2>Yeni Kisiden destek talebi</h2>
          <p><b>Ad:</b> ${escapeHtml(name)}</p>
          <p><b>E-posta:</b> ${escapeHtml(email)}</p>
          <p><b>Konu:</b> ${escapeHtml(topic)}</p>
          <hr>
          <p style="white-space:pre-wrap">${escapeHtml(message)}</p>
        </div>
      `,
    });
    response.status(200).json({success: true});
  } catch (error) {
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
        "yandex", "sogou", "exabot", "facebot", "facebookexternalhit",
        "twitterbot", "linkedinbot", "pinterest", "whatsapp", "telegrambot",
    ];
    return botAgents.some((bot) => userAgent.toLowerCase().includes(bot));
};

// İlan sayfası için sunucu taraflı render (SSR for Bots)
const renderListingPage = async (req, res) => {
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

            const data = doc.data();
            const url = `${DOMAIN}/ilan?id=${listingId}`;
      const rawTitle = data.title || "Kişiden İlanı";
      const title = escapeHtml(rawTitle);
            let description = data.description || "Bu ilanı Kişiden uygulamasında inceleyin.";
            if (description.length > 160) {
                description = description.substring(0, 157) + "...";
            }
      description = escapeHtml(description.replace(/\r?\n|\r/g, " "));

            const imageUrl = data.imageUrl || `${DOMAIN}/icons/Icon-512.png`;
            const price = data.price || 0;
      const sellerName = escapeHtml(data.sellerName || "Kişiden Satıcısı");

            // Google Zengin Sonuçlar (Rich Snippets) için JSON-LD Yapısal Verisi
            const jsonLd = {
                "@context": "https://schema.org/",
                "@type": "Product",
                "name": title,
                "image": imageUrl,
                "description": description,
                "sku": listingId,
                "brand": { "@type": "Brand", "name": "Kişiden" },
                "offers": {
                    "@type": "Offer",
                    "url": url,
                    "priceCurrency": "TRY",
                    "price": price,
                    "availability": "https://schema.org/InStock",
                    "seller": { "@type": "Organization", "name": sellerName },
                },
            };

            // Bota özel tam HTML sayfası döndür
            const html = `
                <!DOCTYPE html>
                <html lang="tr">
                <head>
                    <meta charset="UTF-8">
                    <title>${title}</title>
                    <meta name="description" content="${description}">
                    <link rel="canonical" href="${url}" />
                    <meta property="og:title" content="${title}">
                    <meta property="og:description" content="${description}">
                    <meta property="og:image" content="${imageUrl}">
                    <meta property="og:url" content="${url}">
                    <meta name="twitter:card" content="summary_large_image">
                    <script type="application/ld+json">${JSON.stringify(jsonLd)}</script>
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

    try {
        const snapshot = await db.collection("listings").where("status", "==", "active").get();
        snapshot.forEach((doc) => {
            const listing = doc.data();
            const lastMod = listing.createdAt ? listing.createdAt.toDate().toISOString().split("T")[0] : new Date().toISOString().split("T")[0];
            root.ele("url")
                .ele("loc", `${DOMAIN}/ilan?id=${doc.id}`)
                .up()
                .ele("lastmod", lastMod)
                .up();
        });

        // YENİ: Kategorileri dinamik olarak sitemap'e dahil et
        const categoriesSnap = await db.collection("categories").get();
        categoriesSnap.forEach((doc) => {
            const category = doc.data();
            const lastMod = category.createdAt ? category.createdAt.toDate().toISOString().split("T")[0] : new Date().toISOString().split("T")[0];
            root.ele("url")
                .ele("loc", `${DOMAIN}/kategori?id=${doc.id}`)
                .up()
                .ele("lastmod", lastMod)
                .up();
        });
    } catch (error) {
        logger.error("Sitemap oluşturma hatası:", error);
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
        batch.update(doc.reference, {
          status: 'passive',
          listingRightExpiresAt: admin.firestore.FieldValue.delete(),
          listingRightSource: admin.firestore.FieldValue.delete(),
        });
        expiredCount++;
        notificationPromises.push(sendNotification(sellerId, 'İlan Süresi Doldu', `"${title}" başlıklı ek ilan hakkı süresi doldu ve pasife alındı. Tekrar yayınlamak için yeni ilan hakkı satın almanız veya reklam izleyip hak kazanmanız gerekir.`, 'listing', doc.id));
        return;
      }

      if (autoRenew) {
        batch.update(doc.reference, {
          createdAt: admin.firestore.FieldValue.serverTimestamp()
        });
        renewedCount++;
        notificationPromises.push(sendNotification(sellerId, 'İlanınız Yenilendi', `"${title}" başlıklı ilanınızın 30 günlük süresi dolduğu için otomatik olarak yeniden yayına alındı.`, 'listing', doc.id));
      } else {
        batch.update(doc.reference, {
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
            imageUrl: notificationData.imageUrl || "",
            click_action: "FLUTTER_NOTIFICATION_CLICK"
          },
          token: user.fcmToken
        };

        await admin.messaging().send(message);
      }

      // --- KULLANICIYA E-POSTA İLE BİLDİRİM GÖNDERME ---
      // Eğer kullanıcı e-posta bildirimlerini kapatmamışsa (false değilse) gönder
      if (user.email && user.email.includes("@") && user.emailNotificationsEnabled !== false) {
        const transporter = getTransporter();
        let actionButton = "";
        if (notificationData.type === "listing" && notificationData.targetId) {
          const listingUrl = `${DOMAIN}/ilan?id=${notificationData.targetId}`;
          actionButton = `
            <div style="margin-top: 30px; text-align: center;">
              <a href="${listingUrl}" style="background-color: #1a73e8; color: #ffffff; padding: 14px 28px; text-decoration: none; border-radius: 6px; display: inline-block; font-weight: bold; font-size: 16px;">İlanı Görüntüle</a>
            </div>
          `;
        }

        let reasonBlock = "";
        if (notificationData.reason) {
          reasonBlock = `
            <div style="margin: 20px 0; padding: 15px; background-color: #ffebee; border-left: 4px solid #f44336; border-radius: 4px;">
              <p style="margin: 0; color: #d32f2f; font-size: 14px;"><strong>İşlem Detayı/Nedeni:</strong><br>${notificationData.reason}</p>
            </div>
          `;
        }

        let imageBlock = "";
        if (notificationData.imageUrl) {
          imageBlock = `
            <div style="margin: 18px 0 12px;">
              <img src="${notificationData.imageUrl}" alt="Bildirim görseli" style="width:100%; max-height:260px; object-fit:cover; border-radius:10px; border:1px solid #eeeeee;" />
            </div>
          `;
        }

        const mailOptions = {
          from: '"Kişiden" <info@kisiden.com>',
          to: user.email,
          subject: notificationData.title || "Kişiden'den Yeni Bildirim",
          html: `
            <div style="background-color: #f4f6f8; padding: 30px 10px; font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; line-height: 1.6; color: #333;">
              <div style="max-width: 600px; margin: 0 auto; background-color: #ffffff; border-radius: 8px; overflow: hidden; box-shadow: 0 4px 10px rgba(0,0,0,0.05);">
                <div style="background-color: #1a73e8; padding: 25px; text-align: center;">
                  <img src="${DOMAIN}/icons/Icon-512.png" alt="Kişiden Logo" style="height: 48px; vertical-align: middle; margin-right: 10px; border-radius: 8px;">
                  <h1 style="color: #ffffff; margin: 0; font-size: 26px; letter-spacing: 1px; display: inline-block; vertical-align: middle;">Kişiden</h1>
                </div>
                <div style="padding: 35px 30px;">
                  <p style="font-size: 16px; margin-top: 0;">Merhaba <b>${user.name || 'Kullanıcı'}</b>,</p>
                  <h3 style="color: #1a73e8; margin-top: 25px; margin-bottom: 10px; font-size: 18px;">${notificationData.title || "Yeni Bildirim"}</h3>
                  <p style="font-size: 15px; color: #555; margin-bottom: 30px;">${notificationData.message || "Uygulamada yeni bir bildiriminiz var."}</p>
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
        
        if (receiverUser.fcmToken) {
          const payload = {
            notification: { title: messageData.senderName || "Yeni Mesaj", body: messageData.message || "Size bir mesaj gönderdi." },
            android: { priority: "high", notification: { sound: "default" } },
            apns: { payload: { aps: { sound: "default" } } },
            data: { type: "chat", targetId: chatId, click_action: "FLUTTER_NOTIFICATION_CLICK" },
            token: receiverUser.fcmToken
          };
          await admin.messaging().send(payload);
        }

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

// --- YENI: UCRETLI/REKLAM KAYNAKLI ILAN HAKKI TANIMLAMA (GUVENLI CALLABLE) ---
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
  } else if (mode === "rewarded_1") {
    grantCount = 1;
    packageId = "rewarded_ad_1";
    actionType = "Reklam Izleme Ilan Hakki";
    priceText = "Rewarded Ad";
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

    if (mode === "rewarded_1") {
      const dailyMax = Number(listingRightsSettings.rewardDailyMax || 3);
      const cooldownMinutes = Number(listingRightsSettings.rewardCooldownMinutes || 10);
      const now = new Date();
      const dateKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
      const dailyDate = user.rewardAdDailyDate || "";
      const dailyCount = Number(user.rewardAdDailyCount || 0);
      const lastGrantAt = user.rewardAdLastGrantAt ? user.rewardAdLastGrantAt.toDate() : null;

      if (dailyDate === dateKey && dailyCount >= dailyMax) {
        throw new HttpsError("resource-exhausted", `Gunluk reklam hakkinizi doldurdunuz (${dailyMax}).` );
      }

      if (lastGrantAt) {
        const diffMinutes = (Date.now() - lastGrantAt.getTime()) / 60000;
        if (diffMinutes < cooldownMinutes) {
          throw new HttpsError("resource-exhausted", `Yeni reklam hakki icin ${cooldownMinutes} dakika bekleyin.`);
        }
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

    if (mode === "rewarded_1") {
      const now = new Date();
      const dateKey = `${now.getFullYear()}-${String(now.getMonth() + 1).padStart(2, "0")}-${String(now.getDate()).padStart(2, "0")}`;
      const nextCount = user.rewardAdDailyDate === dateKey
        ? Number(user.rewardAdDailyCount || 0) + 1
        : 1;

      updatePayload.rewardAdDailyDate = dateKey;
      updatePayload.rewardAdDailyCount = nextCount;
      updatePayload.rewardAdLastGrantAt = admin.firestore.FieldValue.serverTimestamp();
    }

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
      verifiedByServer: mode === "paid_package" ? !!verificationRef : false,
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

exports.sendUserNotification = onCall({
  region: "europe-west1",
}, async (request) => {
  if (!request.auth || !request.auth.uid) {
    throw new HttpsError("unauthenticated", "Giris yapilmamis.");
  }

  const senderId = request.auth.uid;
  const receiverId = String(request.data?.receiverId || "").trim();
  const title = String(request.data?.title || "").trim();
  const message = String(request.data?.message || "").trim();
  const type = String(request.data?.type || "general").trim();
  const targetId = String(request.data?.targetId || "").trim();
  const reason = String(request.data?.reason || "").trim();
  const source = String(request.data?.source || "system").trim();

  if (!receiverId || receiverId.length > 128) {
    throw new HttpsError("invalid-argument", "Gecersiz alici bilgisi.");
  }
  if (!title || title.length > 120 || !message || message.length > 1000) {
    throw new HttpsError("invalid-argument", "Bildirim icerigi gecersiz.");
  }
  if (!["general", "chat", "listing", "trade_offer", "review", "ticket"].includes(type)) {
    throw new HttpsError("invalid-argument", "Desteklenmeyen bildirim tipi.");
  }
  if (!trustedNotificationSources.has(source)) {
    throw new HttpsError("permission-denied", "Gecersiz bildirim kaynagi.");
  }

  const senderRef = db.collection("users").doc(senderId);
  const senderSnap = await senderRef.get();
  const senderData = senderSnap.exists ? (senderSnap.data() || {}) : {};
  const lastAt = senderData.lastNotificationSentAt
    ? senderData.lastNotificationSentAt.toDate()
    : null;
  if (lastAt && Date.now() - lastAt.getTime() < 1500) {
    throw new HttpsError("resource-exhausted", "Cok hizli bildirim gonderimi engellendi.");
  }

  await db.collection("users").doc(receiverId).collection("notifications").add({
    title,
    message,
    isRead: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    type,
    targetId,
    ...(reason ? { reason } : {}),
    source,
  });

  await senderRef.set({
    lastNotificationSentAt: admin.firestore.FieldValue.serverTimestamp(),
  }, { merge: true });

  return { success: true };
});