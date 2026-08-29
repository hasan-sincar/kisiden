import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../screens/chat_screen.dart';
import '../screens/listing_detail_screen.dart';
import '../services/database_service.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';
import 'trade_match_card.dart';

class PersonalizedTradeSuggestionsSection extends StatefulWidget {
  const PersonalizedTradeSuggestionsSection({super.key});

  @override
  State<PersonalizedTradeSuggestionsSection> createState() =>
      _PersonalizedTradeSuggestionsSectionState();
}

class _PersonalizedTradeSuggestionsSectionState
    extends State<PersonalizedTradeSuggestionsSection> {
  final DatabaseService _dbService = DatabaseService();
  late Future<List<Map<String, dynamic>>> _future;

  @override
  void initState() {
    super.initState();
    _future = _dbService.getPersonalizedTradeSuggestions(limit: 6);
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _dbService.getPersonalizedTradeSuggestions(limit: 6);
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final matches = snapshot.data ?? const [];
        if (matches.isEmpty) return const SizedBox.shrink();

        return Padding(
          padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    tr('personalized_trade_suggestions'),
                    style: LocalFonts.poppins(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const Spacer(),
                  TextButton(onPressed: _refresh, child: Text(tr('refresh'))),
                ],
              ),
              const SizedBox(height: 6),
              ...matches.map(
                (match) => TradeMatchCard(
                  match: match,
                  onOpenListing: () => _openListing(context, match),
                  onSendTradeOffer: () => _sendTradeOffer(context, match),
                  onSendMessage: () => _openChat(context, match),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _openListing(
    BuildContext context,
    Map<String, dynamic> match,
  ) async {
    final listingId = (match['otherListingId'] ?? '').toString();
    if (listingId.isEmpty) return;
    final doc = await FirebaseFirestore.instance
        .collection('listings')
        .doc(listingId)
        .get();
    if (!doc.exists || !context.mounted) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            ListingDetailScreen(data: doc.data()!, listingId: doc.id),
      ),
    );
  }

  Future<void> _sendTradeOffer(
    BuildContext context,
    Map<String, dynamic> match,
  ) async {
    final receiverId = (match['otherSellerId'] ?? '').toString();
    final receiverListingId = (match['otherListingId'] ?? '').toString();
    final senderListingId = (match['myListingId'] ?? '').toString();

    if (receiverId.isEmpty ||
        receiverListingId.isEmpty ||
        senderListingId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('trade_offer_missing_own_listing'))),
      );
      return;
    }

    await _dbService.sendTradeOffer(
      receiverId: receiverId,
      senderListingId: senderListingId,
      receiverListingId: receiverListingId,
      message: tr('trade_offer_default_message'),
      estimatedPriceDiff:
          (match['estimatedPriceDiff'] as num?)?.toDouble() ?? 0,
    );

    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(tr('trade_offer_sent'))));
  }

  Future<void> _openChat(
    BuildContext context,
    Map<String, dynamic> match,
  ) async {
    final receiverId = (match['otherSellerId'] ?? '').toString();
    final receiverName = (match['otherSellerName'] ?? tr('user')).toString();
    final listingId = (match['otherListingId'] ?? '').toString();

    if (receiverId.isEmpty) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          receiverId: receiverId,
          receiverName: receiverName,
          listingTitle: (match['otherListingTitle'] ?? '').toString(),
          listingId: listingId,
          listingImage: (match['otherListingImage'] ?? '').toString(),
          listingPrice:
              ((match['otherListingData']?['price'] as num?)?.toString() ?? ''),
        ),
      ),
    );
  }
}
