import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import 'listing_detail_screen.dart';
import 'edit_listing_screen.dart';
import 'showcase_purchase_screen.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';

class MyListingsScreen extends StatelessWidget {
  const MyListingsScreen({super.key});

  // --- YENİ: SATIŞ ONAYI VE SİLME SEÇENEKLERİ (MENÜ YUKARI KALDIRILDI) ---
  void _showRemoveOptions(
    BuildContext context,
    String listingId,
    bool isActive,
    String listingTitle,
  ) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(
            bottom: 24.0,
            top: 12.0,
          ), // YENİ: Alta yapışık olmaması için 24 birim padding eklendi
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),

              // YENİ: KİŞİDEN ARACILIĞI İLE SATTIM SEÇENEĞİ
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.green[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.handshake, color: Colors.green),
                ),
                title: Text(
                  tr('sold_via_kisiden'),
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.green[800],
                  ),
                ),
                subtitle: Text(
                  tr('select_buyer_and_review'),
                  style: LocalFonts.poppins(fontSize: 10),
                ),
                onTap: () {
                  Navigator.pop(context); // Alt menüyü kapat
                  _showBuyersDialog(
                    context,
                    listingId,
                    listingTitle,
                  ); // Alıcı seçme ekranını aç
                },
              ),
              const Divider(),

              if (isActive) ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.pause_circle_filled,
                      color: Colors.orange,
                    ),
                  ),
                  title: Text(
                    tr('give_up_selling'),
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.orange[800],
                    ),
                  ),
                  subtitle: Text(
                    tr('listing_passive_desc'),
                    style: LocalFonts.poppins(fontSize: 10),
                  ),
                  onTap: () async {
                    await DatabaseService().deactivateListing(listingId);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
                const Divider(),
              ],

              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.delete_forever, color: Colors.red),
                ),
                title: Text(
                  tr('delete_listing_completely'),
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: Colors.red[800],
                  ),
                ),
                onTap: () async {
                  await DatabaseService().deleteListing(listingId);
                  if (context.mounted) Navigator.pop(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  // --- YENİ: ALICI SEÇME VE YORUM HAKKI TANIMA EKRANI ---
  void _showBuyersDialog(
    BuildContext context,
    String listingId,
    String listingTitle,
  ) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Text(
            tr('who_did_you_sell_to'),
            style: LocalFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: StreamBuilder<QuerySnapshot>(
              // İlana soru soranları veritabanından çekiyoruz
              stream: FirebaseFirestore.instance
                  .collection('listings')
                  .doc(listingId)
                  .collection('questions')
                  .snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());

                // Benzersiz kullanıcıları (soru soranları) filtrele
                Map<String, String> uniqueUsers = {};
                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;
                  String uId = data['userId'];
                  String uName = data['userName'] ?? 'Kullanıcı';
                  // Satıcının kendisini listeye almasını engelle
                  if (uId != FirebaseAuth.instance.currentUser!.uid) {
                    uniqueUsers[uId] = uName;
                  }
                }

                if (uniqueUsers.isEmpty) {
                  return Padding(
                    padding: const EdgeInsets.all(8.0),
                    child: Text(
                      tr('no_questions_yet'),
                      style: LocalFonts.poppins(color: Colors.grey),
                    ),
                  );
                }

                return ListView.builder(
                  shrinkWrap: true,
                  itemCount: uniqueUsers.length,
                  itemBuilder: (context, index) {
                    String buyerId = uniqueUsers.keys.elementAt(index);
                    String buyerName = uniqueUsers.values.elementAt(index);

                    return Card(
                      elevation: 0,
                      color: Colors.blue[50],
                      margin: const EdgeInsets.symmetric(vertical: 4),
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Colors.blue,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        title: Text(
                          buyerName,
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.check_circle_outline,
                          color: Colors.blue,
                        ),
                        onTap: () async {
                          // Satıldı olarak işaretle ve yorum hakkı ver
                          await DatabaseService()
                              .markAsSoldAndGrantReviewPermission(
                                listingId,
                                buyerId,
                                listingTitle,
                              );
                          if (context.mounted) {
                            Navigator.pop(context); // Dialogu kapat
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '$buyerName${tr('review_right_granted')}',
                                ),
                              ),
                            );
                          }
                        },
                      ),
                    );
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                tr('cancel'),
                style: LocalFonts.poppins(color: Colors.grey),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          title: Text(
            tr('my_listings_title'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: Colors.grey,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(text: tr('active_listings')),
              Tab(text: tr('passive_listings')),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildListingList(uid, isActive: true),
            _buildListingList(uid, isActive: false),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String text,
    Color color,
    VoidCallback onTap,
  ) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 2.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(height: 4),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: LocalFonts.poppins(
                    color: color,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildListingList(String uid, {required bool isActive}) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('sellerId', isEqualTo: uid)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData)
          return const Center(child: CircularProgressIndicator());
        var allDocs = snapshot.data!.docs;
        var docs = allDocs.where((doc) {
          var data = doc.data() as Map<String, dynamic>;
          bool isDocActive = (data['status'] == 'active');
          return isActive ? isDocActive : !isDocActive;
        }).toList();
        docs.sort(
          (a, b) => ((b.data() as Map)['createdAt'] ?? Timestamp.now())
              .compareTo((a.data() as Map)['createdAt'] ?? Timestamp.now()),
        );

        if (docs.isEmpty)
          return Center(
            child: Text(
              isActive ? tr('no_active_listings') : tr('no_passive_listings'),
              style: LocalFonts.poppins(color: Colors.grey),
            ),
          );

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: docs.length,
          itemBuilder: (context, index) {
            var data = docs[index].data() as Map<String, dynamic>;
            String docId = docs[index].id;
            bool isShowcased =
                data['showcaseUntil'] != null &&
                (data['showcaseUntil'] as Timestamp).toDate().isAfter(
                  DateTime.now(),
                );
            bool isCatShowcased =
                data['categoryShowcaseUntil'] != null &&
                (data['categoryShowcaseUntil'] as Timestamp).toDate().isAfter(
                  DateTime.now(),
                );
            bool isPending = data['status'] == 'pending';

            int viewCount = data['viewCount'] ?? 0;
            int favCount = data['favoriteCount'] ?? 0;
            DateTime createdAt =
                (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now();
            DateTime expirationDate = createdAt.add(const Duration(days: 30));
            String expDateStr =
                "${expirationDate.day.toString().padLeft(2, '0')}/${expirationDate.month.toString().padLeft(2, '0')}/${expirationDate.year}";
            String formattedPrice = data['price']
                .toString()
                .split('.')
                .first
                .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => '.');

            return Card(
              margin: const EdgeInsets.only(bottom: 16),
              elevation: 3,
              shadowColor: Colors.black12,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) =>
                            ListingDetailScreen(data: data, listingId: docId),
                      ),
                    ),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(16),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              data['imageUrl'] ?? '',
                              width: 90,
                              height: 90,
                              fit: BoxFit.cover,
                              errorBuilder: (c, e, s) => Container(
                                width: 90,
                                height: 90,
                                color: Colors.grey[200],
                                child: const Icon(
                                  Icons.image,
                                  color: Colors.grey,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  data['title'] ?? '',
                                  style: LocalFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  isPending
                                      ? tr('waiting_admin_approval')
                                      : '₺$formattedPrice',
                                  style: LocalFonts.poppins(
                                    color: isPending
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 12,
                                  runSpacing: 4,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.remove_red_eye,
                                          size: 14,
                                          color: Colors.grey[600],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$viewCount',
                                          style: LocalFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.favorite,
                                          size: 14,
                                          color: Colors.red[400],
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          '$favCount',
                                          style: LocalFonts.poppins(
                                            fontSize: 12,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.access_time,
                                      size: 12,
                                      color: Colors.grey[500],
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      '${tr('end_date')}$expDateStr',
                                      style: LocalFonts.poppins(
                                        fontSize: 11,
                                        color: Colors.grey[500],
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.grey[50],
                      borderRadius: const BorderRadius.vertical(
                        bottom: Radius.circular(16),
                      ),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        if (!isActive && !isPending)
                          _buildActionButton(
                            context,
                            Icons.refresh,
                            tr('publish'),
                            Colors.green,
                            () async {
                              try {
                                await DatabaseService().republishListing(docId);
                                if (context.mounted)
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(tr('listing_sent_to_admin')),
                                    ),
                                  );
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Tekrar yayınlamak için yeni ilan hakkı satın almanız gerekir.',
                                      ),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        if (isActive)
                          _buildActionButton(
                            context,
                            Icons.stars_outlined,
                            tr('highlight'),
                            AppColors.secondary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    ShowcasePurchaseScreen(listingId: docId),
                              ),
                            ),
                          ),
                        if (isActive || (!isActive && !isPending))
                          _buildActionButton(
                            context,
                            Icons.edit,
                            tr('edit'),
                            AppColors.primary,
                            () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => EditListingScreen(
                                  listingId: docId,
                                  currentData: data,
                                ),
                              ),
                            ),
                          ),
                        _buildActionButton(
                          context,
                          Icons.more_horiz,
                          tr('actions'),
                          Colors.grey[700]!,
                          () => _showRemoveOptions(
                            context,
                            docId,
                            isActive,
                            data['title'] ?? '',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isShowcased || isCatShowcased)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        borderRadius: const BorderRadius.vertical(
                          bottom: Radius.circular(16),
                        ),
                        border: Border(
                          top: BorderSide(
                            color: AppColors.secondary.withValues(alpha: 0.2),
                          ),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          if (isShowcased) ...[
                            const Icon(
                              Icons.star,
                              color: AppColors.secondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('on_home_showcase'),
                              style: LocalFonts.poppins(
                                fontSize: 10,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 12),
                          ],
                          if (isCatShowcased) ...[
                            const Icon(
                              Icons.category,
                              color: AppColors.secondary,
                              size: 14,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              tr('on_category_showcase'),
                              style: LocalFonts.poppins(
                                fontSize: 10,
                                color: AppColors.secondary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
