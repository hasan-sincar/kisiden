import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'listing_detail_screen.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';
import '../data/trade_types.dart';
import '../widgets/trade_type_selector.dart';

class FavoritesScreen extends StatefulWidget {
  const FavoritesScreen({super.key});

  @override
  State<FavoritesScreen> createState() => _FavoritesScreenState();
}

class _FavoritesScreenState extends State<FavoritesScreen> {
  final Set<String> _selectedTradeTypes = <String>{};
  final Map<String, Future<DocumentSnapshot>> _listingFutures = {};

  Future<DocumentSnapshot> _loadListing(String listingId) {
    return _listingFutures.putIfAbsent(
      listingId,
      () => FirebaseFirestore.instance
          .collection('listings')
          .doc(listingId)
          .get(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('favorites'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TradeTypeSelector(
              showHeading: false,
              selectedTypes: _selectedTradeTypes,
              onTypeToggled: (typeId) => setState(() {
                if (!_selectedTradeTypes.add(typeId)) {
                  _selectedTradeTypes.remove(typeId);
                }
              }),
            ),
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .collection('favorites')
            .orderBy('addedAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());
          var favDocs = snapshot.data!.docs;

          if (favDocs.isEmpty) {
            return Center(
              child: Text(
                tr('no_favorites'),
                style: LocalFonts.poppins(color: Colors.grey),
              ),
            );
          }

          return ListView.builder(
            itemCount: favDocs.length,
            itemBuilder: (context, index) {
              String listingId = favDocs[index].id;

              return FutureBuilder<DocumentSnapshot>(
                future: _loadListing(listingId),
                builder: (context, listingSnap) {
                  if (!listingSnap.hasData) return const SizedBox();
                  if (!listingSnap.data!.exists) {
                    // İlan silinmişse veritabanından da favoriyi kaldır ve listede gösterme
                    FirebaseFirestore.instance
                        .collection('users')
                        .doc(uid)
                        .collection('favorites')
                        .doc(listingId)
                        .delete();
                    return const SizedBox.shrink();
                  }

                  var data = listingSnap.data!.data() as Map<String, dynamic>;
                  if (!listingMatchesTradeTypeFilter(
                    data,
                    _selectedTradeTypes,
                  )) {
                    return const SizedBox.shrink();
                  }

                  return Card(
                    margin: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.all(8),
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          data['imageUrl'] ?? '',
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        ),
                      ),
                      title: Text(
                        data['title'] ?? '',
                        style: LocalFonts.poppins(fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Builder(
                        builder: (context) {
                          double currentPrice =
                              double.tryParse(data['price'].toString()) ?? 0;
                          double? oldPrice = data['oldPrice'] != null
                              ? double.tryParse(data['oldPrice'].toString())
                              : null;
                          String formattedPrice = currentPrice
                              .toStringAsFixed(0)
                              .replaceAllMapped(
                                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                (m) => '.',
                              );

                          if (oldPrice != null && oldPrice != currentPrice) {
                            String formattedOld = oldPrice
                                .toStringAsFixed(0)
                                .replaceAllMapped(
                                  RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                  (m) => '.',
                                );
                            bool isDrop = currentPrice < oldPrice;
                            return Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  '₺$formattedOld',
                                  style: LocalFonts.poppins(
                                    color: Colors.grey,
                                    decoration: TextDecoration.lineThrough,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '₺$formattedPrice',
                                  style: LocalFonts.poppins(
                                    color: isDrop
                                        ? Colors.green[700]
                                        : Colors.red[700],
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                Icon(
                                  isDrop
                                      ? Icons.arrow_downward
                                      : Icons.arrow_upward,
                                  color: isDrop
                                      ? Colors.green[700]
                                      : Colors.red[700],
                                  size: 14,
                                ),
                              ],
                            );
                          }
                          return Text(
                            '₺$formattedPrice',
                            style: LocalFonts.poppins(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          );
                        },
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.favorite, color: Colors.red),
                        onPressed: () {
                          FirebaseFirestore.instance
                              .collection('users')
                              .doc(uid)
                              .collection('favorites')
                              .doc(listingId)
                              .delete();
                          FirebaseFirestore.instance
                              .collection('listings')
                              .doc(listingId)
                              .update({
                                'favoriteCount': FieldValue.increment(-1),
                                'favoritedBy': FieldValue.arrayRemove([uid]),
                              });
                        },
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => ListingDetailScreen(
                            data: data,
                            listingId: listingId,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
