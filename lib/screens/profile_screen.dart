import 'package:flutter/material.dart';
import 'dart:async';
import 'package:appim/utils/local_fonts.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../services/database_service.dart';
import 'edit_profile_screen.dart';
import 'admin_panel_screen.dart';
import 'favorites_screen.dart';
import 'my_listings_screen.dart';
import 'search_alarms_screen.dart'; // YENİ: Arama Alarmları için eklendi
import 'blocked_users_screen.dart'; // YENİ: Engellenenler için eklendi
import 'tickets/user_tickets_screen.dart'; // YENİ: Destek Talepleri Ekranı
import 'login_screen.dart'; // YENİ: Yönlendirme için eklendi
import 'seller_profile_screen.dart'; // YENİ: Kendi profilini görüntüleme için eklendi
import '../utils/translations.dart'; // YENİ: Çeviri sistemi eklendi
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart'; // YENİ: appLocale erişimi için
import 'pro_purchase_screen.dart'; // YENİ: Pro Satın Alma Ekranı
import 'legal_document_screen.dart'; // YENİ: Yasal belgeler için
import 'faq_screen.dart';
import '../utils/theme_colors.dart';

class _DeletingAccountScreen extends StatelessWidget {
  const _DeletingAccountScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const CircularProgressIndicator(color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  tr('account_deleting'),
                  style: LocalFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('please_wait_processing'),
                  style: LocalFonts.poppins(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _logout(BuildContext context) async {
    // SİYAH EKRAN ÇÖZÜMÜ BURADA:
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (c) => const Center(child: CircularProgressIndicator()),
    );

    // YENİ: Çıkış yaparken cihazın bildirim token'ını temizle (Hesaplar arası bildirim karışmasını önler)
    try {
      await DatabaseService().removeDeviceToken();
    } catch (e) {}

    // ÇÖZÜM: Google SignIn Web'de tepki vermezse uygulamayı dondurmasın diye try-catch içine alıyoruz
    try {
      await GoogleSignIn().signOut();
    } catch (e) {}

    try {
      await FirebaseAuth.instance.signOut();
    } catch (e) {}

    if (context.mounted) {
      // Arkada açık kalan TÜM sayfaları hafızadan siliyor ve Login ekranına temiz bir geçiş yapıyor
      Navigator.of(context, rootNavigator: true).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (Route<dynamic> route) => false,
      );
    }
  }

  Future<void> _deleteAccount(BuildContext context) async {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('delete_account_title'),
          style: const TextStyle(color: Colors.red),
        ),
        content: Text(tr('delete_account_desc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c),
            child: Text(tr('cancel')),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(c).colorScheme.error,
            ),
            onPressed: () async {
              final screenContext = context;
              Navigator.pop(c); // Önce uyarı penceresini (AlertDialog) kapat

              final navigator = Navigator.of(
                screenContext,
                rootNavigator: true,
              );
              final messenger = ScaffoldMessenger.of(screenContext);

              navigator.push(
                MaterialPageRoute(
                  builder: (ctx) => const _DeletingAccountScreen(),
                ),
              );

              try {
                await (() async {
                  // YENİ: Hesabı silerken cihaz token'ını da temizle
                  try {
                    await DatabaseService().removeDeviceToken();
                  } catch (e) {}

                  // Öncelik: Admin SDK tarafındaki güvenli hard-delete fonksiyonu
                  // (trade_offers / purchases gibi kural kısıtlı koleksiyonları da temizler)
                  try {
                    await DatabaseService().deleteMyAccountHard();
                  } on FirebaseFunctionsException catch (e) {
                    // Fonksiyon kapalı/erişilemiyor ise mevcut istemci temizliğine düş
                    if (e.code != 'unavailable' &&
                        e.code != 'not-found' &&
                        e.code != 'failed-precondition' &&
                        e.code != 'permission-denied') {
                      rethrow;
                    }

                    final currentUser = FirebaseAuth.instance.currentUser;
                    if (currentUser != null) {
                      await DatabaseService().deleteAllUserData(
                        currentUser.uid,
                      );
                      await currentUser.delete();
                    }
                  }

                  // 3. Google Session'ı kapat
                  try {
                    await GoogleSignIn().signOut();
                  } catch (e) {}

                  try {
                    await FirebaseAuth.instance.signOut();
                  } catch (e) {}
                })().timeout(const Duration(seconds: 45));

                navigator.pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginScreen()),
                  (Route<dynamic> route) => false,
                );
              } on TimeoutException {
                if (navigator.canPop()) {
                  navigator.pop();
                }
                messenger.showSnackBar(
                  const SnackBar(
                    content: Text(
                      'İşlem beklenenden uzun sürdü. Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
                    ),
                  ),
                );
              } on FirebaseAuthException catch (e) {
                if (context.mounted) {
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                }

                if (e.code == 'requires-recent-login') {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(tr('delete_account_error')),
                      backgroundColor: Colors.red,
                    ),
                  );
                } else {
                  messenger.showSnackBar(
                    SnackBar(
                      content: Text(
                        tr('operation_failed_with_reason').replaceFirst(
                          '%s',
                          e.message ?? tr('unknown_server_error'),
                        ),
                      ),
                    ),
                  );
                }
              } catch (e) {
                if (screenContext.mounted) {
                  if (navigator.canPop()) {
                    navigator.pop();
                  }
                }
                messenger.showSnackBar(
                  SnackBar(content: Text('${tr('error')} $e')),
                );
              }
            },
            child: Text(
              tr('delete'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }

  void _openLegalPage(BuildContext context, String page) {
    String title;
    String assetPath;

    switch (page) {
      case 'about':
        title = tr('about_us');
        assetPath = 'assets/legal/about.html';
        break;
      case 'privacy':
        title = tr('privacy_policy');
        assetPath = 'assets/legal/privacy.html';
        break;
      case 'terms':
        title = tr('terms_of_use');
        assetPath = 'assets/legal/terms.html';
        break;
      default:
        return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            LegalDocumentScreen(title: title, assetPath: assetPath),
      ),
    );
  }

  void _showLanguageDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(
          tr('language'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(tr('language_tr')),
              trailing: appLocale.value.languageCode == 'tr'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                appLocale.value = const Locale('tr');
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('language_code', 'tr');
                if (FirebaseAuth.instance.currentUser != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .update({'languageCode': 'tr'});
                }
                Navigator.pop(c);
              },
            ),
            ListTile(
              title: Text(tr('language_en')),
              trailing: appLocale.value.languageCode == 'en'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                appLocale.value = const Locale('en');
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('language_code', 'en');
                if (FirebaseAuth.instance.currentUser != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .update({'languageCode': 'en'});
                }
                Navigator.pop(c);
              },
            ),
            ListTile(
              title: Text(tr('language_ar')),
              trailing: appLocale.value.languageCode == 'ar'
                  ? const Icon(Icons.check, color: Colors.green)
                  : null,
              onTap: () async {
                appLocale.value = const Locale('ar');
                final prefs = await SharedPreferences.getInstance();
                prefs.setString('language_code', 'ar');
                if (FirebaseAuth.instance.currentUser != null) {
                  FirebaseFirestore.instance
                      .collection('users')
                      .doc(FirebaseAuth.instance.currentUser!.uid)
                      .update({'languageCode': 'ar'});
                }
                Navigator.pop(c);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.userChanges(),
      builder: (context, snapshot) {
        final user = snapshot.data;
        if (user == null)
          return const Center(child: CircularProgressIndicator());

        // --- GİZLİ ADMİN KONTROLÜ BURADA ---
        final bool isAdmin = user.email == 'hasanmardinn@gmail.com';

        return Scaffold(
          backgroundColor: Colors.grey[50],
          appBar: AppBar(
            title: Text(
              tr('account'),
              style: LocalFonts.poppins(fontWeight: FontWeight.bold),
            ),
            backgroundColor: Colors.white,
            elevation: 0,
            centerTitle:
                true, // Web'de başlığın ortalı durması daha profesyoneldir
          ),
          body: FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance
                .collection('users')
                .doc(user.uid)
                .get(),
            builder: (context, userSnap) {
              String? coverUrl;
              bool isPro = false;
              if (userSnap.hasData && userSnap.data!.exists) {
                var uData = userSnap.data!.data() as Map<String, dynamic>;
                coverUrl = uData['coverPhotoUrl'];
                isPro =
                    uData['proUntil'] != null &&
                    (uData['proUntil'] as Timestamp).toDate().isAfter(
                      DateTime.now(),
                    );
              }

              return SingleChildScrollView(
                child: Column(
                  children: [
                    // ÜST BİLGİ KARTI
                    Container(
                      margin: const EdgeInsets.only(
                        left: 20,
                        right: 20,
                        top: 16,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            Container(
                              height: 140,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                image: coverUrl != null && coverUrl != ''
                                    ? DecorationImage(
                                        image: NetworkImage(coverUrl),
                                        fit: BoxFit.cover,
                                        colorFilter: ColorFilter.mode(
                                          Colors.black.withValues(alpha: 0.3),
                                          BlendMode.darken,
                                        ),
                                        onError: (e, s) {},
                                      )
                                    : null,
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                              ),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    radius: 35,
                                    backgroundColor: Colors.white,
                                    backgroundImage: user.photoURL != null
                                        ? NetworkImage(user.photoURL!)
                                        : null,
                                    onBackgroundImageError:
                                        (
                                          exception,
                                          stackTrace,
                                        ) {}, // Resim 404 hatasını önleyici
                                    child: user.photoURL == null
                                        ? const Icon(
                                            Icons.person,
                                            size: 35,
                                            color: AppColors.primary,
                                          )
                                        : null,
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        Row(
                                          children: [
                                            Flexible(
                                              child: Text(
                                                user.displayName ?? tr('user'),
                                                style: LocalFonts.poppins(
                                                  fontSize: 20,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.white,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            if (isPro) const SizedBox(width: 8),
                                            if (isPro)
                                              Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 6,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: AppColors.secondary,
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  'PRO',
                                                  style: LocalFonts.poppins(
                                                    color: Colors.white,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                        Text(
                                          user.phoneNumber?.isNotEmpty == true
                                              ? user.phoneNumber!
                                              : (user.email ?? ''),
                                          style: LocalFonts.poppins(
                                            color: Colors.white70,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.edit,
                                      color: Colors.white,
                                    ),
                                    onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const EditProfileScreen(),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),

                    // MENÜ LİSTESİ
                    // YENİ: Kullanıcı Pro olsa bile süresini uzatabilmesi için menüyü gizlemiyoruz
                    _buildMenuSection(
                      title: tr('account_features'),
                      icon: Icons.dashboard_customize_outlined,
                      color: AppColors.primary,
                      children: [
                    _buildMenuTile(
                      Icons.workspace_premium,
                      isPro ? 'Pro Paketini Uzat / Yenile' : tr('upgrade_pro'),
                      AppColors.secondary,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProPurchaseScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.storefront_rounded,
                      tr('seller_profile'),
                      AppColors.primary,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                SellerProfileScreen(sellerId: user.uid),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.favorite,
                      tr('favorite_listings'),
                      Colors.red,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FavoritesScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.notifications_active,
                      tr('search_alarms'),
                      AppColors.secondary,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SearchAlarmsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.support_agent,
                      tr('support_tickets'),
                      Colors.blue,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const UserTicketsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.quiz_outlined,
                      tr('faq_title'),
                      const Color(0xFF0F766E),
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FaqScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.list_alt,
                      tr('my_listings'),
                      AppColors.primary,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const MyListingsScreen(),
                          ),
                        );
                      },
                    ),
                    _buildMenuTile(
                      Icons.block,
                      tr('blocked_users'),
                      Colors.red[400]!,
                      () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const BlockedUsersScreen(),
                          ),
                        );
                      },
                    ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildMenuSection(
                      title: tr('preferences'),
                      icon: Icons.tune,
                      color: Colors.teal,
                      children: [
                        _buildMenuTile(
                          Icons.language,
                          tr('language'),
                          Colors.teal,
                          () => _showLanguageDialog(context),
                        ),
                      ],
                    ),

                    if (isAdmin) ...[
                      _buildMenuSection(
                        title: tr('administration'),
                        icon: Icons.admin_panel_settings,
                        color: Colors.purple,
                        children: [
                          _buildMenuTile(
                            Icons.admin_panel_settings,
                            tr('admin_panel'),
                            Colors.purple,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => const AdminPanelScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    const SizedBox(height: 20),
                    _buildMenuSection(
                      title: tr('information_and_legal'),
                      icon: Icons.info_outline,
                      color: AppColors.primary,
                      children: [
                        _buildMenuTile(
                          Icons.info_outline,
                          tr('about_us'),
                          Colors.grey[700]!,
                          () => _openLegalPage(context, 'about'),
                        ),
                        _buildMenuTile(
                          Icons.privacy_tip_outlined,
                          tr('privacy_policy'),
                          Colors.grey[700]!,
                          () => _openLegalPage(context, 'privacy'),
                        ),
                        _buildMenuTile(
                          Icons.rule,
                          tr('terms_of_use'),
                          Colors.grey[700]!,
                          () => _openLegalPage(context, 'terms'),
                        ),
                      ],
                    ),

                    const SizedBox(height: 20),
                    _buildMenuSection(
                      title: tr('account_actions'),
                      icon: Icons.manage_accounts_outlined,
                      color: Colors.orange,
                      children: [
                        _buildMenuTile(
                          Icons.logout,
                          tr('logout'),
                          Colors.orange,
                          () => _logout(context),
                        ),
                        _buildMenuTile(
                          Icons.delete_forever,
                          tr('delete_account'),
                          Colors.red,
                          () => _deleteAccount(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 40),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildMenuTile(
    IconData icon,
    String title,
    Color iconColor,
    VoidCallback onTap,
  ) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(icon, color: iconColor),
      ),
      title: Text(
        title,
        style: LocalFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15),
      ),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }

  Widget _buildMenuSection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Widget> children,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.16)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
            child: Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Center(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: LocalFonts.poppins(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          ...children,
        ],
      ),
    );
  }
}
