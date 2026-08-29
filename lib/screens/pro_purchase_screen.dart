import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../services/database_service.dart';
import '../utils/translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ProPurchaseScreen extends StatefulWidget {
  const ProPurchaseScreen({super.key});

  @override
  State<ProPurchaseScreen> createState() => _ProPurchaseScreenState();
}

class _ProPurchaseScreenState extends State<ProPurchaseScreen> {
  final DatabaseService _dbService = DatabaseService();
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
      _userDocumentSubscription;
  
  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPro = false;
  int? _remainingProDays;
  int? _proListingLimit;
  int _usedListings = 0;
  int _currentLimit = 10;

  final List<String> _kProductIds = <String>['pro_3_ay', 'pro_6_ay', 'pro_12_ay'];

  @override
  void initState() {
    super.initState();
    final Stream<List<PurchaseDetails>> purchaseUpdated = _inAppPurchase.purchaseStream;
    _subscription = purchaseUpdated.listen((purchaseDetailsList) {
      _listenToPurchaseUpdated(purchaseDetailsList);
    }, onDone: () {
      _subscription.cancel();
    }, onError: (error) {});
    _initStoreInfo();
    _checkProStatus();
    _listenForAdminListingRights();
  }

  void _listenForAdminListingRights() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;
    _userDocumentSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((_) => _checkProStatus());
  }

  @override
  void dispose() {
    _subscription.cancel();
    _userDocumentSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkProStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        int limit = 10;
        final adminListingLimit =
            (data['adminListingLimit'] as num?)?.toInt();

        if (adminListingLimit != null && adminListingLimit > 0) {
          // Yönetici tarafından verilen toplam ilan limiti önceliklidir.
          limit = adminListingLimit;
        }

        if (data['proUntil'] != null) {
          Timestamp endDate = data['proUntil'];
          DateTime endDateTime = endDate.toDate();
          if (endDateTime.isAfter(DateTime.now())) {
            int proLimit = data['proListingLimit'] ?? 0;
            if (adminListingLimit == null) {
              limit = proLimit > 0
                  ? proLimit
                  : 10; // Paket limiti kullanılır
            }
            if (mounted) {
              setState(() { _isPro = true; _remainingProDays = endDateTime.difference(DateTime.now()).inDays; _proListingLimit = limit; });
            }
          }
        }
        
        QuerySnapshot listings = await FirebaseFirestore.instance.collection('listings')
            .where('sellerId', isEqualTo: user.uid)
            .where('status', whereIn: ['active', 'pending']).get();
            
        if (mounted) {
          setState(() { _usedListings = listings.docs.length; _currentLimit = limit; });
        }
      }
    }
  }

  Future<void> _initStoreInfo() async {
    final bool isAvailable = await _inAppPurchase.isAvailable();
    if (!isAvailable) {
      setState(() { _isAvailable = false; _isLoading = false; });
      return;
    }
    ProductDetailsResponse productDetailResponse = await _inAppPurchase.queryProductDetails(_kProductIds.toSet());
    setState(() { _isAvailable = true; _products = productDetailResponse.productDetails; _isLoading = false; });
  }

  void _listenToPurchaseUpdated(List<PurchaseDetails> purchaseDetailsList) {
    for (var purchaseDetails in purchaseDetailsList) {
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Satın alma bekleniyor
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('purchase_cancelled_or_error'))));
        } else if (purchaseDetails.status == PurchaseStatus.purchased || purchaseDetails.status == PurchaseStatus.restored) {
          int days = 90;
          int limit = 25;

          final product = _products.cast<ProductDetails?>().firstWhere((p) => p?.id == purchaseDetails.productID, orElse: () => null);
          if (product == null) return; // Ürün detayı bulunamazsa işlemi durdur

          if (purchaseDetails.productID == 'pro_3_ay') {
            days = 90; limit = 25;
          } else if (purchaseDetails.productID == 'pro_6_ay') {
            days = 180; limit = 60;
          } else if (purchaseDetails.productID == 'pro_12_ay') {
            days = 365; limit = 250;
          }
          
          _dbService.upgradeToPro(days, limit, packageId: purchaseDetails.productID, price: product.price).then((_) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('pro_success_msg'))));
            Navigator.pop(context); // Anasayfaya veya profile dön
          });
        }
        if (purchaseDetails.pendingCompletePurchase) { _inAppPurchase.completePurchase(purchaseDetails); }
      }
    }
  }

  void _buyProduct(String productId) {
    if (!_isAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('store_connection_failed'))));
      return;
    }
    final ProductDetails? product = _products.cast<ProductDetails?>().firstWhere((p) => p?.id == productId, orElse: () => null);
    if (product == null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(tr('product_not_found'))));
      return;
    }
    final PurchaseParam purchaseParam = PurchaseParam(productDetails: product);
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    int remaining = _currentLimit - _usedListings;
    if (remaining < 0) remaining = 0;
    double progress = _currentLimit > 0 ? (_usedListings / _currentLimit) : 0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator()) 
        : SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Üst Kısım: Degrade Arka Plan ve Limit Durumu
                Container(
                  padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 16, bottom: 40, left: 24, right: 24),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.only(bottomLeft: Radius.circular(40), bottomRight: Radius.circular(40)),
                  ),
                  child: Column(
                    children: [
                      // Kaydırmada üst üste binmeyi önleyen, içerikle hareket eden özel başlık tasarımı
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white), onPressed: () => Navigator.pop(context)),
                          Text(tr('pro_store'), style: LocalFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 18)),
                          const SizedBox(width: 48), // Ortalamayı dengelemek için boşluk
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Icon(Icons.workspace_premium, size: 80, color: Colors.amberAccent),
                      const SizedBox(height: 16),
                      Text(tr('premium_privileges'), style: LocalFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                      const SizedBox(height: 24),
                      
                      // İlan Kullanım Durumu Kartı
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.white.withValues(alpha: 0.3)),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(tr('used_listings'), style: LocalFonts.poppins(color: Colors.white70, fontSize: 14)),
                                Text('$_usedListings / $_currentLimit', style: LocalFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(10),
                              child: LinearProgressIndicator(
                                value: progress,
                                minHeight: 10,
                                backgroundColor: Colors.white.withValues(alpha: 0.2),
                                color: remaining == 0 ? Colors.redAccent : Colors.amberAccent,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              remaining == 0 
                                ? tr('listing_limit_full_upgrade') 
                                : tr('remaining_free_listings').replaceAll('%s', remaining.toString()),
                              textAlign: TextAlign.center,
                              style: LocalFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_isPro && _remainingProDays != null) ...[
                        const SizedBox(height: 24),
                        Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [Color(0xFF00b09b), Color(0xFF96c93d)]),
                            borderRadius: BorderRadius.circular(20),
                            boxShadow: [BoxShadow(color: Colors.green.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5))]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Icon(Icons.verified, color: Colors.white, size: 28), 
                                  const SizedBox(width: 12),
                                  Expanded(child: Text(tr('pro_store_active'), style: LocalFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18))),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(tr('current_package'), style: LocalFonts.poppins(color: Colors.white70)),
                                  Text(_proListingLimit == 25 ? tr('pro_3_months') : (_proListingLimit == 60 ? tr('pro_6_months') : (_proListingLimit == 250 ? tr('pro_12_months') : tr('pro_package'))), style: LocalFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(tr('remaining_time'), style: LocalFonts.poppins(color: Colors.white70)),
                                  Text('$_remainingProDays ${tr('days')}', style: LocalFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 32),
                      Text(tr('privileges'), style: LocalFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      _buildFeatureRow(Icons.rocket_launch, Colors.purple, tr('higher_listing_limits')),
                      _buildFeatureRow(Icons.auto_awesome, Colors.orange, tr('pro_gift_showcase')),
                      _buildFeatureRow(Icons.workspace_premium, Colors.amber, tr('pro_badge_profile')),
                      _buildFeatureRow(Icons.support_agent, Colors.blue, tr('priority_support')),
                      
                      const SizedBox(height: 32),
                      Text(tr('package_options'), style: LocalFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.black87)),
                      const SizedBox(height: 16),
                      
                      _buildPackageCard('pro_3_ay', tr('buy_pro_3_months'), '49.99 ₺', isPopular: false),
                      const SizedBox(height: 16),
                      _buildPackageCard('pro_6_ay', tr('buy_pro_6_months'), '79.99 ₺', isPopular: true),
                      const SizedBox(height: 16),
                      _buildPackageCard('pro_12_ay', tr('buy_pro_12_months'), '129.99 ₺', isPopular: false),
                      
                      const SizedBox(height: 30),
                      Text(tr('purchase_secure_info'), textAlign: TextAlign.center, style: LocalFonts.poppins(fontSize: 11, color: Colors.grey)),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildFeatureRow(IconData icon, Color color, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(child: Text(text, style: LocalFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildPackageCard(String productId, String title, String price, {bool isPopular = false}) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: isPopular ? Colors.amber.withValues(alpha: 0.3) : Colors.black.withValues(alpha: 0.05), 
            blurRadius: 15, 
            offset: const Offset(0, 8)
          )
        ],
      ),
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _buyProduct(productId),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: isPopular ? Colors.amber : Colors.grey.shade200, width: isPopular ? 2 : 1),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12), 
                  decoration: BoxDecoration(color: isPopular ? Colors.amber.withValues(alpha: 0.15) : Colors.grey.shade100, shape: BoxShape.circle), 
                  child: Icon(Icons.star, color: isPopular ? Colors.amber.shade700 : Colors.grey.shade600)
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isPopular) 
                        Container(
                          margin: const EdgeInsets.only(bottom: 4),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(color: Colors.amber, borderRadius: BorderRadius.circular(6)),
                          child: Text(tr('best_seller'), style: LocalFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                      Text(title, style: LocalFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.black87)),
                    ],
                  )
                ),
                Text(price, style: LocalFonts.poppins(fontSize: 20, fontWeight: FontWeight.w900, color: const Color(0xFF2A5298))),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
