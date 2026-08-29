import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'chat_screen.dart';
import '../services/database_service.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';

class MyTradesScreen extends StatefulWidget {
  const MyTradesScreen({super.key});

  @override
  State<MyTradesScreen> createState() => _MyTradesScreenState();
}

class _MyTradesScreenState extends State<MyTradesScreen>
    with SingleTickerProviderStateMixin {
  final DatabaseService _dbService = DatabaseService();
  final String? _currentUserId = FirebaseAuth.instance.currentUser?.uid;
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          tr('my_trades'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: [
            Tab(text: tr('trade_tab_incoming')),
            Tab(text: tr('trade_tab_outgoing')),
            Tab(text: tr('trade_tab_pending')),
            Tab(text: tr('trade_tab_accepted')),
            Tab(text: tr('trade_tab_rejected')),
          ],
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _dbService.incomingTradeOffersStream(),
        builder: (context, incomingSnap) {
          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _dbService.outgoingTradeOffersStream(),
            builder: (context, outgoingSnap) {
              if (!incomingSnap.hasData || !outgoingSnap.hasData) {
                return const Center(child: CircularProgressIndicator());
              }

              final incoming = incomingSnap.data!.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
              final outgoing = outgoingSnap.data!.docs
                  .map((doc) => {'id': doc.id, ...doc.data()})
                  .toList();
              final all = [...incoming, ...outgoing];

              return TabBarView(
                controller: _tabController,
                children: [
                  _buildOfferList(incoming),
                  _buildOfferList(outgoing),
                  _buildOfferList(
                    all.where((offer) => offer['status'] == 'pending').toList(),
                  ),
                  _buildOfferList(
                    all
                        .where((offer) => offer['status'] == 'accepted')
                        .toList(),
                  ),
                  _buildOfferList(
                    all
                        .where((offer) => offer['status'] == 'rejected')
                        .toList(),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildOfferList(List<Map<String, dynamic>> offers) {
    if (offers.isEmpty) {
      return Center(
        child: Text(
          tr('no_trade_offer_in_tab'),
          style: LocalFonts.poppins(color: Colors.grey[600]),
        ),
      );
    }

    offers.sort((a, b) {
      final at = a['createdAt'] as Timestamp?;
      final bt = b['createdAt'] as Timestamp?;
      if (at == null || bt == null) return 0;
      return bt.compareTo(at);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: offers.length,
      itemBuilder: (context, index) {
        final offer = offers[index];
        final status = (offer['status'] ?? 'pending').toString();

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  offer['senderListingTitle']?.toString().isNotEmpty == true
                      ? offer['senderListingTitle'].toString()
                      : tr('trade_offer_default_title'),
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                if ((offer['receiverListingTitle'] ?? '')
                    .toString()
                    .isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    'İstenen ürün: ${offer['receiverListingTitle']}',
                    style: LocalFonts.poppins(
                      fontSize: 12,
                      color: Colors.grey[700],
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                Text(
                  '${tr('status')}: ${_statusLabel(status)}',
                  style: LocalFonts.poppins(
                    color: _statusColor(status),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if ((offer['estimatedPriceDiff'] as num?) != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    '${tr('trade_price_difference')}: ${_formatPriceDifference((offer['estimatedPriceDiff'] as num).toDouble())}',
                    style: LocalFonts.poppins(
                      fontSize: 12,
                      color: Colors.purple[700],
                    ),
                  ),
                ],
                if ((offer['message'] ?? '').toString().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    offer['message'].toString(),
                    style: LocalFonts.poppins(fontSize: 12),
                  ),
                ],
                const SizedBox(height: 8),
                if (status == 'pending' &&
                    offer['receiverId'] == _currentUserId)
                  Wrap(
                    spacing: 8,
                    children: [
                      ElevatedButton(
                        onPressed: () async {
                          await _dbService.respondTradeOffer(
                            offerId: offer['id'].toString(),
                            accepted: true,
                          );
                          if (!mounted) return;
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChatScreen(
                                receiverId: (offer['senderId'] ?? '')
                                    .toString(),
                                receiverName:
                                    (offer['senderName'] ?? tr('user'))
                                        .toString(),
                                listingTitle:
                                    (offer['senderListingTitle'] ?? '')
                                        .toString(),
                                listingId: (offer['senderListingId'] ?? '')
                                    .toString(),
                                listingImage:
                                    (offer['senderListingImage'] ?? '')
                                        .toString(),
                                listingPrice: (offer['senderPrice'] ?? '')
                                    .toString(),
                              ),
                            ),
                          );
                        },
                        child: Text(tr('accept')),
                      ),
                      OutlinedButton(
                        onPressed: () async {
                          await _dbService.respondTradeOffer(
                            offerId: offer['id'].toString(),
                            accepted: false,
                          );
                        },
                        child: Text(tr('reject')),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatPriceDifference(double value) {
    final absValue = value.abs().toStringAsFixed(0);
    if (value > 0) {
      return '+$absValue TL';
    }
    if (value < 0) {
      return '-$absValue TL';
    }
    return '0 TL';
  }

  String _statusLabel(String status) {
    switch (status) {
      case 'accepted':
        return tr('trade_status_accepted');
      case 'rejected':
        return tr('trade_status_rejected');
      default:
        return tr('trade_status_pending');
    }
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'accepted':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.orange;
    }
  }
}
