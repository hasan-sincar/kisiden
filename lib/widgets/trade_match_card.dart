import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../utils/local_fonts.dart';
import '../utils/translations.dart';

class TradeMatchCard extends StatelessWidget {
  const TradeMatchCard({
    super.key,
    required this.match,
    required this.onOpenListing,
    required this.onSendTradeOffer,
    required this.onSendMessage,
  });

  final Map<String, dynamic> match;
  final VoidCallback onOpenListing;
  final VoidCallback onSendTradeOffer;
  final VoidCallback onSendMessage;

  @override
  Widget build(BuildContext context) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );

    final score = (match['compatibilityScore'] as num?)?.toInt() ?? 0;
    final priceDiff = (match['estimatedPriceDiff'] as num?)?.toDouble() ?? 0;
    final imageUrl = (match['otherListingImage'] ?? '').toString();
    final title = (match['otherListingTitle'] ?? '').toString();
    final explanation =
        (match['explanation'] ?? tr('trade_match_explanation_default'))
            .toString();

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFD6E4FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x140D47A1),
            blurRadius: 16,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: SizedBox(
                  width: 72,
                  height: 72,
                  child: imageUrl.isEmpty
                      ? Container(
                          color: const Color(0xFFF0F4F8),
                          child: const Icon(Icons.image_outlined),
                        )
                      : CachedNetworkImage(
                          imageUrl: imageUrl,
                          fit: BoxFit.cover,
                          errorWidget: (_, __, ___) => Container(
                            color: const Color(0xFFF0F4F8),
                            child: const Icon(Icons.broken_image_outlined),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('trade_match_found'),
                      style: LocalFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: LocalFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF334E68),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFE6F4EA),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  tr(
                    'trade_compatibility_percent',
                  ).replaceFirst('%s', '$score'),
                  style: LocalFonts.poppins(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF137333),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            explanation,
            style: LocalFonts.poppins(
              fontSize: 12,
              color: const Color(0xFF486581),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${tr('estimated_price_diff')}: ${formatter.format(priceDiff)}',
            style: LocalFonts.poppins(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF334E68),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: onOpenListing,
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(tr('open_listing_details')),
              ),
              ElevatedButton.icon(
                onPressed: onSendTradeOffer,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF0D47A1),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.swap_horiz_rounded, size: 16),
                label: Text(tr('send_trade_offer')),
              ),
              TextButton.icon(
                onPressed: onSendMessage,
                icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16),
                label: Text(tr('send_message')),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
