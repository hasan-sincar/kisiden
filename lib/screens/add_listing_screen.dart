import 'dart:async';

import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart'
    as image_compress; // YENİ
import 'package:firebase_auth/firebase_auth.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import '../services/database_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:typed_data'; // YENİ: Byte okumak için
import 'dart:ui' as ui; // YENİ: Resim üzerine yazı çizmek için
import '../utils/turkey_locations.dart';
import 'package:flutter/services.dart'; // YENİ: Formatter için
import 'dart:convert'; // YENİ: JSON okumak için
import 'package:intl/intl.dart'; // YENİ: Para formatı için
import '../utils/translations.dart'; // YENİ: Çeviri için
import 'pro_purchase_screen.dart';
import '../utils/theme_colors.dart';
import 'listing_success_screen.dart'; // YENİ: Başarı Ekranı
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

class AddListingScreen extends StatefulWidget {
  const AddListingScreen({super.key});
  @override
  State<AddListingScreen> createState() => _AddListingScreenState();
}

class _AddListingScreenState extends State<AddListingScreen> {
  int _currentStep = 1;
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _priceController = TextEditingController();
  bool _offersEnabled = true;
  bool _tradeEnabled = false;
  int _offerValidityHours = 24;
  int _offerMinimumPercent = 70;
  final _offerMinimumAmountController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  String? _selectedNeighborhood;
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  final List<Uint8List> _optimizedImages =
      []; // YENİ: Web uyumluluğu için File yerine Byte Listesi kullanıyoruz
  bool _isLoading = false;
  String _loadingText = "";
  String? selectedCategoryId;
  String selectedCategoryName = "";
  String fullCategoryPath = "";
  String fullCategoryDisplayPath = "";
  Map<String, String> _autoAttributes =
      {}; // YENİ: Ağaçtan otomatik çekilen özellikler

  String? _selectedCity;
  String? _selectedDistrict;
  Position? _selectedPosition;
  bool _isDetectingLocation = false;

  List<String> _currentNeighborhoods = []; // YENİ: Seçilen ilçenin mahalleleri
  bool _isLoadingNeighborhoods = false; // YENİ: Yükleniyor durumu
  Map<String, dynamic>? _neighborhoodsJsonCache;
  Map<String, List<String>> _normalizedNeighborhoodsIndex = {};

  final List<Map<String, dynamic>> _categoryFeatures = [];
  final Map<String, TextEditingController> _featureTextControllers = {};
  final Map<String, String?> _featureDropdownValues = {};

  bool _checkingLimit = true;
  bool _canAddListing = false;
  int _usedListingsCount = 0;
  int _listingLimit = 10;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userLimitSubscription;
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _purchaseSubscription;
  List<String> _listingRightProductIds = <String>[
    'ilan_hakkii_5',
    'ilan_hakkii_10',
    'ilan_hakkii_20',
  ];
  Map<String, int> _listingRightPackageGrants = {
    'ilan_hakkii_5': 5,
    'ilan_hakkii_10': 10,
    'ilan_hakkii_20': 20,
  };
  Map<String, String> _listingRightPackageTitles = {
    'ilan_hakkii_5': '5 ${tr('listing_rights_unit')}',
    'ilan_hakkii_10': '10 ${tr('listing_rights_unit')}',
    'ilan_hakkii_20': '20 ${tr('listing_rights_unit')}',
  };
  List<ProductDetails> _listingRightProducts = [];
  bool _isStoreReady = false;
  bool _isBuyingListingRight = false;
  bool _isRewardLoading = false;
  final Set<String> _processedPurchaseIds = <String>{};
  String _rewardedAndroidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  String _rewardedIosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  int _rewardDailyMax = 3;
  int _rewardCooldownMinutes = 10;

  @override
  void initState() {
    super.initState();
    _checkUserLimit();
    _listenForListingRightChanges();
    _bootstrapListingRightMonetization();
  }

  Future<void> _bootstrapListingRightMonetization() async {
    await _loadListingRightSettings();
    await _initListingRightPurchaseFlow();
  }

  Future<void> _loadListingRightSettings() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('listing_rights')
          .get();
      if (!doc.exists) return;

      final data = doc.data() as Map<String, dynamic>;
      final rawPackages =
          (data['paidPackages'] as List<dynamic>? ?? <dynamic>[])
              .whereType<Map>()
              .toList();

      final grants = <String, int>{};
      final titles = <String, String>{};
      for (final raw in rawPackages) {
        final productId = (raw['productId'] ?? '').toString().trim();
        final grantCount = (raw['grantCount'] as num?)?.toInt() ?? 0;
        final title = (raw['title'] ?? '').toString().trim();
        if (productId.isEmpty || grantCount <= 0) continue;
        grants[productId] = grantCount;
        titles[productId] = title.isNotEmpty
            ? title
            : '$grantCount ${tr('listing_rights_unit')}';
      }

      if (mounted) {
        setState(() {
          if (grants.isNotEmpty) {
            _listingRightPackageGrants = grants;
            _listingRightPackageTitles = titles;
            _listingRightProductIds = grants.keys.toList();
          }

          _rewardedAndroidAdUnitId =
              (data['rewardedAndroidAdUnitId'] ?? _rewardedAndroidAdUnitId)
                  .toString()
                  .trim();
          _rewardedIosAdUnitId =
              (data['rewardedIosAdUnitId'] ?? _rewardedIosAdUnitId)
                  .toString()
                  .trim();
          _rewardDailyMax =
              ((data['rewardDailyMax'] as num?)?.toInt() ?? _rewardDailyMax);
          _rewardCooldownMinutes =
              ((data['rewardCooldownMinutes'] as num?)?.toInt() ??
              _rewardCooldownMinutes);
        });
      }
    } catch (_) {}
  }

  Future<void> _initListingRightPurchaseFlow() async {
    _purchaseSubscription?.cancel();

    final available = await _inAppPurchase.isAvailable();
    if (!available) {
      if (mounted) setState(() => _isStoreReady = false);
      return;
    }

    final response = await _inAppPurchase.queryProductDetails(
      _listingRightProductIds.toSet(),
    );
    if (mounted) {
      setState(() {
        _listingRightProducts = response.productDetails;
        _isStoreReady = response.productDetails.isNotEmpty;
      });
    }

    _purchaseSubscription = _inAppPurchase.purchaseStream.listen(
      _handleListingRightPurchaseUpdates,
      onDone: () => _purchaseSubscription?.cancel(),
      onError: (_) {
        if (mounted) {
          setState(() => _isBuyingListingRight = false);
        }
      },
    );
  }

  Future<void> _handleListingRightPurchaseUpdates(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (final purchase in purchaseDetailsList) {
      if (!_listingRightPackageGrants.containsKey(purchase.productID)) {
        continue;
      }

      if (purchase.status == PurchaseStatus.pending) {
        if (mounted) setState(() => _isBuyingListingRight = true);
        continue;
      }

      if (purchase.status == PurchaseStatus.error) {
        if (mounted) {
          setState(() => _isBuyingListingRight = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('purchase_cancelled_or_error'))),
          );
        }
      }

      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        final purchaseToken =
            purchase.purchaseID ??
            '${purchase.productID}_${purchase.transactionDate ?? ''}';
        if (_processedPurchaseIds.contains(purchaseToken)) {
          if (purchase.pendingCompletePurchase) {
            await _inAppPurchase.completePurchase(purchase);
          }
          continue;
        }

        _processedPurchaseIds.add(purchaseToken);
        try {
          final granted = _listingRightPackageGrants[purchase.productID] ?? 0;
          final product = _listingRightProducts
              .cast<ProductDetails?>()
              .firstWhere(
                (p) => p?.id == purchase.productID,
                orElse: () => null,
              );

          final callable = FirebaseFunctions.instanceFor(
            region: 'europe-west1',
          ).httpsCallable('grantListingRights');

          final verificationData = <String, dynamic>{
            'source': purchase.verificationData.source,
            'serverVerificationData':
                purchase.verificationData.serverVerificationData,
            'localVerificationData':
                purchase.verificationData.localVerificationData,
          };

          await callable.call({
            'mode': 'paid_package',
            'productId': purchase.productID,
            'priceText': product?.price ?? '',
            'purchaseId': purchase.purchaseID ?? '',
            'purchasePlatform': purchase.verificationData.source,
            'verificationData': verificationData,
          });
          await _checkUserLimit();

          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '$granted ${tr('listing_rights_added_to_account_suffix')}',
                  style: LocalFonts.poppins(),
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${tr('listing_rights_assign_failed_prefix')}: $e',
                ),
                backgroundColor: Colors.red,
              ),
            );
          }
        } finally {
          if (mounted) setState(() => _isBuyingListingRight = false);
        }
      }

      if (purchase.pendingCompletePurchase) {
        await _inAppPurchase.completePurchase(purchase);
      }
    }
  }

  Future<void> _buySpecificListingRightsPackage(ProductDetails product) async {
    if (_isBuyingListingRight) return;
    final purchaseParam = PurchaseParam(productDetails: product);
    setState(() => _isBuyingListingRight = true);
    _inAppPurchase.buyConsumable(
      purchaseParam: purchaseParam,
      autoConsume: true,
    );
  }

  String _resolveRewardedAdUnitId() {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _rewardedAndroidAdUnitId;
    }
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _rewardedIosAdUnitId;
    }
    return '';
  }

  Future<void> _watchRewardedAdForListingRight() async {
    if (_isRewardLoading) return;
    setState(() => _isRewardLoading = true);

    final adUnitId = _resolveRewardedAdUnitId();
    if (adUnitId.isEmpty) {
      if (mounted) {
        setState(() => _isRewardLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('rewarded_ad_not_supported'))),
        );
      }
      return;
    }

    RewardedAd.load(
      adUnitId: adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          var hasEarnedReward = false;
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              ad.dispose();
              if (mounted) {
                setState(() => _isRewardLoading = false);
                if (!hasEarnedReward) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(tr('watch_ad_until_end_for_reward')),
                    ),
                  );
                }
              }
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              ad.dispose();
              if (mounted) {
                setState(() => _isRewardLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${tr('ad_open_failed_prefix')}: ${error.message}',
                    ),
                  ),
                );
              }
            },
          );

          ad.show(
            onUserEarnedReward: (ad, reward) async {
              hasEarnedReward = true;
              try {
                final callable = FirebaseFunctions.instanceFor(
                  region: 'europe-west1',
                ).httpsCallable('grantListingRights');
                await callable.call({'mode': 'rewarded_1'});
                await _checkUserLimit();

                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        tr('rewarded_ad_success_plus_one_right'),
                        style: LocalFonts.poppins(),
                      ),
                      backgroundColor: Colors.green,
                    ),
                  );
                }
              } on FirebaseFunctionsException catch (e) {
                final message = e.message ?? tr('unknown_server_error');
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${tr('rewarded_ad_assign_failed_prefix')} (${e.code}): $message',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '${tr('rewarded_ad_assign_failed_prefix')}: $e',
                      ),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              }
            },
          );
        },
        onAdFailedToLoad: (error) {
          if (mounted) {
            setState(() => _isRewardLoading = false);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  '${tr('ad_load_failed_prefix')}: ${error.message}',
                ),
              ),
            );
          }
        },
      ),
    );
  }

  void _listenForListingRightChanges() {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    _userLimitSubscription = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((_) => _checkUserLimit());
  }

  Future<void> _checkUserLimit() async {
    try {
      User user = FirebaseAuth.instance.currentUser!;
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      int limit = 10; // GÜNCELLENDİ: Standart ücretsiz ilan limiti 10 yapıldı
      if (userDoc.exists) {
        var data = userDoc.data() as Map<String, dynamic>;
        int adminExtraLimit =
            (data['adminExtraListingLimit'] as num?)?.toInt() ?? 0;
        int? adminListingLimit = (data['adminListingLimit'] as num?)?.toInt();
        if (adminListingLimit != null) {
          // Yönetici toplam limiti açıkça tanımladıysa tek kaynak budur.
          limit = adminListingLimit;
        } else {
          Timestamp? proUntil = data['proUntil'];
          if (proUntil != null && proUntil.toDate().isAfter(DateTime.now())) {
            int proLimit = data['proListingLimit'] ?? 0;
            limit = proLimit > 0
                ? proLimit
                : 10; // Pro paket limiti geçerli olur, ücretsiz limite eklenmez
          }
          // Önceki yönetici tanımları için geriye dönük uyumluluk.
          limit += adminExtraLimit;
        }
      }
      final aggregate = await FirebaseFirestore.instance
          .collection('listings')
          .where('sellerId', isEqualTo: user.uid)
          .where('status', whereIn: ['active', 'pending'])
          .count()
          .get();
      int used = aggregate.count ?? 0;
      if (used >= limit) {
        if (mounted)
          setState(() {
            _canAddListing = false;
            _checkingLimit = false;
            _usedListingsCount = used;
            _listingLimit = limit;
          });
      } else {
        if (mounted)
          setState(() {
            _canAddListing = true;
            _checkingLimit = false;
            _usedListingsCount = used;
            _listingLimit = limit;
          });
      }
    } catch (e) {
      if (mounted) setState(() => _checkingLimit = false);
    } // Hata olursa geçici olarak girmesine izin ver
  }

  @override
  void dispose() {
    _userLimitSubscription?.cancel();
    _purchaseSubscription?.cancel();
    _titleController.dispose();
    _descriptionController.dispose();
    _priceController.dispose();
    _offerMinimumAmountController.dispose();
    _neighborhoodController.dispose();
    for (final controller in _featureTextControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  // GÜNCELLENDİ: RESİMLERE FİLİGRAN EKLEME (Web Uyumluluğu)
  Future<Uint8List> _addWatermark(Uint8List bytes) async {
    final ui.Codec codec = await ui.instantiateImageCodec(bytes);
    final ui.FrameInfo frameInfo = await codec.getNextFrame();
    final ui.Image image = frameInfo.image;

    final ui.PictureRecorder recorder = ui.PictureRecorder();
    final Canvas canvas = Canvas(recorder);

    // Orijinal resmi çiz
    canvas.drawImage(image, Offset.zero, Paint());

    // Transparan Filigran Yazısı Ayarları
    final textStyle = TextStyle(
      color: Colors.white.withValues(alpha: 0.35), // Transparan beyaz
      fontSize: image.width * 0.15, // Resmin büyüklüğüne göre ölçekle
      fontWeight: FontWeight.bold,
      shadows: [
        Shadow(
          color: Colors.black.withValues(alpha: 0.3),
          offset: const Offset(2, 2),
          blurRadius: 6,
        ),
      ], // Okunabilirliği artıran gölge
    );

    final textSpan = TextSpan(text: 'Kişiden', style: textStyle);
    final textPainter = TextPainter(
      text: textSpan,
      textDirection: ui.TextDirection.ltr,
    );
    textPainter.layout();

    // Yazıyı tam ortaya, hafif çapraz yerleştir (Hırsızlığı zorlaştırmak için)
    canvas.translate(image.width / 2, image.height / 2);
    canvas.rotate(-0.5); // Sola eğik açı
    canvas.translate(-image.width / 2, -image.height / 2);

    final offset = Offset(
      (image.width - textPainter.width) / 2,
      (image.height - textPainter.height) / 2,
    );
    textPainter.paint(canvas, offset);

    final ui.Picture picture = recorder.endRecording();
    final ui.Image watermarkedImage = await picture.toImage(
      image.width,
      image.height,
    );
    final ByteData? byteData = await watermarkedImage.toByteData(
      format: ui.ImageByteFormat.png,
    );

    // YENİ: Grafik belleği (Buffer) sızıntısını engellemek için resimleri GPU'dan anında temizliyoruz.
    image.dispose();
    watermarkedImage.dispose();
    codec.dispose(); // Sızıntı yapabilen Codec verisini de temizliyoruz

    return byteData!.buffer.asUint8List();
  }

  // GÜNCELLENDİ: RESİM SIKIŞTIRMA FONKSİYONU (Web uyumlu bellek içi sıkıştırma)
  Future<Uint8List?> _compressImage(Uint8List bytes) async {
    try {
      var result = await image_compress.FlutterImageCompress.compressWithList(
        bytes,
        quality: 70,
        minWidth: 1080,
        minHeight: 1080,
        format: image_compress.CompressFormat.jpeg,
      );
      return result;
    } catch (e) {
      // Web tarafında veya eklenti kaynaklı bir sorun olursa orijinal byte'ları döndürür
      return bytes;
    }
  }

  // YENİ: TOPLU RESİM SEÇME VE OTOMATİK İŞLEME FONKSİYONU
  Future<void> _pickMultipleImages() async {
    // KESİN ÇÖZÜM: Resimleri cihazın galerisinden çıkarırken İşletim Sisteminin (Native) gücüyle küçültüyoruz.
    // Böylece uygulamanın RAM'ine ve GPU'suna asla 4K orijinal dosyalar girmiyor, çökme tamamen ortadan kalkıyor!
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );

    if (pickedFiles.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingText = tr('processing_photos_wait');
      });

      // Maksimum 15 sınırını seçilen dosya sayısıyla kıyaslayalım
      int loopCount = pickedFiles.length > 15 ? 15 : pickedFiles.length;

      for (int i = 0; i < loopCount; i++) {
        if (_optimizedImages.length >= 15) break; // Maksimum 15 fotoğraf sınırı

        // İlerleme durumunu kullanıcıya gösterelim (Örn: Fotoğraflar işleniyor... 1/5)
        setState(() {
          _loadingText = "${tr('processing_photos')} (${i + 1}/$loopCount)";
        });

        // Cihazın render kuyruğunu tam olarak boşaltması için çok kısa bir bekleme
        await Future.delayed(const Duration(milliseconds: 300));

        Uint8List originalBytes = await pickedFiles[i].readAsBytes();
        Uint8List watermarkedBytes = await _addWatermark(
          originalBytes,
        ); // Arka planda filigranı ekle
        Uint8List? compressedBytes = await _compressImage(
          watermarkedBytes,
        ); // Boyutunu küçült ve sıkıştır

        if (compressedBytes != null) {
          _optimizedImages.add(compressedBytes);
        } else {
          _optimizedImages.add(
            watermarkedBytes,
          ); // Sıkıştırma hatası olursa fall-back
        }
      }

      setState(() {
        _isLoading = false;
        _loadingText = "";
      });
    }
  }

  Future<void> _fetchCategoryFeatures(String categoryId) async {
    var doc = await FirebaseFirestore.instance
        .collection('categories')
        .doc(categoryId)
        .get();
    if (doc.exists) {
      var data = doc.data() as Map<String, dynamic>;
      List<dynamic> rawFeatures = data['features'] ?? [];
      setState(() {
        _categoryFeatures.clear();
        _featureTextControllers.clear();
        _featureDropdownValues.clear();
        for (var f in rawFeatures) {
          if (f is String) {
            _categoryFeatures.add({'name': f, 'options': []});
            _featureTextControllers[f] = TextEditingController();
          } else if (f is Map) {
            String name = f['name'];
            List<String> options = List<String>.from(f['options'] ?? []);
            _categoryFeatures.add({'name': name, 'options': options});
            if (options.isEmpty) {
              _featureTextControllers[name] = TextEditingController();
            } else {
              _featureDropdownValues[name] = null;
            }
          }
        }
      });
    }
  }

  void _showCategoryPicker(
    String parentId,
    String currentPath, [
    String currentDisplayPath = "",
    Map<String, String>? currentAttributes,
  ]) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getCategoriesStream(parentId),
          builder: (context, snapshot) {
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            var docs = snapshot.data!.docs.toList();

            docs.sort((a, b) {
              var ad = a.data() as Map<String, dynamic>;
              var bd = b.data() as Map<String, dynamic>;
              int orderA = ad['order'] ?? 0;
              int orderB = bd['order'] ?? 0;
              if (orderA != orderB) return orderA.compareTo(orderB);
              Timestamp? tA = ad['createdAt'];
              Timestamp? tB = bd['createdAt'];
              if (tA != null && tB != null) return tA.compareTo(tB);
              return 0;
            });

            if (docs.isEmpty) {
              Future.delayed(Duration.zero, () {
                setState(() {
                  selectedCategoryId = parentId;
                  selectedCategoryName = currentPath.split(' > ').last;
                  fullCategoryPath = currentPath;
                  fullCategoryDisplayPath = currentDisplayPath;
                  _autoAttributes = currentAttributes ?? {}; // YENİ
                });
                _fetchCategoryFeatures(parentId);
                Navigator.pop(context);
              });
              return Center(
                child: Text(tr('approving'), style: LocalFonts.poppins()),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
                  child: Row(
                    children: [
                      if (currentPath.isNotEmpty)
                        IconButton(
                          icon: const Icon(Icons.arrow_back),
                          tooltip: 'Üst kategoriye dön',
                          onPressed: () async {
                            final parentSnapshot = await FirebaseFirestore
                                .instance
                                .collection('categories')
                                .doc(parentId)
                                .get();
                            if (!context.mounted) return;
                            final categoryData = parentSnapshot.data();
                            final grandParentId =
                                categoryData?['parentId']?.toString() ?? '';
                            final pathParts = currentPath
                                .split(' > ')
                                .where((part) => part.isNotEmpty)
                                .toList();
                            final displayParts = currentDisplayPath
                                .split(' > ')
                                .where((part) => part.isNotEmpty)
                                .toList();
                            pathParts.removeLast();
                            if (displayParts.isNotEmpty) {
                              displayParts.removeLast();
                            }
                            Navigator.pop(context);
                            _showCategoryPicker(
                              grandParentId,
                              pathParts.join(' > '),
                              displayParts.join(' > '),
                              currentAttributes,
                            );
                          },
                        ),
                      if (currentPath.isEmpty)
                        Expanded(
                          child: Center(
                            child: Text(
                              tr('select_category'),
                              style: LocalFonts.poppins(
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        )
                      else
                        Expanded(
                          child: Text(
                            currentDisplayPath,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      var docData = docs[index].data() as Map<String, dynamic>;
                      String originalName = docData['name'];
                      String translatedName = getTranslatedText(
                        docData,
                        'name',
                      );
                      String attrType = docData['attributeType'] ?? '';
                      String clickedId = docs[index].id;

                      return ListTile(
                        title: Text(
                          translatedName,
                          style: LocalFonts.poppins(),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () async {
                          String newPath = currentPath.isEmpty
                              ? originalName
                              : "$currentPath > $originalName";
                          String newDisplayPath = currentDisplayPath.isEmpty
                              ? translatedName
                              : "$currentDisplayPath > $translatedName";

                          Map<String, String> newAttributes = Map.from(
                            currentAttributes ?? {},
                          );
                          if (attrType.trim().isNotEmpty) {
                            newAttributes[attrType.trim()] = originalName;
                          }

                          // YENİ ÇÖZÜM: Veritabanına alt kategori var mı diye bakana kadar pencereyi açık tutuyoruz.
                          var subCats = await FirebaseFirestore.instance
                              .collection('categories')
                              .where('parentId', isEqualTo: clickedId)
                              .limit(1)
                              .get();
                          if (!context.mounted) return;

                          if (subCats.docs.isEmpty) {
                            Navigator.pop(
                              context,
                            ); // Alt kategori kalmadıysa pencereyi tamamen kapat
                            setState(() {
                              selectedCategoryId = clickedId;
                              selectedCategoryName = newPath.split(' > ').last;
                              fullCategoryPath = newPath;
                              fullCategoryDisplayPath = newDisplayPath;
                              _autoAttributes = newAttributes;
                            });
                            _fetchCategoryFeatures(clickedId);
                          } else {
                            Navigator.pop(
                              context,
                            ); // Alt kategori varsa, bu pencereyi kapatıp hemen yeni pencereyi aç
                            _showCategoryPicker(
                              clickedId,
                              newPath,
                              newDisplayPath,
                              newAttributes,
                            );
                          }
                        },
                      );
                    },
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  String _normalizeLocationToken(String value) {
    var normalized = value.trim().toLowerCase();
    const replacements = <String, String>{
      'ç': 'c',
      'ğ': 'g',
      'ı': 'i',
      'i̇': 'i',
      'ö': 'o',
      'ş': 's',
      'ü': 'u',
      'â': 'a',
      'î': 'i',
      'û': 'u',
    };
    replacements.forEach((from, to) {
      normalized = normalized.replaceAll(from, to);
    });

    // Remove combining marks and separators so different Unicode forms match.
    normalized = normalized.replaceAll(RegExp(r'[\u0300-\u036f]'), '');
    normalized = normalized.replaceAll(RegExp(r'[^a-z0-9]'), '');
    return normalized;
  }

  List<String> _cityLookupCandidates(String city) {
    final normalized = _normalizeLocationToken(city);
    final candidates = <String>{normalized};
    if (normalized == 'icel') candidates.add('mersin');
    if (normalized == 'mersin') candidates.add('icel');
    return candidates.toList();
  }

  Future<void> _ensureNeighborhoodDataLoaded() async {
    if (_neighborhoodsJsonCache != null) return;

    final jsonString = await rootBundle.loadString('assets/mahalleler.json');
    final parsed = json.decode(jsonString);
    if (parsed is! Map<String, dynamic>) {
      throw const FormatException('mahalleler.json formatı geçersiz');
    }

    final normalizedIndex = <String, List<String>>{};
    parsed.forEach((key, value) {
      final split = key.split('_');
      if (split.length < 2 || value is! List) return;

      final city = split.first;
      final district = split.sublist(1).join('_');
      final indexKey =
          '${_normalizeLocationToken(city)}_${_normalizeLocationToken(district)}';

      final neighborhoods = value
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      if (neighborhoods.isEmpty) return;
      final existing = normalizedIndex[indexKey] ?? <String>[];
      final merged = <String>{...existing, ...neighborhoods}.toList()..sort();
      normalizedIndex[indexKey] = merged;
    });

    _neighborhoodsJsonCache = parsed;
    _normalizedNeighborhoodsIndex = normalizedIndex;
  }

  List<String> _resolveNeighborhoods(String city, String district) {
    final rawMap = _neighborhoodsJsonCache;
    if (rawMap == null) return const [];

    final directKey = '${city.trim()}_${district.trim()}';
    final directMatch = rawMap[directKey];
    if (directMatch is List) {
      return directMatch
          .whereType<String>()
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toSet()
          .toList()
        ..sort();
    }

    final normalizedDistrict = _normalizeLocationToken(district);
    for (final cityCandidate in _cityLookupCandidates(city)) {
      final normalizedKey = '${cityCandidate}_$normalizedDistrict';
      final match = _normalizedNeighborhoodsIndex[normalizedKey];
      if (match != null && match.isNotEmpty) {
        return List<String>.from(match);
      }
    }

    return const [];
  }

  // YENİ: JSON dosyasından asenkron olarak mahalleleri yükleme fonksiyonu
  Future<void> _loadNeighborhoods(String city, String district) async {
    setState(() {
      _isLoadingNeighborhoods = true;
      _selectedNeighborhood = null;
      _neighborhoodController.clear();
      _currentNeighborhoods = [];
    });
    try {
      await _ensureNeighborhoodDataLoaded();
      final resolvedNeighborhoods = _resolveNeighborhoods(city, district);
      setState(() {
        _currentNeighborhoods = resolvedNeighborhoods;
      });

      if (resolvedNeighborhoods.isEmpty) {
        debugPrint('Mahalle bulunamadı: city=$city district=$district');
      }
    } catch (e) {
      debugPrint("Mahalleler yüklenemedi: $e");
    } finally {
      setState(() {
        _isLoadingNeighborhoods = false;
      });
    }
  }

  List<String> _getMissingRequiredFields() {
    final missingFields = <String>[];

    if (_optimizedImages.isEmpty) {
      missingFields.add(tr('photo'));
    }
    if (_titleController.text.trim().isEmpty) {
      missingFields.add(tr('listing_title'));
    }
    if (_descriptionController.text.trim().isEmpty) {
      missingFields.add(tr('description'));
    }
    if (_priceController.text.trim().isEmpty) {
      missingFields.add(tr('price_tl'));
    }
    if (_selectedCity == null || _selectedCity!.trim().isEmpty) {
      missingFields.add(tr('city'));
    }
    if (_selectedDistrict == null || _selectedDistrict!.trim().isEmpty) {
      missingFields.add(tr('district'));
    }

    return missingFields;
  }

  void _nextStep() {
    final missingFields = _getMissingRequiredFields();
    if (missingFields.isNotEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: Colors.red.shade700,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('missing_required_fields'),
                      style: LocalFonts.poppins(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${missingFields.join(', ')}',
                      style: LocalFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.95),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }
    setState(() => _currentStep = 2);
  }

  Future<Position?> _getUserLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) return null;
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) return null;
      }
      if (permission == LocationPermission.deniedForever) return null;
      return await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );
    } catch (e) {
      return null;
    }
  }

  String? _matchLocationValue(Iterable<String> values, String? candidate) {
    final normalizedCandidate = _normalizeLocationToken(candidate ?? '');
    if (normalizedCandidate.isEmpty) return null;
    for (final value in values) {
      final normalizedValue = _normalizeLocationToken(value);
      if (normalizedValue == normalizedCandidate ||
          normalizedValue.contains(normalizedCandidate) ||
          normalizedCandidate.contains(normalizedValue)) {
        return value;
      }
    }
    return null;
  }

  Future<void> _detectListingLocation() async {
    if (_isDetectingLocation) return;
    setState(() => _isDetectingLocation = true);
    try {
      final position = await _getUserLocation();
      if (position == null) {
        throw StateError(tr('location_not_available'));
      }

      final placemarks = await Geocoding().placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      if (placemarks.isEmpty) {
        throw StateError(tr('location_not_available'));
      }

      final place = placemarks.first;
      final city = _matchLocationValue(
        turkeyLocations.keys,
        place.administrativeArea ?? place.locality,
      );
      if (city == null) {
        throw StateError(tr('location_not_available'));
      }
      final district = _matchLocationValue(
        turkeyLocations[city] ?? const <String>[],
        place.subAdministrativeArea ?? place.locality,
      );
      if (district == null) {
        throw StateError(tr('location_not_available'));
      }

      await _ensureNeighborhoodDataLoaded();
      final neighborhood = _matchLocationValue(
        _resolveNeighborhoods(city, district),
        place.subLocality ?? place.thoroughfare,
      );

      setState(() {
        _selectedPosition = position;
        _selectedCity = city;
        _selectedDistrict = district;
        _selectedNeighborhood = neighborhood;
        _neighborhoodController.text = neighborhood ?? '';
      });
      await _loadNeighborhoods(city, district);
      if (!mounted) return;
      setState(() {
        _selectedNeighborhood = neighborhood;
        _neighborhoodController.text = neighborhood ?? '';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('location_detected')}: $city, $district'
            '${neighborhood == null ? '' : ', $neighborhood'}',
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('${tr('location_error')}: $error')),
      );
    } finally {
      if (mounted) setState(() => _isDetectingLocation = false);
    }
  }

  Future<void> _submitListing() async {
    if (selectedCategoryId == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_select_category'))));
      return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    // ÇÖZÜM: Gizli boşluk, virgül veya geçersiz karakter hatalarını (FormatException) önlemek için RegExp ile sadece sayıları alıyoruz
    double parsedPrice =
        double.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0.0;

    Map<String, String> featuresToSave = {};
    // Kategori ağacından yakalanan gizli özellikleri önce ekliyoruz
    featuresToSave.addAll(_autoAttributes);

    // YENİ: Mahalle bilgisini özellikler arasına kaydediyoruz (Böylece İlan detaylarında "Mahalle" olarak görünür)
    String finalNeighborhood =
        _selectedNeighborhood ?? _neighborhoodController.text.trim();
    if (finalNeighborhood.isNotEmpty) {
      featuresToSave['Mahalle'] = finalNeighborhood;
    }

    _featureTextControllers.forEach((key, c) {
      if (c.text.trim().isNotEmpty) featuresToSave[key] = c.text.trim();
    });
    _featureDropdownValues.forEach((key, val) {
      if (val != null && val.isNotEmpty) featuresToSave[key] = val;
    });

    setState(() {
      _isLoading = true;
      _loadingText = tr('analyzing_buyers');
    });

    try {
      // YENİ: Arama alarmlarında bizim ilanımızın özelliklerine uygun alıcı var mı diye bakıyoruz
      var alarmData = await _dbService.checkAlarmsForListing(
        categoryPath: fullCategoryPath,
        city: _selectedCity!,
        district: _selectedDistrict!,
        features: featuresToSave,
        currentUserId: user.uid,
      );

      int matchCount = alarmData['matchCount'] ?? 0;
      double maxBudget = alarmData['maxBudget'] ?? 0.0;

      setState(() {
        _isLoading = false;
        _loadingText = "";
      });

      if (matchCount > 0) {
        if (parsedPrice > maxBudget && maxBudget > 0) {
          // Senaryo A: Alıcı var ama fiyatımız onların bütçesinden yüksek!
          if (mounted)
            _showPriceDropOfferDialog(
              matchCount,
              maxBudget,
              parsedPrice,
              featuresToSave,
            );
        } else {
          // Senaryo B: Fiyatımız çoktan bütçelerine uygun veya alıcıların bütçe limiti yok.
          if (mounted)
            _showGoodNewsDialog(matchCount, parsedPrice, featuresToSave);
        }
      } else {
        // Hiç eşleşen çıkmadıysa doğrudan yükleme aşamasına geç
        _finalizeListing(parsedPrice, featuresToSave);
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
        _loadingText = "";
      });
      _finalizeListing(
        parsedPrice,
        featuresToSave,
      ); // Hata olursa süreci kesme, normal devam et
    }
  }

  Future<void> _finalizeListing(
    double finalPrice,
    Map<String, String> featuresToSave, {
    bool isDiscountedForAlarms = false,
  }) async {
    setState(() {
      _isLoading = true;
      _loadingText = tr('getting_location');
    });
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        Position? position = _selectedPosition ?? await _getUserLocation();
        setState(() {
          _loadingText = tr('processing_listing');
        });

        String? mainImageUrl;
        List<String> additionalImages = [];
        for (int i = 0; i < _optimizedImages.length; i++) {
          String fileName =
              "${user.uid}_${DateTime.now().millisecondsSinceEpoch}_$i";
          String? url = await _dbService.uploadImage(
            _optimizedImages[i],
            fileName,
          );
          if (url != null) {
            if (i == 0) {
              mainImageUrl = url;
            } else {
              additionalImages.add(url);
            }
          }
        }

        if (mainImageUrl != null) {
          try {
            bool success = await _dbService.addListing(
              title: _titleController.text.trim(),
              description: _descriptionController.text.trim(),
              price: finalPrice,
              imageUrl: mainImageUrl,
              additionalImages: additionalImages,
              category: selectedCategoryName,
              categoryPath: fullCategoryPath,
              featuresMap: featuresToSave,
              user: user,
              lat: position?.latitude,
              lng: position?.longitude,
              city: _selectedCity!,
              district: _selectedDistrict!,
              isDiscountedForAlarms: isDiscountedForAlarms,
              isOfferEnabled: _offersEnabled,
              offerValidityHours: _offerValidityHours,
              offerMinimumPercent: _offerMinimumPercent,
              offerMinimumAmount: double.tryParse(
                _offerMinimumAmountController.text.trim().replaceAll(',', '.'),
              ),
              autoRenew: false,
              tradeEnabled: _tradeEnabled,
            );
            if (success && mounted) {
              // YENİ: Kullanıcıyı animasyonlu başarı ekranına yönlendir
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (context) => const ListingSuccessScreen(),
                ),
              );
            } else {
              // Başarısız olduysa kullanıcıya bilgi ver
              if (mounted)
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      tr('listing_publish_failed') +
                          ' ' +
                          tr('check_console_for_details'),
                    ),
                    backgroundColor: Colors.red,
                  ),
                );
            }
          } catch (e) {
            // Eğer güvenlik kuralları nedeniyle izin reddedildiyse, kullanıcıya daha açıklayıcı mesaj göster
            String errMsg = '${tr('error')}$e';
            try {
              if (e is FirebaseException && e.code == 'permission-denied') {
                errMsg = tr('permission_denied_publish_hint');
              }
            } catch (_) {}

            if (mounted)
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text(errMsg), backgroundColor: Colors.red),
              );
          }
        } else {
          // mainImageUrl null döndüyse upload başarısız olmuş demektir
          if (mounted)
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  tr('image_upload_failed') +
                      ' ' +
                      tr('check_console_for_details'),
                ),
                backgroundColor: Colors.red,
              ),
            );
        }
      }
    } catch (e) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('error')}$e'),
            backgroundColor: Colors.red,
          ),
        );
    } finally {
      if (mounted)
        setState(() {
          _isLoading = false;
          _loadingText = "";
        });
    }
  }

  void _showPriceDropOfferDialog(
    int count,
    double budget,
    double currentPrice,
    Map<String, String> featuresToSave,
  ) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.local_fire_department,
              size: 60,
              color: Colors.orange,
            ),
            const SizedBox(height: 16),
            Text(
              tr('great_news'),
              style: LocalFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.orange[800],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: LocalFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: "${tr('buyers_looking_for_listing')} "),
                  TextSpan(
                    text: "$count ${tr('people')} ",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                  TextSpan(text: "${tr('but_max_budget_is')} "),
                  TextSpan(
                    text: formatter.format(budget),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  TextSpan(
                    text:
                        " (${tr('your_price')}: ${formatter.format(currentPrice)}).\n\n",
                  ),
                  TextSpan(text: "${tr('if_you_want_price')} "),
                  TextSpan(
                    text: "${formatter.format(budget)} ",
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: tr('update_price_and_sell_faster')),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[700],
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(c);
                _priceController.text = budget.toStringAsFixed(
                  0,
                ); // Fiyatı text alanında da güncelliyoruz
                _finalizeListing(
                  budget,
                  featuresToSave,
                  isDiscountedForAlarms: true,
                ); // YENİ: İndirim bayrağını (flag) true olarak yolluyoruz
              },
              child: Text(
                "${tr('set_price_to')} ${formatter.format(budget)} ${tr('and_publish')}",
                style: LocalFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 15,
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () {
                Navigator.pop(c);
                _finalizeListing(
                  currentPrice,
                  featuresToSave,
                ); // Eski fiyatta ısrarcıysa böyle yolluyoruz
              },
              child: Text(
                tr('publish_with_current_price'),
                style: LocalFonts.poppins(
                  color: Colors.grey[600],
                  fontSize: 14,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showGoodNewsDialog(
    int count,
    double currentPrice,
    Map<String, String> featuresToSave,
  ) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (c) => Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.celebration, size: 60, color: Colors.green),
            const SizedBox(height: 16),
            Text(
              tr('awesome'),
              style: LocalFonts.poppins(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.green[800],
              ),
            ),
            const SizedBox(height: 12),
            RichText(
              textAlign: TextAlign.center,
              text: TextSpan(
                style: LocalFonts.poppins(
                  fontSize: 14,
                  color: Colors.black87,
                  height: 1.5,
                ),
                children: [
                  TextSpan(text: "${tr('buyers_waiting_with_budget')} "),
                  TextSpan(
                    text: "$count ${tr('people')} ",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.green,
                    ),
                  ),
                  TextSpan(text: tr('will_notify_buyers')),
                ],
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () {
                Navigator.pop(c);
                _finalizeListing(currentPrice, featuresToSave);
              },
              child: Text(
                tr('great_publish'),
                style: LocalFonts.poppins(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingLimit) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(tr('new_listing_step'), style: LocalFonts.poppins()),
        ),
        body: const Center(
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (!_canAddListing) {
      return Scaffold(
        backgroundColor: Colors.white,
        appBar: AppBar(
          title: Text(tr('new_listing_step'), style: LocalFonts.poppins()),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Center(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.secondary.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.workspace_premium,
                        size: 80,
                        color: AppColors.secondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('listing_limit_reached'),
                      textAlign: TextAlign.center,
                      style: LocalFonts.poppins(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 24),

                    // Kullanım Durumu Kutusu
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: Column(
                        children: [
                          Text(
                            '${tr('used_listing_rights')}: $_usedListingsCount / $_listingLimit',
                            style: LocalFonts.poppins(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            tr('listing_limit_desc'),
                            textAlign: TextAlign.center,
                            style: LocalFonts.poppins(
                              color: Colors.grey[700],
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: () {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const ProPurchaseScreen(),
                          ),
                        );
                      },
                      icon: const Icon(Icons.star, color: Colors.white),
                      label: Text(
                        tr('upgrade_pro'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.secondary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const SizedBox(height: 10),
                    if (_listingRightProducts.isNotEmpty)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          tr('paid_listing_right_packages_title'),
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    if (_listingRightProducts.isNotEmpty)
                      const SizedBox(height: 8),
                    if (_listingRightProducts.isNotEmpty) ...[
                      ...([..._listingRightProducts]..sort((a, b) {
                            final ga = _listingRightPackageGrants[a.id] ?? 0;
                            final gb = _listingRightPackageGrants[b.id] ?? 0;
                            return ga.compareTo(gb);
                          }))
                          .map((product) {
                            final grant =
                                _listingRightPackageGrants[product.id] ?? 0;
                            final title =
                                _listingRightPackageTitles[product.id] ??
                                '$grant ${tr('listing_rights_unit')}';
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: OutlinedButton.icon(
                                onPressed: _isBuyingListingRight
                                    ? null
                                    : () => _buySpecificListingRightsPackage(
                                        product,
                                      ),
                                icon: const Icon(Icons.payment),
                                label: Text(
                                  '$title ${tr('buy_action')} (${product.price})',
                                  style: LocalFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                style: OutlinedButton.styleFrom(
                                  minimumSize: const Size(double.infinity, 46),
                                  side: BorderSide(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.4,
                                    ),
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            );
                          }),
                    ],
                    if (_listingRightProducts.isEmpty)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.orange.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: Colors.orange.withValues(alpha: 0.4),
                          ),
                        ),
                        child: Text(
                          tr(
                            'listing_right_packages_unavailable_check_console',
                          ),
                          style: LocalFonts.poppins(
                            fontSize: 12,
                            color: Colors.orange[900],
                          ),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: _isRewardLoading
                          ? null
                          : _watchRewardedAdForListingRight,
                      icon: _isRewardLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.ondemand_video_rounded),
                      label: Text(
                        tr('watch_ad_get_plus_one_right'),
                        style: LocalFonts.poppins(fontWeight: FontWeight.w600),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${tr('rewarded_ad_daily_limit_prefix')}$_rewardDailyMax ${tr('rewarded_ad_daily_limit_middle')}$_rewardCooldownMinutes ${tr('rewarded_ad_daily_limit_suffix')}',
                      textAlign: TextAlign.center,
                      style: LocalFonts.poppins(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          '${tr('new_listing_step')} $_currentStep/2)',
          style: LocalFonts.poppins(),
        ),
        leading: _currentStep == 2
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () => setState(() => _currentStep = 1),
              )
            : null,
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const CircularProgressIndicator(color: AppColors.primary),
                  const SizedBox(height: 16),
                  Text(
                    _loadingText,
                    style: LocalFonts.poppins(
                      color: AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: _currentStep == 1 ? _buildStep1() : _buildStep2(),
            ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _pickMultipleImages, // GÜNCELLENDİ: Artık toplu seçim yapıyor
          child: Container(
            height: 150,
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary, width: 1),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.add_photo_alternate,
                  size: 40,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 8),
                Text(
                  tr('bulk_photo_select'),
                  style: LocalFonts.poppins(color: AppColors.primary),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (_optimizedImages.isNotEmpty)
          SizedBox(
            height: 100,
            child: ReorderableListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: _optimizedImages.length,
              onReorder: (int oldIndex, int newIndex) {
                setState(() {
                  if (oldIndex < newIndex) {
                    newIndex -= 1;
                  }
                  final Uint8List item = _optimizedImages.removeAt(oldIndex);
                  _optimizedImages.insert(newIndex, item);
                });
              },
              proxyDecorator:
                  (Widget child, int index, Animation<double> animation) {
                    return Material(color: Colors.transparent, child: child);
                  },
              itemBuilder: (context, index) => Container(
                key: ObjectKey(_optimizedImages[index]),
                margin: const EdgeInsets.only(right: 8),
                width: 85,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: index == 0
                      ? Border.all(color: AppColors.primary, width: 3)
                      : null,
                  image: DecorationImage(
                    image: MemoryImage(_optimizedImages[index]),
                    fit: BoxFit.cover,
                  ),
                ),
                child: Stack(
                  children: [
                    if (index == 0)
                      Positioned(
                        bottom: 0,
                        left: 0,
                        right: 0,
                        child: Container(
                          decoration: BoxDecoration(
                            color: AppColors.primary.withValues(alpha: 0.9),
                            borderRadius: const BorderRadius.vertical(
                              bottom: Radius.circular(5),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Text(
                            "Kapak",
                            textAlign: TextAlign.center,
                            style: LocalFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    Align(
                      alignment: Alignment.topRight,
                      child: GestureDetector(
                        onTap: () =>
                            setState(() => _optimizedImages.removeAt(index)),
                        child: Container(
                          margin: const EdgeInsets.all(4),
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: Colors.white,
                          ),
                          child: const Icon(
                            Icons.cancel,
                            color: Colors.red,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          decoration: InputDecoration(
            labelText: tr('listing_title'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _priceController,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.number,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            CurrencyInputFormatter(),
          ],
          decoration: InputDecoration(
            labelText: tr('price_tl'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tr('offer_settings')),
                  subtitle: Text(tr('offer_settings_desc')),
                  value: _offersEnabled,
                  onChanged: (value) =>
                      setState(() => _offersEnabled = value),
                ),
                if (_offersEnabled) ...[
                  DropdownButtonFormField<int>(
                    value: _offerValidityHours,
                    decoration: InputDecoration(
                      labelText: tr('offer_validity'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 24, child: Text('24 saat')),
                      DropdownMenuItem(value: 48, child: Text('48 saat')),
                    ],
                    onChanged: (value) => setState(
                      () => _offerValidityHours = value ?? 24,
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<int>(
                    value: _offerMinimumPercent,
                    decoration: InputDecoration(
                      labelText: tr('offer_minimum_percent'),
                    ),
                    items: const [
                      DropdownMenuItem(value: 70, child: Text('%70')),
                      DropdownMenuItem(value: 80, child: Text('%80')),
                      DropdownMenuItem(value: 90, child: Text('%90')),
                    ],
                    onChanged: (value) => setState(
                      () => _offerMinimumPercent = value ?? 70,
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _offerMinimumAmountController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('offer_minimum_amount'),
                      prefixText: '₺ ',
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: SwitchListTile(
            title: Text(tr('trade_settings')),
            subtitle: Text(tr('trade_settings_desc')),
            value: _tradeEnabled,
            onChanged: (value) => setState(() => _tradeEnabled = value),
          ),
        ),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: _isDetectingLocation ? null : _detectListingLocation,
            icon: _isDetectingLocation
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.my_location),
            label: Text(
              _isDetectingLocation
                  ? tr('getting_location')
                  : tr('use_current_location'),
            ),
          ),
        ),
        const SizedBox(height: 12),

        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('city'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                ),
                initialValue: _selectedCity,
                items: turkeyLocations.keys
                    .map(
                      (city) => DropdownMenuItem(
                        value: city,
                        child: Text(city, overflow: TextOverflow.ellipsis),
                      ),
                    )
                    .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedCity = val;
                    _selectedDistrict = null;
                    _selectedNeighborhood = null;
                    _neighborhoodController.clear();
                    _currentNeighborhoods =
                        []; // YENİ: Şehir değişince mahalleleri sıfırla
                  });
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('district'),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 15,
                  ),
                ),
                initialValue: _selectedDistrict,
                items: _selectedCity == null
                    ? []
                    : turkeyLocations[_selectedCity]!
                          .map(
                            (d) => DropdownMenuItem(
                              value: d,
                              child: Text(d, overflow: TextOverflow.ellipsis),
                            ),
                          )
                          .toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedDistrict = val;
                    _selectedNeighborhood = null;
                    _neighborhoodController.clear();
                  });
                  if (val != null && _selectedCity != null) {
                    _loadNeighborhoods(
                      _selectedCity!,
                      val,
                    ); // YENİ: İlçe seçilince mahalleleri çek
                  }
                },
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),
        if (_isLoadingNeighborhoods)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16.0),
            child: Center(child: CircularProgressIndicator()),
          )
        else if (_currentNeighborhoods.isNotEmpty)
          DropdownButtonFormField<String>(
            isExpanded: true,
            decoration: InputDecoration(
              labelText: tr('neighborhood_optional'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 15,
              ),
            ),
            initialValue: _selectedNeighborhood,
            items: _currentNeighborhoods
                .map(
                  (n) => DropdownMenuItem(
                    value: n,
                    child: Text(n, overflow: TextOverflow.ellipsis),
                  ),
                )
                .toList(),
            onChanged: (val) {
              setState(() {
                _selectedNeighborhood = val;
                _neighborhoodController.text = val ?? '';
              });
            },
          )
        else
          TextField(
            controller: _neighborhoodController,
            decoration: InputDecoration(
              labelText: tr('neighborhood_optional'),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),

        const SizedBox(height: 16),
        TextField(
          controller: _descriptionController,
          onChanged: (_) => setState(() {}),
          maxLines: 5,
          decoration: InputDecoration(
            labelText: tr('description'),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
        ),

        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: _nextStep,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue[800],
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            tr('next_category_selection'),
            style: LocalFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStep2() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          tileColor: AppColors.primary.withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          leading: const Icon(Icons.category, color: AppColors.primary),
          title: Text(
            fullCategoryDisplayPath.isEmpty
                ? tr('select_category_mandatory')
                : fullCategoryDisplayPath,
            style: LocalFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
          trailing: const Icon(Icons.edit, size: 20),
          onTap: () => _showCategoryPicker("", "", ""),
        ),
        const SizedBox(height: 16),
        if (_categoryFeatures.isNotEmpty) ...[
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.secondary.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppColors.secondary.withValues(alpha: 0.3),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('category_features'),
                  style: LocalFonts.poppins(
                    fontWeight: FontWeight.bold,
                    color: AppColors.secondary,
                  ),
                ),
                const SizedBox(height: 12),
                ..._categoryFeatures.map((feature) {
                  String name = feature['name'];
                  List<String> options = feature['options'];
                  if (options.isNotEmpty) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: DropdownButtonFormField<String>(
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: name,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          fillColor: Colors.white,
                          filled: true,
                        ),
                        initialValue: _featureDropdownValues[name],
                        hint: Text('$name ${tr('select')}'),
                        items: options
                            .toSet()
                            .map(
                              (opt) => DropdownMenuItem(
                                value: opt,
                                child: Text(
                                  opt,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _featureDropdownValues[name] = val),
                      ),
                    );
                  } else {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: TextField(
                        controller: _featureTextControllers[name],
                        onChanged: (_) => setState(() {}),
                        decoration: InputDecoration(
                          labelText: name,
                          border: const OutlineInputBorder(),
                          isDense: true,
                          fillColor: Colors.white,
                          filled: true,
                        ),
                      ),
                    );
                  }
                }),
              ],
            ),
          ),
          const SizedBox(height: 16),
        ],
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: _submitListing,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[700],
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: Text(
            tr('publish_send_approval'),
            style: LocalFonts.poppins(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
}

class CurrencyInputFormatter extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) return newValue;
    int value = int.parse(newValue.text.replaceAll(RegExp(r'[^0-9]'), ''));
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '',
      decimalDigits: 0,
    );
    String newText = formatter.format(value).trim();
    return newValue.copyWith(
      text: newText,
      selection: TextSelection.collapsed(offset: newText.length),
    );
  }
}
