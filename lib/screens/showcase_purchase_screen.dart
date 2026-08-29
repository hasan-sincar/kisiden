import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/database_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/translations.dart';

class ShowcasePurchaseScreen extends StatefulWidget {
  final String listingId;
  const ShowcasePurchaseScreen({super.key, required this.listingId});

  @override
  State<ShowcasePurchaseScreen> createState() => _ShowcasePurchaseScreenState();
}

class _ShowcasePurchaseScreenState extends State<ShowcasePurchaseScreen> {
  final DatabaseService _dbService = DatabaseService();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  int _freeHomeCount = 0;
  int _freeCategoryCount = 0;
  int _freeUrgentCount = 0;

  // Google Play'de oluşturacağımız Ürün Kimlikleri (Product IDs)
  final List<String> _kProductIds = <String>[
    'vitrin_1_gun',
    'vitrin_1_hafta',
    'vitrin_1_ay',
    'kat_vitrin_1_gun',
    'kat_vitrin_1_hafta',
    'kat_vitrin_1_ay',
    'acil_2_gun',
    'acil_3_gun',
    'acil_7_gun',
  ];

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated =
        _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen(
      (purchaseDetailsList) {
        _listenToPurchaseUpdated(purchaseDetailsList);
      },
      onDone: () {
        _subscription.cancel();
      },
      onError: (error) {
        // Hata durumu
      },
    );
    _initStoreInfo();
    _loadFreeShowcases();
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _loadFreeShowcases() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      var doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (doc.exists && mounted) {
        setState(() {
          _freeHomeCount = doc.data()?['freeHomeShowcaseCount'] ?? 0;
          _freeCategoryCount = doc.data()?['freeCategoryShowcaseCount'] ?? 0;
          _freeUrgentCount = doc.data()?['freeUrgentCount'] ?? 0;
        });
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() {
        _isAvailable = false;
        _isLoading = false;
      });
      return;
    }

    ProductDetailsResponse productDetailResponse = await _inAppPurchase
        .queryProductDetails(_kProductIds.toSet());
    setState(() {
      _isAvailable = true;
      _products = productDetailResponse.productDetails;
      _isLoading = false;
    });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Satın alma bekleniyor
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('purchase_cancelled_or_error'))),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          // BAŞARILI SATIN ALMA - Veritabanını güncelle
          int days = 1;
          if (purchaseDetails.productID == 'vitrin_1_hafta' ||
              purchaseDetails.productID == 'kat_vitrin_1_hafta' ||
              purchaseDetails.productID == 'acil_7_gun') {
            days = 7;
          }
          if (purchaseDetails.productID == 'vitrin_1_ay' ||
              purchaseDetails.productID == 'kat_vitrin_1_ay') {
            days = 30;
          }
          if (purchaseDetails.productID == 'acil_3_gun') {
            days = 3;
          }

          final product = _products.cast<ProductDetails?>().firstWhere(
            (p) => p?.id == purchaseDetails.productID,
            orElse: () => null,
          );
          if (product == null) return; // Ürün detayı bulunamazsa işlemi durdur
          if (purchaseDetails.productID.startsWith('acil_')) {
            _dbService
                .upgradeListingToUrgent(
                  widget.listingId,
                  days,
                  packageId: purchaseDetails.productID,
                  price: product.price,
                )
                .then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('urgent_promoted_1_day'))),
                    );
                    Navigator.pop(context);
                  }
                });
          } else if (purchaseDetails.productID.startsWith('kat_')) {
            _dbService
                .upgradeListingToCategoryShowcase(
                  widget.listingId,
                  days,
                  packageId: purchaseDetails.productID,
                  price: product.price,
                )
                .then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(tr('listing_cat_showcased_1_day')),
                      ),
                    );
                    Navigator.pop(context); // Önceki sayfaya dön
                  }
                });
          } else {
            _dbService
                .upgradeListingToShowcase(
                  widget.listingId,
                  days,
                  packageId: purchaseDetails.productID,
                  price: product.price,
                )
                .then((_) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(tr('listing_showcased_1_day'))),
                    );
                    Navigator.pop(context); // Önceki sayfaya dön
                  }
                });
          }
        }
        if (purchaseDetails.pendingCompletePurchase) {
          _inAppPurchase.completePurchase(purchaseDetails);
        }
      }
    }
  }

  Future<void> _useFreeShowcase(bool isCategory) async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      if (isCategory) {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'freeCategoryShowcaseCount': FieldValue.increment(-1),
        });
        await _dbService.upgradeListingToCategoryShowcase(
          widget.listingId,
          1,
        ); // 1 Günlük hediye
      } else {
        await FirebaseFirestore.instance.collection('users').doc(uid).update({
          'freeHomeShowcaseCount': FieldValue.increment(-1),
        });
        await _dbService.upgradeListingToShowcase(
          widget.listingId,
          1,
        ); // 1 Günlük hediye
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('gift_showcase_used_success'))),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('error')}: $e')));
    }
  }

  Future<void> _useFreeUrgent() async {
    setState(() => _isLoading = true);
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;

      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'freeUrgentCount': FieldValue.increment(-1),
      });
      await _dbService.upgradeListingToUrgent(widget.listingId, 1);

      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('gift_urgent_used_success'))));
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${tr('error')}: $e')));
      }
    }
  }

  void _buyProduct(String productId) {
    if (!_isAvailable) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('store_connection_failed'))));
      return;
    }
    final ProductDetails? product = _products
        .cast<ProductDetails?>()
        .firstWhere((p) => p?.id == productId, orElse: () => null);
    if (product == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('product_not_found'))));
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(
            tr('buy_showcase_title'),
            style: LocalFonts.poppins(fontWeight: FontWeight.bold),
          ),
          bottom: TabBar(
            labelColor: Colors.amber,
            unselectedLabelColor: Colors.grey,
            indicatorColor: Colors.amber,
            tabs: [
              Tab(icon: Icon(Icons.home), text: tr('showcase')),
              Tab(icon: Icon(Icons.category), text: tr('category_showcase')),
              const Tab(icon: Icon(Icons.notifications_active), text: 'Acil'),
            ],
          ),
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : TabBarView(
                children: [
                  _buildShowcaseTab(isCategory: false),
                  _buildShowcaseTab(isCategory: true),
                  _buildUrgentTab(),
                ],
              ),
      ),
    );
  }

  Widget _buildUrgentTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(Icons.notifications_active, size: 80, color: Colors.red[600]),
          const SizedBox(height: 16),
          Text(
            'Acil İlan',
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tr('urgent_showcase_desc'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          if (_freeUrgentCount > 0) ...[
            _buildPricingCard(
              title: tr('gift_urgent_right_1_day'),
              price: tr('free'),
              icon: Icons.card_giftcard,
              color: Colors.green,
              isPopular: true,
              onTap: _useFreeUrgent,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Text(
                tr(
                  'remaining_right_count',
                ).replaceFirst('%s', '$_freeUrgentCount'),
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
          ],

          _buildPricingCard(
            title: '24 Saat Acil',
            price: '9.99 ₺',
            icon: Icons.flash_on,
            color: Colors.red,
            onTap: () => _buyProduct('acil_2_gun'),
          ),
          const SizedBox(height: 16),
          _buildPricingCard(
            title: '3 Gün Acil',
            price: '14.99 ₺',
            icon: Icons.bolt,
            color: Colors.deepOrange,
            isPopular: true,
            onTap: () => _buyProduct('acil_3_gun'),
          ),
          const SizedBox(height: 16),
          _buildPricingCard(
            title: '7 Gün Acil',
            price: '24.99 ₺',
            icon: Icons.local_fire_department,
            color: Colors.red[800]!,
            onTap: () => _buyProduct('acil_7_gun'),
          ),
          const SizedBox(height: 30),
          Text(
            tr('purchase_secure_info'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildShowcaseTab({required bool isCategory}) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Icon(
            isCategory ? Icons.category : Icons.stars,
            size: 80,
            color: isCategory ? Colors.orange[600] : Colors.amber[600],
          ),
          const SizedBox(height: 16),
          Text(
            isCategory
                ? tr('stand_out_in_category')
                : tr('highlight_listing_title'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            isCategory
                ? tr('category_showcase_desc')
                : tr('home_showcase_desc'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(color: Colors.grey[600]),
          ),
          const SizedBox(height: 40),

          // YENİ: Ücretsiz hak varsa en üstte göster
          if (isCategory ? _freeCategoryCount > 0 : _freeHomeCount > 0) ...[
            _buildPricingCard(
              title: tr('gift_showcase_right_1_day'),
              price: tr('free'),
              icon: Icons.card_giftcard,
              color: Colors.green,
              isPopular: true,
              onTap: () => _useFreeShowcase(isCategory),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 16.0),
              child: Text(
                tr('remaining_right_count').replaceFirst(
                  '%s',
                  '${isCategory ? _freeCategoryCount : _freeHomeCount}',
                ),
                textAlign: TextAlign.center,
                style: LocalFonts.poppins(
                  color: Colors.green[700],
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Divider(),
            const SizedBox(height: 16),
          ],

          _buildPricingCard(
            title: tr('showcase_1_day'),
            price: isCategory ? '2.99 ₺' : '3.99 ₺',
            icon: Icons.flash_on,
            color: Colors.blue,
            onTap: () =>
                _buyProduct(isCategory ? 'kat_vitrin_1_gun' : 'vitrin_1_gun'),
          ),
          const SizedBox(height: 16),

          _buildPricingCard(
            title: tr('showcase_1_week'),
            price: isCategory ? '10.99 ₺' : '14.99 ₺',
            icon: Icons.rocket_launch,
            color: Colors.purple,
            isPopular: true,
            onTap: () => _buyProduct(
              isCategory ? 'kat_vitrin_1_hafta' : 'vitrin_1_hafta',
            ),
          ),
          const SizedBox(height: 16),

          _buildPricingCard(
            title: tr('showcase_1_month'),
            price: isCategory ? '39.99 ₺' : '49.99 ₺',
            icon: Icons.diamond,
            color: Colors.amber[800]!,
            onTap: () =>
                _buyProduct(isCategory ? 'kat_vitrin_1_ay' : 'vitrin_1_ay'),
          ),

          const SizedBox(height: 30),
          Text(
            tr('purchase_secure_info'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(fontSize: 10, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildPricingCard({
    required String title,
    required String price,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
    bool isPopular = false,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isPopular ? color : Colors.grey.shade300,
            width: isPopular ? 2 : 1,
          ),
          boxShadow: [
            if (isPopular)
              BoxShadow(
                color: color.withValues(alpha: 0.2),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isPopular)
                    Text(
                      tr('best_seller'),
                      style: LocalFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  Text(
                    title,
                    style: LocalFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              price,
              style: LocalFonts.poppins(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green[700],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
