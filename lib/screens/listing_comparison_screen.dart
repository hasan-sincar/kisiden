import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../utils/local_fonts.dart';
import '../utils/theme_colors.dart';
import '../utils/translations.dart';

class ListingComparisonScreen extends StatelessWidget {
  const ListingComparisonScreen({super.key, required this.listings});

  final List<MapEntry<String, Map<String, dynamic>>> listings;

  Map<String, dynamic> _features(Map<String, dynamic> listing) {
    final rawFeatures = listing['features'];
    if (rawFeatures is Map) {
      return Map<String, dynamic>.from(rawFeatures);
    }
    return const {};
  }

  String _value(dynamic value) {
    if (value == null || value.toString().trim().isEmpty) {
      return tr('not_specified');
    }
    if (value is Iterable) {
      final values = value
          .map((item) => item.toString().trim())
          .where((item) => item.isNotEmpty)
          .toList();
      return values.isEmpty ? tr('not_specified') : values.join(', ');
    }
    return value.toString();
  }

  String _price(Map<String, dynamic> listing) {
    final price = num.tryParse(listing['price']?.toString() ?? '');
    if (price == null) return tr('not_specified');
    return NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    ).format(price);
  }

  String _location(Map<String, dynamic> listing) {
    final features = _features(listing);
    final parts = [
      listing['city']?.toString(),
      listing['district']?.toString(),
      features['Mahalle']?.toString(),
    ].where((part) => part != null && part.trim().isNotEmpty).toList();
    return parts.isEmpty ? tr('not_specified') : parts.join(', ');
  }

  Widget _buildListingCard(
    BuildContext context,
    MapEntry<String, Map<String, dynamic>> listing,
    int index,
    List<String> featureNames,
    double cardWidth,
  ) {
    final data = listing.value;
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = data['imageUrl']?.toString() ?? '';
    final rows = <({String label, String value})>[
      (
        label: tr('category'),
        value: _value(data['categoryPath'] ?? data['category']),
      ),
      (label: tr('location'), value: _location(data)),
      (label: tr('description'), value: _value(data['description'])),
      for (final name in featureNames)
        (label: name, value: _value(_features(data)[name])),
    ];

    return SizedBox(
      width: cardWidth,
      child: Card(
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        elevation: 2,
        shadowColor: Colors.black.withValues(alpha: 0.08),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: Colors.grey.shade200),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                if (imageUrl.isNotEmpty)
                  Image.network(
                    imageUrl,
                    width: double.infinity,
                    height: 170,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _imagePlaceholder(width: cardWidth, height: 170),
                  )
                else
                  _imagePlaceholder(width: cardWidth, height: 170),
                Positioned(
                  top: 12,
                  left: 12,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.95),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${index + 1} / ${listings.length}',
                      style: LocalFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _value(data['title']),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.primaryContainer.withValues(
                        alpha: 0.55,
                      ),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('price'),
                          style: LocalFonts.poppins(
                            fontSize: 11,
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _price(data),
                          style: LocalFonts.poppins(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  for (var rowIndex = 0; rowIndex < rows.length; rowIndex++)
                    _buildDetailRow(
                      rows[rowIndex].label,
                      rows[rowIndex].value,
                      color: rowIndex.isEven
                          ? Colors.grey.shade50
                          : Colors.white,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, {required Color color}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      margin: const EdgeInsets.only(bottom: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: LocalFonts.poppins(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: label == tr('description') ? 5 : 3,
            overflow: TextOverflow.ellipsis,
            style: LocalFonts.poppins(fontSize: 13, color: Colors.black87),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final featureNames = <String>[];
    for (final listing in listings) {
      for (final name in _features(listing.value).keys) {
        if (!featureNames.contains(name)) featureNames.add(name);
      }
    }
    final colorScheme = Theme.of(context).colorScheme;
    final screenWidth = MediaQuery.sizeOf(context).width;
    final cardWidth = (screenWidth * 0.82).clamp(280.0, 360.0);

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        title: Text(
          tr('compare_listings'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(
                    Icons.compare_arrows_rounded,
                    color: colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tr('comparison_swipe_hint'),
                    style: LocalFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (var index = 0; index < listings.length; index++) ...[
                      if (index > 0) const SizedBox(width: 14),
                      _buildListingCard(
                        context,
                        listings[index],
                        index,
                        featureNames,
                        cardWidth,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _imagePlaceholder({required double width, required double height}) {
    return Container(
      width: width,
      height: height,
      color: Colors.grey[200],
      alignment: Alignment.center,
      child: Icon(Icons.image_outlined, color: Colors.grey[500], size: 36),
    );
  }
}
