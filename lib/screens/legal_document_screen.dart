import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:appim/utils/local_fonts.dart';
import 'package:appim/utils/theme_colors.dart';
import 'package:flutter_html/flutter_html.dart';
import 'package:url_launcher/url_launcher.dart';

class LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String assetPath;

  const LegalDocumentScreen({
    super.key,
    required this.title,
    required this.assetPath,
  });

  Future<String> _loadAsset() async {
    try {
      return await rootBundle.loadString(assetPath);
    } catch (_) {
      return '<h1>Belge yüklenemedi.</h1>';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title, style: LocalFonts.poppins()),
        backgroundColor: Colors.white,
        elevation: 1,
      ),
      backgroundColor: Colors.white,
      body: FutureBuilder<String>(
        future: _loadAsset(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(
              horizontal: 12.0,
              vertical: 8.0,
            ),
            child: Html(
              data: snapshot.data ?? '<h1>Belge bulunamadı.</h1>',
              style: {
                "body": Style(
                  fontFamily: 'Poppins',
                  fontSize: FontSize(15.0),
                  lineHeight: LineHeight.number(1.7),
                  color: Colors.grey[800],
                ),
                "h1": Style(
                  fontSize: FontSize(24.0),
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                  textAlign: TextAlign.center,
                  margin: Margins.only(bottom: 16),
                ),
                "h2": Style(
                  fontSize: FontSize(20.0),
                  fontWeight: FontWeight.w600,
                  color: AppColors.primary.withOpacity(0.9),
                  margin: Margins.only(top: 24, bottom: 8),
                  border: const Border(
                    bottom: BorderSide(color: AppColors.secondary, width: 2),
                  ),
                  padding: HtmlPaddings.only(bottom: 4),
                ),
                "p": Style(margin: Margins.only(bottom: 12)),
                "ul": Style(margin: Margins.only(left: 16, bottom: 12)),
                "li": Style(margin: Margins.only(bottom: 8)),
                "a": Style(
                  color: AppColors.secondary,
                  textDecoration: TextDecoration.none,
                ),
                "strong": Style(
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
                ".warning": Style(
                  backgroundColor: Colors.orange.withOpacity(0.1),
                  border: Border(
                    left: BorderSide(color: Colors.orange.shade700, width: 4),
                  ),
                  padding: HtmlPaddings.all(16),
                  margin: Margins.symmetric(vertical: 12),
                  fontSize: FontSize(14.0),
                ),
              },
              onLinkTap: (url, _, __) async {
                if (url != null && await canLaunchUrl(Uri.parse(url))) {
                  await launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  );
                }
              },
            ),
          );
        },
      ),
    );
  }
}
