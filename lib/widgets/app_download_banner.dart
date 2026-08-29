import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../utils/theme_colors.dart';
import '../utils/translations.dart';

class AppDownloadBanner extends StatefulWidget {
  const AppDownloadBanner({super.key});

  @override
  State<AppDownloadBanner> createState() => _AppDownloadBannerState();
}

class _AppDownloadBannerState extends State<AppDownloadBanner> {
  bool _isVisible = true;

  // ÖNEMLİ: Uygulamanızı mağazaya yükledikten sonra bu linkleri kendi uygulamanızın mağaza linkleriyle değiştirin.
  final String _playStoreUrl =
      "https://play.google.com/store/apps/details?id=com.kisidencom.app";
  final String _appStoreUrl =
      "https://apps.apple.com/tr/app/kisiden/id123456789";

  Future<void> _launchURL(String url) async {
    if (kIsWeb) {
      final isAndroid = defaultTargetPlatform == TargetPlatform.android;
      final isIOS =
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS;

      if (isAndroid) {
        // Android Akıllı Intent (Uygulama varsa açar, yoksa otomatik Play Store'a atar)
        final String intentUrl =
            "intent://kisiden.com/#Intent;scheme=https;package=com.kisidencom.app;S.browser_fallback_url=${Uri.encodeComponent(_playStoreUrl)};end";
        try {
          await launchUrl(
            Uri.parse(intentUrl),
            mode: LaunchMode.externalApplication,
          );
          return; // İşlem başarılıysa metoddan çık
        } catch (e) {
          debugPrint("Intent yönlendirmesi başarısız oldu: $e");
        }
      } else if (isIOS) {
        // iOS için Custom Scheme (Uygulama cihazda yüklüyse açmayı dener)
        final Uri appUri = Uri.parse("kisiden://");
        try {
          await launchUrl(appUri, mode: LaunchMode.externalApplication);
        } catch (e) {
          debugPrint("iOS Custom Scheme başarısız oldu: $e");
        }
      }
    }

    // Fallback (Uygulama yüklü değilse, hata verirse veya masaüstündeyse doğrudan mağaza/web linkini aç)
    final Uri uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      debugPrint("Link açılamadı: $url");
    }
  }

  @override
  Widget build(BuildContext context) {
    // Eğer uygulama web'de ÇALIŞMIYORSA veya kullanıcı banner'ı [X] ile kapattıysa hiçbir şey gösterme
    if (!kIsWeb || !_isVisible) return const SizedBox.shrink();

    // Kullanıcının web sitenize hangi cihazdan girdiğini algılayalım
    final isIOS =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
    final isMobileWeb =
        defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.android;

    if (isMobileWeb) {
      // ----------------------------------------------------
      // 1. MOBİL WEB (Telefondan Tarayıcı İle Girenler İçin)
      // Ekranın altına yapışık (Sticky Bottom) şık bir tasarım.
      // ----------------------------------------------------
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 20,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 12.0,
            ),
            child: Row(
              children: [
                // Kapatma Butonu
                GestureDetector(
                  onTap: () => setState(() => _isVisible = false),
                  child: const Icon(Icons.close, color: Colors.grey, size: 22),
                ),
                const SizedBox(width: 12),
                // Uygulama Logosu
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.storefront_rounded,
                    color: Colors.white,
                    size: 26,
                  ),
                ),
                const SizedBox(width: 12),
                // Başlıklar
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tr('app_name'),
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        tr('slogan'),
                        style: LocalFonts.poppins(
                          fontSize: 11,
                          color: Colors.grey[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                // Mağazaya Git Butonu (Cihaza göre dinamik)
                ElevatedButton(
                  onPressed: () =>
                      _launchURL(isIOS ? _appStoreUrl : _playStoreUrl),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 0,
                    ),
                    elevation: 0,
                  ),
                  child: Text(
                    tr('open_in_app'),
                    style: LocalFonts.poppins(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    } else {
      // ----------------------------------------------------
      // 2. MASAÜSTÜ WEB (Bilgisayarından Girenler İçin)
      // Ekranın üst veya alt kısmına yatay yerleşecek geniş tasarım.
      // ----------------------------------------------------
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary, AppColors.secondary],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.phone_iphone, color: Colors.white, size: 28),
            const SizedBox(width: 16),
            Text(
              tr('download_mobile_app_better_experience'),
              style: LocalFonts.poppins(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 24),
            ElevatedButton.icon(
              onPressed: () => _launchURL(_playStoreUrl),
              icon: const Icon(Icons.android, size: 18, color: Colors.black87),
              label: Text(
                'Google Play',
                style: LocalFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton.icon(
              onPressed: () => _launchURL(_appStoreUrl),
              icon: const Icon(Icons.apple, size: 18, color: Colors.black87),
              label: Text(
                'App Store',
                style: LocalFonts.poppins(
                  color: Colors.black87,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
            const SizedBox(width: 24),
            IconButton(
              icon: const Icon(Icons.close, color: Colors.white70),
              onPressed: () => setState(() => _isVisible = false),
            ),
          ],
        ),
      );
    }
  }
}
