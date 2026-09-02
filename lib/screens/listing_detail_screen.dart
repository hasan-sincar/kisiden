import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:share_plus/share_plus.dart';
import '../services/database_service.dart';
import 'chat_screen.dart';
import '../utils/auth_gate.dart';
import '../utils/theme_colors.dart';
import 'seller_profile_screen.dart';
import 'package:flutter/foundation.dart'; // YENİ: Web platform kontrolü için
import 'package:meta_seo/meta_seo.dart'; // YENİ: SEO Meta etiketleri için
import '../utils/translations.dart';
import 'story_share_screen.dart'; // YENİ: Hikaye paylaşım ekranı

String formatRelativeTime(dynamic timestamp) {
  if (timestamp == null) return '';

  DateTime dateTime;
  if (timestamp is Timestamp) {
    dateTime = timestamp.toDate();
  } else if (timestamp is DateTime) {
    dateTime = timestamp;
  } else if (timestamp is String) {
    dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
  } else {
    return '';
  }

  final now = DateTime.now();
  final difference = now.difference(dateTime);

  if (difference.isNegative || difference.inSeconds < 45) {
    return tr('time_just_now');
  }
  if (difference.inMinutes < 60) {
    final minutes = difference.inMinutes;
    return minutes == 1
        ? tr('time_one_minute_ago')
        : tr('time_minutes_ago').replaceFirst('%s', '$minutes');
  }
  if (difference.inHours < 24) {
    final hours = difference.inHours;
    return hours == 1
        ? tr('time_one_hour_ago')
        : tr('time_hours_ago').replaceFirst('%s', '$hours');
  }
  if (difference.inDays < 7) {
    final days = difference.inDays;
    return days == 1
        ? tr('time_one_day_ago')
        : tr('time_days_ago').replaceFirst('%s', '$days');
  }
  if (difference.inDays < 30) {
    final weeks = (difference.inDays / 7).floor();
    return weeks == 1
        ? tr('time_one_week_ago')
        : tr('time_weeks_ago').replaceFirst('%s', '$weeks');
  }
  if (difference.inDays < 365) {
    final months = (difference.inDays / 30).floor();
    return months == 1
        ? tr('time_one_month_ago')
        : tr('time_months_ago').replaceFirst('%s', '$months');
  }

  final years = (difference.inDays / 365).floor();
  return years == 1
      ? tr('time_one_year_ago')
      : tr('time_years_ago').replaceFirst('%s', '$years');
}

class ListingDetailScreen extends StatefulWidget {
  final Map<String, dynamic> data;
  final String listingId;
  const ListingDetailScreen({
    super.key,
    required this.data,
    required this.listingId,
  });
  @override
  State<ListingDetailScreen> createState() => _ListingDetailScreenState();
}

class _ListingDetailScreenState extends State<ListingDetailScreen> {
  final DatabaseService _dbService = DatabaseService();
  final TextEditingController _questionController = TextEditingController();
  int _currentImageIndex = 0;
  bool _isDescriptionExpanded = false;
  Map<String, String> _featureLabelMap = {};
  Map<String, Map<String, String>> _featureOptionMap = {};

  Future<bool> _requireRegisteredUser() async {
    return AuthGate.requireRegisteredUser(
      context,
      message:
          'İletişim bilgilerini görmek ve satıcıyla iletişime geçmek için giriş yapmalısınız.',
    );
  }

  @override
  void initState() {
    super.initState();
    _loadFeatureLocalizationMaps();
    _dbService.incrementViewCount(
      widget.listingId,
    ); // İlan detayı her açıldığında görüntülenmeyi 1 artırır
  }

  Future<void> _loadFeatureLocalizationMaps() async {
    try {
      final categoryId = widget.data['categoryId']?.toString() ?? '';
      if (categoryId.isEmpty) return;

      final doc = await FirebaseFirestore.instance
          .collection('categories')
          .doc(categoryId)
          .get();
      if (!doc.exists || !mounted) return;

      final data = doc.data() as Map<String, dynamic>? ?? {};
      final rawFeatures = data['features'];
      if (rawFeatures is! List) return;

      final labelMap = <String, String>{};
      final optionMap = <String, Map<String, String>>{};

      for (final item in rawFeatures) {
        if (item is! Map) continue;
        final feature = Map<String, dynamic>.from(item);
        final rawName = (feature['name'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;

        final localizedName = getTranslatedText(feature, 'name').trim();
        if (localizedName.isNotEmpty) {
          labelMap[rawName] = localizedName;
        }

        final rawOptions = feature['options'];
        final localizedOptions = getTranslatedList(feature, 'options');
        if (rawOptions is List &&
            localizedOptions.isNotEmpty &&
            rawOptions.length == localizedOptions.length) {
          final byValue = <String, String>{};
          for (var i = 0; i < rawOptions.length; i++) {
            final rawOption = rawOptions[i].toString();
            final localizedOption = localizedOptions[i].toString();
            byValue[rawOption] = localizedOption;
          }
          if (byValue.isNotEmpty) {
            optionMap[rawName] = byValue;
          }
        }
      }

      if (!mounted) return;
      setState(() {
        _featureLabelMap = labelMap;
        _featureOptionMap = optionMap;
      });
    } catch (_) {}
  }

  String _localizedFeatureKey(String rawKey) {
    final k = rawKey.trim();
    if (k.isEmpty) return rawKey;
    if (_featureLabelMap.containsKey(k)) {
      return _featureLabelMap[k]!;
    }

    final lower = k.toLowerCase();
    if (lower == 'marka') return tr('brand');
    if (lower == 'seri') return tr('series');
    if (lower == 'model') return tr('model');
    if (lower == 'paket') return tr('package');
    if (lower == 'mahalle') return tr('neighborhood');
    return rawKey;
  }

  String _localizedFeatureValue(String rawKey, String rawValue) {
    final map = _featureOptionMap[rawKey.trim()];
    if (map != null && map.containsKey(rawValue)) {
      return map[rawValue]!;
    }
    return rawValue;
  }

  @override
  void dispose() {
    _questionController.dispose();
    super.dispose();
  }

  Future<void> _makePhoneCall(BuildContext context, String phoneNumber) async {
    if (!await _requireRegisteredUser()) return;
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    }
  }

  Future<void> _openWhatsApp(BuildContext context, String phoneNumber) async {
    if (!await _requireRegisteredUser()) return;
    String cleanPhone = phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (cleanPhone.startsWith('0')) {
      cleanPhone = '90${cleanPhone.substring(1)}';
    } else if (!cleanPhone.startsWith('90')) {
      cleanPhone = '90$cleanPhone';
    }

    String listingUrl = "https://kisiden.com/ilan?id=${widget.listingId}";
    String message = "${tr('i_want_to_get_details')}\n$listingUrl";

    final Uri whatsappUri = Uri.parse(
      "https://wa.me/$cleanPhone?text=${Uri.encodeComponent(message)}",
    );
    if (await canLaunchUrl(whatsappUri)) {
      await launchUrl(whatsappUri, mode: LaunchMode.externalApplication);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('cannot_open_link'))));
      }
    }
  }

  void _openFullGallery(List<String> images, int initialIndex) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            FullScreenGallery(images: images, initialIndex: initialIndex),
      ),
    );
  }

  Widget _buildDetailRow(String key, String value, {bool isRed = false}) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  key,
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: LocalFonts.poppins(
                    fontSize: 13,
                    fontWeight: isRed ? FontWeight.w500 : FontWeight.normal,
                    color: isRed ? Colors.red[600] : Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        ),
        const DottedLine(),
      ],
    );
  }

  Widget _buildCopyableDetailRow(String key, String value) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10.0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  key,
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                    color: Colors.grey[900],
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        value,
                        style: LocalFonts.poppins(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.red[600],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        await Clipboard.setData(ClipboardData(text: value));
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'İlan numarası kopyalandı.',
                              style: LocalFonts.poppins(),
                            ),
                            duration: const Duration(milliseconds: 1200),
                          ),
                        );
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.blue.withValues(alpha: 0.08),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.copy_rounded,
                          size: 16,
                          color: Colors.blue[800],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const DottedLine(),
      ],
    );
  }

  Widget _buildAdminChangeSummaryCard(Map<String, dynamic> summary) {
    final rawChanges = summary['changes'];
    final Timestamp? ts = summary['updatedAt'] as Timestamp?;
    if (rawChanges is! Map) return const SizedBox.shrink();

    final changes = Map<String, dynamic>.from(rawChanges);
    if (changes.isEmpty) return const SizedBox.shrink();

    String updatedAtText = '';
    if (ts != null) {
      final d = ts.toDate();
      updatedAtText =
          '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
    }

    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.orange.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.edit_note, color: Colors.deepOrange, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Düzenlenen Alanlar',
                  style: LocalFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: Colors.deepOrange[800],
                  ),
                ),
              ),
            ],
          ),
          if (updatedAtText.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Güncelleme: $updatedAtText',
              style: LocalFonts.poppins(fontSize: 11, color: Colors.grey[700]),
            ),
          ],
          const SizedBox(height: 10),
          ...changes.entries.map((entry) {
            final value = entry.value is Map<String, dynamic>
                ? Map<String, dynamic>.from(entry.value)
                : <String, dynamic>{};
            final before = value['before']?.toString() ?? '-';
            final after = value['after']?.toString() ?? '-';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    entry.key,
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Önce: $before',
                    style: LocalFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[700],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Sonra: $after',
                    style: LocalFonts.poppins(
                      fontSize: 11,
                      color: Colors.deepOrange[900],
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  void _shareListing() {
    String shareUrl = "https://kisiden.com/ilan?id=${widget.listingId}";
    String formattedPrice = widget.data['price']
        .toString()
        .split('.')
        .first
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
    String message =
        "${tr('share_listing_msg')}\n${widget.data['title']}\n${tr('price')}: ₺$formattedPrice\n\n${tr('click_for_details')} $shareUrl";
    Share.share(message);
  }

  void _reportListing() {
    showDialog(
      context: context,
      builder: (context) {
        String reason = "";
        return AlertDialog(
          title: Text(
            tr('report_listing'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          content: TextField(
            onChanged: (val) => reason = val,
            decoration: InputDecoration(
              hintText: tr('report_reason_hint'),
              border: const OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(tr('cancel')),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () async {
                if (reason.isNotEmpty) {
                  await _dbService.reportListing(widget.listingId, reason);
                  if (context.mounted) {
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('report_sent_to_admin'))),
                    );
                  }
                }
              },
              child: Text(
                tr('report'),
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  void _answerDialog(
    String questionId,
    String questionText,
    String askerId,
    String sellerId,
  ) {
    final TextEditingController answerController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          tr('reply'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${tr('question')}: $questionText',
              style: LocalFonts.poppins(
                fontWeight: FontWeight.w600,
                color: Colors.blue[800],
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: answerController,
              decoration: InputDecoration(
                hintText: tr('answer_hint'),
                border: const OutlineInputBorder(),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              if (answerController.text.trim().isNotEmpty) {
                final submitted = await _dbService.answerQuestion(
                  widget.listingId,
                  questionId,
                  answerController.text.trim(),
                  askerId,
                  sellerId,
                );
                if (submitted && context.mounted) {
                  answerController.clear();
                  Navigator.pop(context);
                }
              }
            },
            child: Text(
              tr('reply'),
              style: const TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    ).whenComplete(answerController.dispose);
  }

  String _maskName(String fullName) {
    List<String> parts = fullName.trim().split(' ');
    if (parts.length > 1 && parts.last.isNotEmpty)
      return "${parts.first} ${parts.last[0].toUpperCase()}.";
    return fullName;
  }

  // İl ve İlçe isimlerini "İstanbul, Avcılar" formatına çeviren fonksiyon
  String _formatLocation(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;

    // YENİ: Web için SEO Meta etiketlerini dinamik olarak sayfaya işliyoruz
    if (kIsWeb) {
      MetaSEO meta = MetaSEO();
      String title = widget.data['title'] ?? tr('seo_listing_default_title');
      String desc =
          widget.data['description'] ?? tr('seo_listing_default_desc');
      List<String> allImagesForSeo = [];
      if (widget.data['imageUrl'] != null &&
          widget.data['imageUrl'].toString().isNotEmpty)
        allImagesForSeo.add(widget.data['imageUrl'].toString());
      if (widget.data['additionalImages'] != null) {
        for (var img in widget.data['additionalImages']) {
          if (img.toString().isNotEmpty) allImagesForSeo.add(img.toString());
        }
      }
      if (allImagesForSeo.isEmpty) allImagesForSeo.add('');
      String categoryDisplayForSeo =
          widget.data['categoryPath']?.replaceAll(' > ', ' / ') ??
          widget.data['category'] ??
          tr('not_specified');

      if (desc.length > 150)
        desc =
            '${desc.substring(0, 147)}...'; // SEO için açıklama uzunluğu sınırlandırması

      meta.author(author: widget.data['sellerName'] ?? tr('app_name'));
      meta.description(description: desc);
      meta.keywords(
        keywords:
            '${tr('seo_keyword_app')}, ${tr('seo_keyword_listing')}, ${categoryDisplayForSeo.replaceAll(' / ', ', ')}, ${widget.data['city']}, ${widget.data['district']}',
      );
      meta.ogTitle(ogTitle: title);
      meta.ogDescription(ogDescription: desc);
      meta.ogImage(ogImage: allImagesForSeo.first);
    }

    // YENİ: Tarayıcı sekme başlığını (Title) dinamik olarak değiştirir
    return Title(
      title:
          '${widget.data['title'] ?? tr('listing_detail')} - ${tr('app_name')}',
      color: Colors.blue,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(tr('listing_detail'), style: LocalFonts.poppins()),
          actions: [
            // YENİ: Gelişmiş Paylaşım Menüsü (Link vs Hikaye)
            PopupMenuButton<String>(
              icon: const Icon(Icons.share),
              onSelected: (value) {
                if (value == 'link') _shareListing();
                if (value == 'story')
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => StoryShareScreen(
                        data: widget.data,
                        listingId: widget.listingId,
                      ),
                    ),
                  );
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'link',
                  child: Row(
                    children: [
                      const Icon(Icons.link, color: Colors.blue),
                      const SizedBox(width: 8),
                      Text(tr('share_as_link')),
                    ],
                  ),
                ),
                PopupMenuItem(
                  value: 'story',
                  child: Row(
                    children: [
                      const Icon(Icons.amp_stories, color: Colors.purple),
                      const SizedBox(width: 8),
                      Text(tr('share_as_story')),
                    ],
                  ),
                ),
              ],
            ),
            if (AuthGate.isRegistered &&
                currentUser?.uid != widget.data['sellerId'])
              StreamBuilder<bool>(
                stream: _dbService.isFavoriteStream(widget.listingId),
                builder: (context, snapshot) {
                  bool isFav = snapshot.data ?? false;
                  return IconButton(
                    icon: Icon(
                      isFav ? Icons.favorite : Icons.favorite_border,
                      color: isFav ? Colors.red : null,
                    ),
                    onPressed: () =>
                        _dbService.toggleFavorite(widget.listingId, isFav),
                  );
                },
              ),
            if (AuthGate.isRegistered &&
                currentUser?.uid != widget.data['sellerId'])
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'report') _reportListing();
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'report',
                    child: Row(
                      children: [
                        const Icon(Icons.report, color: Colors.red),
                        const SizedBox(width: 8),
                        Text(tr('report_listing')),
                      ],
                    ),
                  ),
                ],
              ),
          ],
        ),
        body: StreamBuilder<DocumentSnapshot>(
          stream: FirebaseFirestore.instance
              .collection('listings')
              .doc(widget.listingId)
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            if (!snapshot.data!.exists)
              return Center(
                child: Text(
                  tr('this_listing_deleted'),
                  style: LocalFonts.poppins(),
                ),
              );
            var listingData =
                snapshot.data!.data() as Map<String, dynamic>? ?? {};

            String sellerId = listingData['sellerId'] ?? '';
            String sellerName =
                listingData['sellerName'] ?? tr('anonymous_seller');
            String sellerPhone = listingData['sellerPhone'] ?? '';
            bool isMyListing = currentUser?.uid == sellerId;

            String dateStr = tr('unknown');
            if (listingData['createdAt'] != null &&
                listingData['createdAt'] is Timestamp) {
              DateTime dt = (listingData['createdAt'] as Timestamp).toDate();
              final monthNames = [
                "",
                tr('month_january'),
                tr('month_february'),
                tr('month_march'),
                tr('month_april'),
                tr('month_may'),
                tr('month_june'),
                tr('month_july'),
                tr('month_august'),
                tr('month_september'),
                tr('month_october'),
                tr('month_november'),
                tr('month_december'),
              ];
              dateStr = "${dt.day} ${monthNames[dt.month]} ${dt.year}";
            }
            String listingNo =
                listingData['listingNo'] ??
                widget.listingId
                    .replaceAll(RegExp(r'[^0-9]'), '')
                    .padRight(8, '0')
                    .substring(0, 8);
            List<String> allImages = [];
            if (listingData['imageUrl'] != null &&
                listingData['imageUrl'].toString().isNotEmpty)
              allImages.add(listingData['imageUrl'].toString());
            if (listingData['additionalImages'] != null) {
              for (var img in listingData['additionalImages']) {
                if (img.toString().isNotEmpty) allImages.add(img.toString());
              }
            }
            if (allImages.isEmpty) allImages.add('');

            Map<String, dynamic> featuresMap = {};
            if (listingData['features'] is Map) {
              featuresMap = Map<String, dynamic>.from(listingData['features']);
            }

            String mahalle = featuresMap['Mahalle']?.toString() ?? '';
            String marka = featuresMap['Marka']?.toString() ?? '';
            String seri = featuresMap['Seri']?.toString() ?? '';
            String model = featuresMap['Model']?.toString() ?? '';
            String paket = featuresMap['Paket']?.toString() ?? '';

            featuresMap.remove('Mahalle');
            featuresMap.remove('Marka');
            featuresMap.remove('Seri');
            featuresMap.remove('Model');
            featuresMap.remove('Paket');

            String locationText = '';
            if (listingData['city'] != null &&
                listingData['district'] != null) {
              locationText =
                  '${_formatLocation(listingData['city'])}, ${_formatLocation(listingData['district'])}';
              if (mahalle.isNotEmpty) {
                locationText += ', ${_formatLocation(mahalle)}';
              }
            }

            // Özellikleri sıralamak için liste haline getiriyoruz (Örn: Marka > Model > Diğerleri)
            var sortedFeatures = featuresMap.entries.toList();
            sortedFeatures.sort((a, b) {
              int getWeight(String key) {
                String k = key.toLowerCase();
                if (k == 'marka') return 0;
                if (k == 'model') return 1;
                if (k == 'yıl') return 2;
                return 99; // Diğerleri varsayılan olarak alta eklensin
              }

              int wA = getWeight(a.key);
              int wB = getWeight(b.key);
              if (wA != wB) return wA.compareTo(wB);
              return a.key.compareTo(
                b.key,
              ); // İkisi de aynı ağırlıktaysa alfabetik diz
            });

            String formattedPrice = (listingData['price'] ?? 0)
                .toString()
                .split('.')
                .first
                .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');
            final bool isAdminViewer =
                currentUser?.email == 'hasanmardinn@gmail.com';
            final summaryRaw = listingData['lastEditChangeSummary'];
            final editSummary = summaryRaw is Map<String, dynamic>
                ? summaryRaw
                : (summaryRaw is Map
                      ? Map<String, dynamic>.from(summaryRaw)
                      : null);

            return Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: 320,
                              width: double.infinity,
                              child: PageView.builder(
                                onPageChanged: (index) =>
                                    setState(() => _currentImageIndex = index),
                                itemCount: allImages.length,
                                itemBuilder: (context, index) {
                                  String currentImg = allImages[index];
                                  return GestureDetector(
                                    onTap: () =>
                                        _openFullGallery(allImages, index),
                                    child: Container(
                                      width: double.infinity,
                                      color: Colors.grey[100],
                                      child: currentImg.isNotEmpty
                                          ? Image.network(
                                              currentImg,
                                              fit: BoxFit.cover,
                                              errorBuilder: (c, e, s) =>
                                                  const Icon(
                                                    Icons.image_not_supported,
                                                    size: 50,
                                                    color: Colors.grey,
                                                  ),
                                            )
                                          : const Icon(
                                              Icons.image_not_supported,
                                              size: 50,
                                              color: Colors.grey,
                                            ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            if (allImages.length > 1)
                              Positioned(
                                bottom: 16,
                                left: 0,
                                right: 0,
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    allImages.length,
                                    (index) => AnimatedContainer(
                                      duration: const Duration(
                                        milliseconds: 300,
                                      ),
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                      ),
                                      height: 8,
                                      width: _currentImageIndex == index
                                          ? 24
                                          : 8,
                                      decoration: BoxDecoration(
                                        color: _currentImageIndex == index
                                            ? Colors.blue[800]
                                            : Colors.white.withValues(
                                                alpha: 0.8,
                                              ),
                                        borderRadius: BorderRadius.circular(4),
                                        boxShadow: const [
                                          BoxShadow(
                                            color: Colors.black26,
                                            blurRadius: 4,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.all(20.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '₺$formattedPrice',
                                style: LocalFonts.poppins(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blue[800],
                                ),
                              ),

                              const SizedBox(height: 8),
                              Text(
                                listingData['title'] ?? '',
                                style: LocalFonts.poppins(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const DottedLine(),
                              _buildCopyableDetailRow(
                                tr('listing_no'),
                                listingNo,
                              ),
                              _buildDetailRow(tr('listing_date'), dateStr),
                              if (locationText.isNotEmpty)
                                _buildDetailRow(tr('location'), locationText),
                              if (marka.isNotEmpty)
                                _buildDetailRow(
                                  tr('brand'),
                                  _localizedFeatureValue('Marka', marka),
                                ),
                              if (seri.isNotEmpty)
                                _buildDetailRow(
                                  tr('series'),
                                  _localizedFeatureValue('Seri', seri),
                                ),
                              if (model.isNotEmpty)
                                _buildDetailRow(
                                  tr('model'),
                                  _localizedFeatureValue('Model', model),
                                ),
                              if (paket.isNotEmpty)
                                _buildDetailRow(
                                  tr('package'),
                                  _localizedFeatureValue('Paket', paket),
                                ),
                              ...sortedFeatures.map(
                                (entry) => _buildDetailRow(
                                  _localizedFeatureKey(entry.key),
                                  _localizedFeatureValue(
                                    entry.key,
                                    entry.value.toString(),
                                  ),
                                ),
                              ),

                              if (isAdminViewer && editSummary != null)
                                _buildAdminChangeSummaryCard(editSummary),

                              const SizedBox(height: 24),
                              Text(
                                tr('description'),
                                style: LocalFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    listingData['description'] ?? '',
                                    style: LocalFonts.poppins(
                                      fontSize: 15,
                                      height: 1.5,
                                      color: Colors.black87,
                                    ),
                                    maxLines: _isDescriptionExpanded ? null : 5,
                                    overflow: _isDescriptionExpanded
                                        ? TextOverflow.visible
                                        : TextOverflow.ellipsis,
                                  ),
                                  if ((listingData['description'] ?? '')
                                          .length >
                                      200)
                                    InkWell(
                                      onTap: () => setState(
                                        () => _isDescriptionExpanded =
                                            !_isDescriptionExpanded,
                                      ),
                                      child: Padding(
                                        padding: const EdgeInsets.only(
                                          top: 8.0,
                                        ),
                                        child: Text(
                                          _isDescriptionExpanded
                                              ? tr('show_less')
                                              : tr('read_more'),
                                          style: LocalFonts.poppins(
                                            color: Colors.blue[800],
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 30),
                              const Divider(height: 50),
                              Text(
                                tr('q_and_a'),
                                style: LocalFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),

                              if (!isMyListing)
                                StreamBuilder<DocumentSnapshot>(
                                  stream: currentUser != null
                                      ? FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(currentUser.uid)
                                            .snapshots()
                                      : null,
                                  builder: (context, userSnap) {
                                    bool isBlocked = false;
                                    if (userSnap.hasData &&
                                        userSnap.data!.exists) {
                                      var userData =
                                          userSnap.data!.data()
                                              as Map<String, dynamic>;
                                      List<String> hiddenUsers = [
                                        ...List<String>.from(
                                          userData['blockedUsers'] ?? [],
                                        ),
                                        ...List<String>.from(
                                          userData['blockedBy'] ?? [],
                                        ),
                                      ];
                                      isBlocked = hiddenUsers.contains(
                                        sellerId,
                                      );
                                    }
                                    if (isBlocked)
                                      return Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        child: Container(
                                          padding: const EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: Colors.red[50],
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            border: Border.all(
                                              color: Colors.red.shade200,
                                            ),
                                          ),
                                          child: Row(
                                            children: [
                                              const Icon(
                                                Icons.block,
                                                color: Colors.red,
                                              ),
                                              const SizedBox(width: 8),
                                              Expanded(
                                                child: Text(
                                                  tr(
                                                    'cannot_contact_blocked_seller',
                                                  ),
                                                  style: LocalFonts.poppins(
                                                    color: Colors.red[800],
                                                    fontSize: 13,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      );
                                    return Container(
                                      margin: const EdgeInsets.only(
                                        bottom: 16.0,
                                      ),
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(18),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Expanded(
                                            child: TextField(
                                              controller: _questionController,
                                              readOnly: !AuthGate.isRegistered,
                                              onTap: () {
                                                if (!AuthGate.isRegistered) {
                                                  AuthGate.requireRegisteredUser(
                                                    context,
                                                    message:
                                                        'Soru-cevap bölümünü kullanmak için giriş yapmalısınız.',
                                                  );
                                                }
                                              },
                                              decoration: InputDecoration(
                                                hintText: tr(
                                                  'ask_question_hint',
                                                ),
                                                filled: true,
                                                fillColor: Colors.grey[50],
                                                border: OutlineInputBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(14),
                                                  borderSide: BorderSide.none,
                                                ),
                                                enabledBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide:
                                                          BorderSide.none,
                                                    ),
                                                focusedBorder:
                                                    OutlineInputBorder(
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            14,
                                                          ),
                                                      borderSide: BorderSide(
                                                        color: Colors
                                                            .blue
                                                            .shade200,
                                                        width: 1.2,
                                                      ),
                                                    ),
                                                contentPadding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 14,
                                                      vertical: 12,
                                                    ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          Container(
                                            decoration: BoxDecoration(
                                              color: Colors.blue[800],
                                              shape: BoxShape.circle,
                                            ),
                                            child: IconButton(
                                              icon: const Icon(
                                                Icons.send_rounded,
                                                color: Colors.white,
                                                size: 18,
                                              ),
                                              onPressed: () async {
                                                if (!await AuthGate.requireRegisteredUser(
                                                  context,
                                                  message:
                                                      'Soru-cevap bölümünü kullanmak için giriş yapmalısınız.',
                                                ))
                                                  return;
                                                if (_questionController.text
                                                    .trim()
                                                    .isNotEmpty) {
                                                  final submitted =
                                                      await _dbService.askQuestion(
                                                        widget.listingId,
                                                        sellerId,
                                                        _questionController.text
                                                            .trim(),
                                                        listingData['title'] ??
                                                            '',
                                                      );
                                                  if (submitted && mounted) {
                                                    _questionController.clear();
                                                    FocusManager
                                                        .instance
                                                        .primaryFocus
                                                        ?.unfocus();
                                                  }
                                                }
                                              },
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  },
                                ),

                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('listings')
                                    .doc(widget.listingId)
                                    .collection('questions')
                                    .orderBy('timestamp', descending: true)
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return const SizedBox();
                                  var questions = snapshot.data!.docs;
                                  if (questions.isEmpty)
                                    return Container(
                                      padding: const EdgeInsets.all(16),
                                      decoration: BoxDecoration(
                                        color: Colors.transparent,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              shape: BoxShape.circle,
                                              border: Border.all(
                                                color: Colors.grey.shade300,
                                              ),
                                            ),
                                            child: Icon(
                                              Icons.chat_bubble_outline_rounded,
                                              color: Colors.blue[800],
                                              size: 18,
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          Expanded(
                                            child: Text(
                                              tr('no_questions_asked'),
                                              style: LocalFonts.poppins(
                                                color: Colors.grey[700],
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    );
                                  return ListView.builder(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: questions.length,
                                    itemBuilder: (context, index) {
                                      var q =
                                          questions[index].data()
                                              as Map<String, dynamic>;
                                      String qId = questions[index].id;
                                      bool hasAnswer =
                                          q['answer'] != null &&
                                          q['answer'].toString().isNotEmpty;
                                      String displayAskerName =
                                          (q['userId'] == sellerId)
                                          ? (widget.data['sellerName'] ??
                                                tr('seller'))
                                          : _maskName(
                                              q['userName'] ?? tr('user'),
                                            );

                                      List<dynamic> replies = List.from(
                                        q['replies'] ?? [],
                                      );
                                      if (hasAnswer && replies.isEmpty) {
                                        replies.add({
                                          'userId': sellerId,
                                          'userName': tr('seller'),
                                          'message': q['answer'],
                                        });
                                      }

                                      bool isMyQuestion =
                                          currentUser?.uid == q['userId'];
                                      bool canReply =
                                          isMyListing || isMyQuestion;
                                      final questionTime = formatRelativeTime(
                                        q['timestamp'],
                                      );
                                      final askerId =
                                          q['userId']?.toString() ?? '';

                                      return Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 16.0,
                                        ),
                                        padding: const EdgeInsets.all(14),
                                        decoration: BoxDecoration(
                                          color: Colors.transparent,
                                          borderRadius: BorderRadius.circular(
                                            18,
                                          ),
                                          border: Border.all(
                                            color: Colors.grey.shade300,
                                          ),
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                GestureDetector(
                                                  onTap: askerId.isNotEmpty
                                                      ? () {
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  SellerProfileScreen(
                                                                    sellerId:
                                                                        askerId,
                                                                  ),
                                                            ),
                                                          );
                                                        }
                                                      : null,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.transparent,
                                                      shape: BoxShape.circle,
                                                      border: Border.all(
                                                        color: Colors
                                                            .grey
                                                            .shade300,
                                                      ),
                                                    ),
                                                    child: Icon(
                                                      Icons
                                                          .help_outline_rounded,
                                                      size: 16,
                                                      color: Colors.blue[800],
                                                    ),
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Row(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .center,
                                                        children: [
                                                          Expanded(
                                                            child: Text(
                                                              displayAskerName,
                                                              style: LocalFonts.poppins(
                                                                fontSize: 11,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                color: Colors
                                                                    .grey[700],
                                                              ),
                                                            ),
                                                          ),
                                                          if (questionTime
                                                              .isNotEmpty)
                                                            Text(
                                                              questionTime,
                                                              style: LocalFonts.poppins(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                            ),
                                                        ],
                                                      ),
                                                      const SizedBox(height: 2),
                                                      Text(
                                                        q['question'] ?? '',
                                                        style:
                                                            LocalFonts.poppins(
                                                              fontSize: 13,
                                                              color: Colors
                                                                  .black87,
                                                              height: 1.4,
                                                            ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 10),
                                            ...replies.map((reply) {
                                              bool isSeller =
                                                  reply['userId'] == sellerId;
                                              String replierName = isSeller
                                                  ? (widget.data['sellerName'] ??
                                                        tr('seller'))
                                                  : _maskName(
                                                      reply['userName'] ??
                                                          tr('user'),
                                                    );
                                              final replyTime =
                                                  formatRelativeTime(
                                                    reply['timestamp'],
                                                  );
                                              return Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8.0,
                                                ),
                                                child: Row(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  mainAxisAlignment: isSeller
                                                      ? MainAxisAlignment.end
                                                      : MainAxisAlignment.start,
                                                  children: isSeller
                                                      ? [
                                                          Expanded(
                                                            child: Container(
                                                              margin:
                                                                  const EdgeInsets.only(
                                                                    left: 24,
                                                                  ),
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .transparent,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      14,
                                                                    ),
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Row(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .center,
                                                                    children: [
                                                                      Expanded(
                                                                        child: Text(
                                                                          replierName,
                                                                          style: LocalFonts.poppins(
                                                                            fontSize:
                                                                                10,
                                                                            color:
                                                                                Colors.green[800],
                                                                            fontWeight:
                                                                                FontWeight.bold,
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      if (replyTime
                                                                          .isNotEmpty)
                                                                        Text(
                                                                          replyTime,
                                                                          style: LocalFonts.poppins(
                                                                            fontSize:
                                                                                10,
                                                                            color:
                                                                                Colors.grey[600],
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    reply['message'] ??
                                                                        '',
                                                                    style: LocalFonts.poppins(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black87,
                                                                      height:
                                                                          1.35,
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .transparent,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade300,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .storefront_rounded,
                                                              size: 16,
                                                              color: Colors
                                                                  .green[800],
                                                            ),
                                                          ),
                                                        ]
                                                      : [
                                                          Container(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  8,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color: Colors
                                                                  .transparent,
                                                              shape: BoxShape
                                                                  .circle,
                                                              border: Border.all(
                                                                color: Colors
                                                                    .grey
                                                                    .shade300,
                                                              ),
                                                            ),
                                                            child: Icon(
                                                              Icons
                                                                  .person_rounded,
                                                              size: 16,
                                                              color: Colors
                                                                  .grey[700],
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          Expanded(
                                                            child: Container(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    12,
                                                                  ),
                                                              decoration: BoxDecoration(
                                                                color: Colors
                                                                    .transparent,
                                                                borderRadius:
                                                                    BorderRadius.circular(
                                                                      14,
                                                                    ),
                                                                border: Border.all(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade300,
                                                                ),
                                                              ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                children: [
                                                                  Text(
                                                                    reply['message'] ??
                                                                        '',
                                                                    style: LocalFonts.poppins(
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black87,
                                                                      height:
                                                                          1.35,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Text(
                                                                    replierName,
                                                                    style: LocalFonts.poppins(
                                                                      fontSize:
                                                                          10,
                                                                      color: Colors
                                                                          .grey[600],
                                                                    ),
                                                                  ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                ),
                                              );
                                            }),
                                            if (canReply)
                                              Align(
                                                alignment:
                                                    Alignment.centerRight,
                                                child: TextButton.icon(
                                                  onPressed: () =>
                                                      _answerDialog(
                                                        qId,
                                                        q['question'] ?? '',
                                                        q['userId'] ?? '',
                                                        sellerId,
                                                      ),
                                                  icon: const Icon(
                                                    Icons.reply_outlined,
                                                    size: 16,
                                                  ),
                                                  label: Text(
                                                    tr('reply'),
                                                    style: LocalFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                              )
                                            else if (replies.isEmpty)
                                              Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 8,
                                                ),
                                                child: Text(
                                                  tr('seller_not_answered_yet'),
                                                  style: LocalFonts.poppins(
                                                    fontSize: 11,
                                                    fontStyle: FontStyle.italic,
                                                    color: Colors.grey,
                                                  ),
                                                ),
                                              ),
                                          ],
                                        ),
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 30),
                              const Divider(height: 1),
                              const SizedBox(height: 20),
                              Text(
                                tr('similar_listings'),
                                style: LocalFonts.poppins(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              StreamBuilder<QuerySnapshot>(
                                stream: FirebaseFirestore.instance
                                    .collection('listings')
                                    .where('status', isEqualTo: 'active')
                                    .snapshots(),
                                builder: (context, snapshot) {
                                  if (!snapshot.hasData)
                                    return const Center(
                                      child: CircularProgressIndicator(),
                                    );
                                  var similarDocs = snapshot.data!.docs
                                      .where((doc) {
                                        if (doc.id == widget.listingId)
                                          return false;
                                        var data =
                                            doc.data() as Map<String, dynamic>;
                                        return data['categoryPath'] ==
                                            listingData['categoryPath'];
                                      })
                                      .take(10)
                                      .toList();

                                  if (similarDocs.isEmpty)
                                    return Text(
                                      tr('no_similar_listings'),
                                      style: LocalFonts.poppins(
                                        color: Colors.grey,
                                        fontSize: 13,
                                      ),
                                    );

                                  return SizedBox(
                                    height: 215,
                                    child: ListView.builder(
                                      physics: const BouncingScrollPhysics(),
                                      scrollDirection: Axis.horizontal,
                                      itemCount: similarDocs.length,
                                      itemBuilder: (context, index) {
                                        var data =
                                            similarDocs[index].data()
                                                as Map<String, dynamic>;
                                        String formattedPrice = data['price']
                                            .toString()
                                            .split('.')
                                            .first
                                            .replaceAllMapped(
                                              RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                              (m) => '.',
                                            );
                                        List<String> allImages = [];
                                        if (data['imageUrl'] != null &&
                                            data['imageUrl']
                                                .toString()
                                                .isNotEmpty)
                                          allImages.add(
                                            data['imageUrl'].toString(),
                                          );
                                        if (data['additionalImages'] != null) {
                                          for (var img
                                              in data['additionalImages']) {
                                            if (img.toString().isNotEmpty)
                                              allImages.add(img.toString());
                                          }
                                        }
                                        if (allImages.isEmpty)
                                          allImages.add('');

                                        double currentPrice =
                                            double.tryParse(
                                              listingData['price'].toString(),
                                            ) ??
                                            0;
                                        double similarPrice =
                                            double.tryParse(
                                              data['price'].toString(),
                                            ) ??
                                            0;
                                        bool isFirsat =
                                            similarPrice > 0 &&
                                            similarPrice < currentPrice;

                                        return InkWell(
                                          onTap: () {
                                            FocusScope.of(context).unfocus();
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    ListingDetailScreen(
                                                      data: data,
                                                      listingId:
                                                          similarDocs[index].id,
                                                    ),
                                              ),
                                            );
                                          },
                                          child: Container(
                                            width: 155,
                                            margin: const EdgeInsets.only(
                                              right: 12,
                                              bottom: 6,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(16),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.05),
                                                  blurRadius: 8,
                                                  offset: const Offset(0, 3),
                                                ),
                                              ],
                                              border: Border.all(
                                                color: Colors.grey.shade200,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Expanded(
                                                  child: ClipRRect(
                                                    borderRadius:
                                                        const BorderRadius.vertical(
                                                          top: Radius.circular(
                                                            14,
                                                          ),
                                                        ),
                                                    child: SizedBox(
                                                      width: double.infinity,
                                                      child:
                                                          allImages
                                                              .first
                                                              .isEmpty
                                                          ? const Icon(
                                                              Icons.image,
                                                              color:
                                                                  Colors.grey,
                                                            )
                                                          : Stack(
                                                              fit: StackFit
                                                                  .expand,
                                                              children: [
                                                                Image.network(
                                                                  allImages
                                                                      .first,
                                                                  fit: BoxFit
                                                                      .cover,
                                                                  errorBuilder:
                                                                      (
                                                                        c,
                                                                        e,
                                                                        s,
                                                                      ) => const Icon(
                                                                        Icons
                                                                            .image_not_supported,
                                                                        color: Colors
                                                                            .grey,
                                                                      ),
                                                                ),
                                                                if (isFirsat)
                                                                  Positioned(
                                                                    top: 6,
                                                                    left: 6,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .green,
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.local_offer,
                                                                            color:
                                                                                Colors.white,
                                                                            size:
                                                                                10,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            tr(
                                                                              'opportunity',
                                                                            ),
                                                                            style: LocalFonts.poppins(
                                                                              color: Colors.white,
                                                                              fontSize: 10,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                                if (allImages
                                                                        .length >
                                                                    1)
                                                                  Positioned(
                                                                    bottom: 6,
                                                                    right: 6,
                                                                    child: Container(
                                                                      padding: const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            3,
                                                                      ),
                                                                      decoration: BoxDecoration(
                                                                        color: Colors
                                                                            .black
                                                                            .withValues(
                                                                              alpha: 0.65,
                                                                            ),
                                                                        borderRadius:
                                                                            BorderRadius.circular(
                                                                              8,
                                                                            ),
                                                                      ),
                                                                      child: Row(
                                                                        mainAxisSize:
                                                                            MainAxisSize.min,
                                                                        children: [
                                                                          const Icon(
                                                                            Icons.photo_library,
                                                                            color:
                                                                                Colors.white,
                                                                            size:
                                                                                10,
                                                                          ),
                                                                          const SizedBox(
                                                                            width:
                                                                                4,
                                                                          ),
                                                                          Text(
                                                                            '${allImages.length}',
                                                                            style: LocalFonts.poppins(
                                                                              color: Colors.white,
                                                                              fontSize: 10,
                                                                              fontWeight: FontWeight.bold,
                                                                            ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                    ),
                                                  ),
                                                ),
                                                Padding(
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '₺$formattedPrice',
                                                        style:
                                                            LocalFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 15,
                                                              color: Colors
                                                                  .blue[900],
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      Text(
                                                        data['title'] ?? '',
                                                        maxLines: 1,
                                                        overflow: TextOverflow
                                                            .ellipsis,
                                                        style:
                                                            LocalFonts.poppins(
                                                              fontSize: 12,
                                                              color: Colors
                                                                  .black87,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .w500,
                                                            ),
                                                      ),
                                                      const SizedBox(height: 4),
                                                      if (data['city'] !=
                                                              null &&
                                                          data['district'] !=
                                                              null)
                                                        Text(
                                                          '${_formatLocation(data['city'])}, ${_formatLocation(data['district'])}',
                                                          style:
                                                              LocalFonts.poppins(
                                                                fontSize: 10,
                                                                color: Colors
                                                                    .grey[600],
                                                              ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // --- YUKARI KALDIRILAN BUTONLAR ---
                if (!isMyListing)
                  Container(
                    padding: const EdgeInsets.fromLTRB(12, 2, 12, 5),
                    decoration: const BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.vertical(
                        top: Radius.circular(22),
                      ),
                    ),
                    child: SafeArea(
                      child: StreamBuilder<DocumentSnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('users')
                            .doc(sellerId.isEmpty ? 'unknown' : sellerId)
                            .snapshots(),
                        builder: (context, userSnap) {
                          String contactPref = 'both';
                          bool isSellerPro = false;
                          bool isReliableSeller = false;
                          if (userSnap.hasData && userSnap.data!.exists) {
                            var uData =
                                userSnap.data!.data() as Map<String, dynamic>;
                            contactPref = uData['contactPreference'] ?? 'both';
                            Timestamp? proUntil = uData['proUntil'];
                            if (proUntil != null &&
                                proUntil.toDate().isAfter(DateTime.now())) {
                              isSellerPro = true;
                            }
                            int soldCount = uData['soldCount'] ?? 0;
                            isReliableSeller = soldCount >= 3;
                          }
                          bool showCall =
                              contactPref == 'both' ||
                              contactPref == 'call_only';
                          bool showMessage =
                              contactPref == 'both' ||
                              contactPref == 'message_only';
                          bool isOfferEnabled =
                              listingData['isOfferEnabled'] ?? true;
                          bool showOffer = isOfferEnabled && !isMyListing;

                          return Row(
                            children: [
                              if (sellerId.isNotEmpty)
                                Expanded(
                                  child: _buildActionBtn(
                                    Icons.store_rounded,
                                    tr('seller'),
                                    Colors.orange[600]!,
                                    () async {
                                      if (!await _requireRegisteredUser()) {
                                        return;
                                      }
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              SellerProfileScreen(
                                                sellerId: sellerId,
                                              ),
                                        ),
                                      );
                                    },
                                    isPro: isSellerPro,
                                    isReliable: isReliableSeller,
                                  ),
                                ),
                              if (showCall && sellerPhone.isNotEmpty)
                                const SizedBox(width: 8),
                              if (showCall && sellerPhone.isNotEmpty)
                                Expanded(
                                  child: _buildActionBtn(
                                    Icons.phone,
                                    tr('call'),
                                    Colors.blue[800]!,
                                    () => _makePhoneCall(context, sellerPhone),
                                  ),
                                ),
                              if (showMessage && sellerId.isNotEmpty)
                                const SizedBox(width: 8),
                              if (showMessage && sellerId.isNotEmpty)
                                Expanded(
                                  child: _buildActionBtn(
                                    Icons.chat_bubble_rounded,
                                    tr('message'),
                                    Colors.blue[500]!,
                                    () async {
                                      if (!await _requireRegisteredUser())
                                        return;
                                      if (!context.mounted) return;
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => ChatScreen(
                                            receiverId: sellerId,
                                            receiverName: sellerName,
                                            listingTitle: listingData['title'],
                                            listingId: widget.listingId,
                                            listingImage: allImages.first,
                                            listingPrice: formattedPrice,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              if (showCall && sellerPhone.isNotEmpty)
                                const SizedBox(width: 8),
                              if (showCall && sellerPhone.isNotEmpty)
                                Expanded(
                                  child: _buildActionBtn(
                                    Icons.chat,
                                    'WhatsApp',
                                    Colors.green[600]!,
                                    () => _openWhatsApp(context, sellerPhone),
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildActionBtn(
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap, {
    bool isPro = false,
    bool isReliable = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 1),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: TextButton(
        onPressed: onTap,
        style: TextButton.styleFrom(
          foregroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Icon(icon, size: 24, color: color),
                ),
                if (isPro)
                  Positioned(
                    top: -6,
                    right: -12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(4),
                        border: Border.all(color: Colors.white, width: 1),
                      ),
                      child: Text(
                        'PRO',
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontSize: 7,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                else if (isReliable)
                  Positioned(
                    top: -4,
                    right: -8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: const BoxDecoration(
                        color: Colors.green,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.verified_user,
                        color: Colors.white,
                        size: 8,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: LocalFonts.poppins(
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}

class FullScreenGallery extends StatefulWidget {
  final List<String> images;
  final int initialIndex;

  const FullScreenGallery({
    super.key,
    required this.images,
    required this.initialIndex,
  });

  @override
  State<FullScreenGallery> createState() => _FullScreenGalleryState();
}

class _FullScreenGalleryState extends State<FullScreenGallery> {
  late final PageController _pageController;
  late final List<TransformationController> _transformationControllers;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    _transformationControllers = List.generate(
      widget.images.length,
      (_) => TransformationController(),
    );
    for (final controller in _transformationControllers) {
      controller.addListener(_onTransformationChanged);
    }
  }

  void _onTransformationChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pageController.dispose();
    for (final controller in _transformationControllers) {
      controller.removeListener(_onTransformationChanged);
      controller.dispose();
    }
    super.dispose();
  }

  void _toggleZoom(int index) {
    final controller = _transformationControllers[index];
    final isZoomed = controller.value.getMaxScaleOnAxis() > 1.01;
    controller.value = isZoomed
        ? Matrix4.identity()
        : (Matrix4.identity()..scaleByDouble(2.5, 2.5, 2.5, 1));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
      ),
      body: PageView.builder(
        itemCount: widget.images.length,
        controller: _pageController,
        onPageChanged: (index) => setState(() => _currentIndex = index),
        itemBuilder: (context, index) {
          final transformationController = _transformationControllers[index];
          return GestureDetector(
            onDoubleTap: () => _toggleZoom(index),
            child: InteractiveViewer(
              transformationController: transformationController,
              minScale: 1,
              maxScale: 4,
              panEnabled:
                  transformationController.value.getMaxScaleOnAxis() > 1.01,
              boundaryMargin: const EdgeInsets.all(80),
              clipBehavior: Clip.none,
              child: Center(
                child: Image.network(
                  widget.images[index],
                  fit: BoxFit.contain,
                  width: double.infinity,
                  errorBuilder: (c, e, s) => const Icon(
                    Icons.image_not_supported,
                    color: Colors.white,
                    size: 50,
                  ),
                ),
              ),
            ),
          );
        },
      ),
      bottomNavigationBar: widget.images.length > 1
          ? SafeArea(
              child: Container(
                color: Colors.black,
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  '${_currentIndex + 1} / ${widget.images.length}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
            )
          : null,
    );
  }
}

class DottedLine extends StatelessWidget {
  const DottedLine({super.key});
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final boxWidth = constraints.constrainWidth();
        const dashWidth = 3.0;
        const dashHeight = 1.0;
        final dashCount = (boxWidth / (2 * dashWidth)).floor();
        return Flex(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          direction: Axis.horizontal,
          children: List.generate(
            dashCount,
            (_) => SizedBox(
              width: dashWidth,
              height: dashHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(color: Colors.grey[300]),
              ),
            ),
          ),
        );
      },
    );
  }
}
