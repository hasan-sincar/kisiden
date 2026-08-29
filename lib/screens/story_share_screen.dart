import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../utils/theme_colors.dart';
import '../utils/translations.dart';

class StoryShareScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String listingId;
  const StoryShareScreen({
    super.key,
    required this.data,
    required this.listingId,
  });

  @override
  State<StoryShareScreen> createState() => _StoryShareScreenState();
}

class _StoryShareScreenState extends State<StoryShareScreen> {
  final GlobalKey _globalKey = GlobalKey();
  bool _isSharing = false;

  Future<void> _shareStory() async {
    setState(() => _isSharing = true);
    try {
      // Ekranda oluşturduğumuz estetik widget'ı (9:16) yüksek kaliteli (3x) bir görsele dönüştürüyoruz
      RenderRepaintBoundary boundary =
          _globalKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(
        format: ui.ImageByteFormat.png,
      );

      if (byteData != null) {
        Uint8List pngBytes = byteData.buffer.asUint8List();
        final xFile = XFile.fromData(
          pngBytes,
          mimeType: 'image/png',
          name: 'kisiden_story.png',
        );

        // Görseli oluşturduktan sonra share_plus ile diğer uygulamalara aktarıyoruz
        await Share.shareXFiles(
          [xFile],
          text:
              '${tr('share_listing_msg')}\nhttps://kisiden.com/ilan?id=${widget.listingId}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('error')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    String formattedPrice = widget.data['price']
        .toString()
        .split('.')
        .first
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    String imageUrl = '';
    if (widget.data['imageUrl'] != null &&
        widget.data['imageUrl'].toString().isNotEmpty) {
      imageUrl = widget.data['imageUrl'].toString();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(tr('share_on_story'), style: LocalFonts.poppins()),
      ),
      backgroundColor: Colors.grey[200],
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: 9 / 16, // Tam bir Instagram/WhatsApp Story oranı
                child: RepaintBoundary(
                  key: _globalKey,
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFF833AB4),
                          Color(0xFFFD1D1D),
                          Color(0xFFF56040),
                        ], // Modern sıcak degrade
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(24.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          // Uygulama Rozeti
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.9),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Text(
                              'Kişiden',
                              style: LocalFonts.poppins(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 32),

                          // İlan Kartı
                          Container(
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.2),
                                  blurRadius: 15,
                                  spreadRadius: 5,
                                ),
                              ],
                            ),
                            child: Column(
                              children: [
                                ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(20),
                                  ),
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: imageUrl.isNotEmpty
                                        ? Image.network(
                                            imageUrl,
                                            fit: BoxFit.cover,
                                          )
                                        : const Icon(
                                            Icons.image,
                                            size: 80,
                                            color: Colors.grey,
                                          ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    children: [
                                      Text(
                                        widget.data['title'] ?? '',
                                        style: LocalFonts.poppins(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        '₺$formattedPrice',
                                        style: LocalFonts.poppins(
                                          fontSize: 24,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Sahte Tıklama Aksiyonu Görseli
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(
                                  Icons.touch_app,
                                  color: Colors.white,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  tr('click_for_details'),
                                  style: LocalFonts.poppins(
                                    color: Colors.white,
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // İndir/Paylaş Butonu (Görsele dahil olmaz, sadece ekranda görünür)
          Container(
            padding: const EdgeInsets.all(24.0),
            color: Colors.white,
            child: ElevatedButton.icon(
              onPressed: _isSharing ? null : _shareStory,
              icon: _isSharing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(Icons.amp_stories, color: Colors.white),
              label: Text(
                _isSharing ? tr('preparing') : tr('share_instagram_whatsapp'),
                style: LocalFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 54),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
