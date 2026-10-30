import 'dart:async';

import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'listing_camera_screen.dart';
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
import '../widgets/defect_marker_tools.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  bool _offersEnabled = false;
  bool _tradeEnabled = false;
  bool _cashOnDeliveryAvailable = false;
  int _offerValidityHours = 24;
  int _offerMinimumPercent = 70;
  final _offerMinimumAmountController = TextEditingController();
  final _neighborhoodController = TextEditingController();
  String? _selectedNeighborhood;
  final DatabaseService _dbService = DatabaseService();
  final ImagePicker _picker = ImagePicker();

  final List<Uint8List> _optimizedImages =
      []; // YENİ: Web uyumluluğu için File yerine Byte Listesi kullanıyoruz
  List<DefectMarker> _defectMarkers = <DefectMarker>[];
  bool _isLoading = false;
  String _loadingText = "";
  bool _showStep1Validation = false;
  bool _showCategoryValidation = false;
  bool _draftReady = false;
  bool _isApplyingDraft = false;
  bool _hasLocalDraft = false;
  bool _draftSaveErrorShown = false;
  Timer? _draftSaveTimer;
  String? _draftOwnerUid;
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
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _listingRightSettingsSubscription;
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
  bool _rewardedAdSettingsLoaded = false;
  bool _rewardedAdsEnabled = true;
  final Set<String> _processedPurchaseIds = <String>{};
  String _rewardedAndroidAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  String _rewardedIosAdUnitId = 'ca-app-pub-3940256099942544/1712485313';
  int _rewardDailyMax = 3;
  int _rewardCooldownMinutes = 1;

  @override
  void initState() {
    super.initState();
    _draftOwnerUid = FirebaseAuth.instance.currentUser?.uid;
    _titleController.addListener(_scheduleDraftSave);
    _descriptionController.addListener(_scheduleDraftSave);
    _priceController.addListener(_scheduleDraftSave);
    _offerMinimumAmountController.addListener(_scheduleDraftSave);
    _neighborhoodController.addListener(_scheduleDraftSave);
    _checkUserLimit();
    _listenForListingRightChanges();
    _bootstrapListingRightMonetization();
    _loadListingDraft();
  }

  String _listingDraftKey(String uid) => 'listing_draft_$uid';

  void _scheduleDraftSave() {
    if (!_draftReady || _isApplyingDraft) return;
    _draftSaveTimer?.cancel();
    _draftSaveTimer = Timer(
      const Duration(milliseconds: 300),
      _persistListingDraft,
    );
  }

  Map<String, dynamic> _listingDraftData() {
    return {
      'title': _titleController.text,
      'description': _descriptionController.text,
      'price': _priceController.text,
      'city': _selectedCity,
      'district': _selectedDistrict,
      'neighborhood': _neighborhoodController.text,
      'selectedNeighborhood': _selectedNeighborhood,
      'categoryId': selectedCategoryId,
      'categoryName': selectedCategoryName,
      'categoryPath': fullCategoryPath,
      'categoryDisplayPath': fullCategoryDisplayPath,
      'autoAttributes': _autoAttributes,
      'featureTextValues': {
        for (final entry in _featureTextControllers.entries)
          entry.key: entry.value.text,
      },
      'featureDropdownValues': _featureDropdownValues,
      'offersEnabled': _offersEnabled,
      'tradeEnabled': _tradeEnabled,
      'cashOnDeliveryAvailable': _cashOnDeliveryAvailable,
      'offerValidityHours': _offerValidityHours,
      'offerMinimumPercent': _offerMinimumPercent,
      'offerMinimumAmount': _offerMinimumAmountController.text,
      'currentStep': _currentStep,
    };
  }

  bool _hasDraftContent(Map<String, dynamic> data) {
    return [
      data['title'],
      data['description'],
      data['price'],
      data['city'],
      data['district'],
      data['categoryId'],
    ].any((value) => value is String && value.trim().isNotEmpty);
  }

  Future<void> _persistListingDraft() async {
    if (!_draftReady || _isApplyingDraft) return;
    final uid = _draftOwnerUid;
    if (uid == null) return;

    try {
      final data = _listingDraftData();
      final preferences = await SharedPreferences.getInstance();
      if (_hasDraftContent(data)) {
        await preferences.setString(_listingDraftKey(uid), jsonEncode(data));
        if (mounted && !_hasLocalDraft) {
          setState(() => _hasLocalDraft = true);
        }
      } else {
        await preferences.remove(_listingDraftKey(uid));
        if (mounted && _hasLocalDraft) {
          setState(() => _hasLocalDraft = false);
        }
      }
    } catch (error) {
      debugPrint('İlan taslağı kaydedilemedi: $error');
      if (mounted && !_draftSaveErrorShown) {
        _draftSaveErrorShown = true;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('listing_draft_save_failed'))),
        );
      }
    }
  }

  Future<void> _loadListingDraft() async {
    final uid = _draftOwnerUid;
    if (uid == null) {
      _draftReady = true;
      return;
    }

    try {
      final preferences = await SharedPreferences.getInstance();
      final storedDraft = preferences.getString(_listingDraftKey(uid));
      if (storedDraft == null) {
        _draftReady = true;
        return;
      }

      final decoded = jsonDecode(storedDraft);
      if (decoded is! Map) {
        throw const FormatException('Invalid listing draft');
      }
      final draft = Map<String, dynamic>.from(decoded);
      if (!mounted) return;
      setState(() => _hasLocalDraft = true);

      final action = await showDialog<int>(
        context: context,
        builder: (dialogContext) => Dialog(
          insetPadding: const EdgeInsets.symmetric(
            horizontal: 20,
            vertical: 24,
          ),
          clipBehavior: Clip.antiAlias,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(24, 24, 24, 22),
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.primary, Color(0xFF3268E8)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: Colors.white,
                          size: 36,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        tr('listing_draft_available'),
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        tr('listing_draft_restore_prompt'),
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.info_outline_rounded,
                              color: AppColors.primary,
                              size: 20,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                tr('listing_draft_local_notice'),
                                style: LocalFonts.poppins(
                                  color: Colors.black87,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 18),
                      SizedBox(
                        height: 48,
                        child: ElevatedButton.icon(
                          onPressed: () => Navigator.pop(dialogContext, 1),
                          icon: const Icon(Icons.restore_rounded),
                          label: Text(tr('restore_draft')),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            elevation: 0,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            textStyle: LocalFonts.poppins(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextButton(
                              onPressed: () => Navigator.pop(dialogContext, 0),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.black54,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                              child: Text(tr('not_now')),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextButton.icon(
                              onPressed: () => Navigator.pop(dialogContext, 2),
                              icon: const Icon(
                                Icons.delete_outline_rounded,
                                size: 18,
                              ),
                              label: Text(tr('delete_draft')),
                              style: TextButton.styleFrom(
                                foregroundColor: Colors.red.shade700,
                                minimumSize: const Size.fromHeight(44),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
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
      );

      if (action == 1) {
        await _applyListingDraft(draft);
      } else if (action == 2) {
        await preferences.remove(_listingDraftKey(uid));
        if (mounted) setState(() => _hasLocalDraft = false);
      }
    } on FormatException catch (error) {
      debugPrint('İlan taslağı okunamadı: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('listing_draft_load_failed'))),
        );
      }
    } catch (error) {
      debugPrint('İlan taslağı yüklenemedi: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('listing_draft_load_failed'))),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _draftReady = true);
      } else {
        _draftReady = true;
      }
    }
  }

  Future<void> _applyListingDraft(Map<String, dynamic> draft) async {
    _isApplyingDraft = true;
    try {
      String draftString(String key) =>
          draft[key] is String ? draft[key] as String : '';

      _titleController.text = draftString('title');
      _descriptionController.text = draftString('description');
      _priceController.text = draftString('price');
      _neighborhoodController.text = draftString('neighborhood');
      _offerMinimumAmountController.text = draftString('offerMinimumAmount');

      final city = draftString('city');
      final district = draftString('district');
      _selectedCity = turkeyLocations.containsKey(city) ? city : null;
      final districts = _selectedCity == null
          ? null
          : turkeyLocations[_selectedCity!];
      _selectedDistrict = districts != null && districts.contains(district)
          ? district
          : null;
      _selectedNeighborhood = draft['selectedNeighborhood'] is String
          ? draft['selectedNeighborhood'] as String
          : null;

      selectedCategoryId = draft['categoryId'] is String
          ? draft['categoryId'] as String
          : null;
      selectedCategoryName = draftString('categoryName');
      fullCategoryPath = draftString('categoryPath');
      fullCategoryDisplayPath = draftString('categoryDisplayPath');
      _autoAttributes = draft['autoAttributes'] is Map
          ? Map<String, String>.from(draft['autoAttributes'] as Map)
          : {};
      _offersEnabled = draft['offersEnabled'] == true;
      _tradeEnabled = draft['tradeEnabled'] == true;
      _cashOnDeliveryAvailable = draft['cashOnDeliveryAvailable'] == true;
      _offerValidityHours = draft['offerValidityHours'] == 48 ? 48 : 24;
      _offerMinimumPercent = [70, 80, 90].contains(draft['offerMinimumPercent'])
          ? draft['offerMinimumPercent'] as int
          : 70;
      _currentStep = draft['currentStep'] == 2 ? 2 : 1;

      final categoryId = selectedCategoryId;
      if (categoryId != null && categoryId.isNotEmpty) {
        await _fetchCategoryFeatures(categoryId);
        final rawTextValues = draft['featureTextValues'];
        if (rawTextValues is Map) {
          for (final entry in rawTextValues.entries) {
            final controller = _featureTextControllers[entry.key.toString()];
            if (controller != null && entry.value is String) {
              controller.text = entry.value as String;
            }
          }
        }
        final rawDropdownValues = draft['featureDropdownValues'];
        if (rawDropdownValues is Map) {
          for (final entry in rawDropdownValues.entries) {
            final key = entry.key.toString();
            final value = entry.value;
            if (_featureDropdownValues.containsKey(key) && value is String) {
              for (final feature in _categoryFeatures) {
                if (feature['name'] == key &&
                    (feature['options'] as List).contains(value)) {
                  _featureDropdownValues[key] = value;
                  break;
                }
              }
            }
          }
        }
      }
      if (mounted) setState(() {});
    } finally {
      _isApplyingDraft = false;
    }
  }

  Future<void> _deleteListingDraft() async {
    final uid = _draftOwnerUid;
    if (uid == null) return;
    _draftSaveTimer?.cancel();
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(_listingDraftKey(uid));
      if (mounted) setState(() => _hasLocalDraft = false);
    } catch (error) {
      debugPrint('İlan taslağı silinemedi: $error');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('listing_draft_delete_failed'))),
        );
      }
    }
  }

  Future<void> _bootstrapListingRightMonetization() async {
    final settingsRef = FirebaseFirestore.instance
        .collection('settings')
        .doc('listing_rights');
    try {
      final settings = await settingsRef.get();
      _applyListingRightSettings(settings);
    } catch (error) {
      debugPrint('İlan hakkı ayarları alınamadı: $error');
      if (mounted) {
        setState(() {
          _rewardedAdsEnabled = false;
          _rewardedAdSettingsLoaded = true;
        });
      }
    }

    _listingRightSettingsSubscription = settingsRef.snapshots().listen(
      _applyListingRightSettings,
      onError: (Object error) {
        debugPrint('İlan hakkı ayarları dinlenemedi: $error');
        if (!mounted) return;
        setState(() {
          _rewardedAdsEnabled = false;
          _rewardedAdSettingsLoaded = true;
        });
      },
    );
    await _initListingRightPurchaseFlow();
  }

  void _applyListingRightSettings(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? <String, dynamic>{};
    final configuredPackages = data['paidPackages'];
    final rawPackages = configuredPackages is List
        ? configuredPackages.whereType<Map>().toList()
        : <Map>[];

    final grants = <String, int>{};
    final titles = <String, String>{};
    for (final raw in rawPackages) {
      final productId = (raw['productId'] ?? '').toString().trim();
      final grantValue = raw['grantCount'];
      final grantCount = grantValue is num ? grantValue.toInt() : 0;
      final title = (raw['title'] ?? '').toString().trim();
      if (productId.isEmpty || grantCount <= 0) continue;
      grants[productId] = grantCount;
      titles[productId] = title.isNotEmpty
          ? title
          : '$grantCount ${tr('listing_rights_unit')}';
    }

    if (!mounted) return;
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
      final dailyMax = data['rewardDailyMax'];
      _rewardDailyMax = dailyMax is num
          ? dailyMax.toInt()
          : int.tryParse(dailyMax?.toString() ?? '') ?? _rewardDailyMax;
      final cooldown = data['rewardCooldownMinutes'];
      final cooldownMinutes = cooldown is num
          ? cooldown.toInt()
          : int.tryParse(cooldown?.toString() ?? '');
      _rewardCooldownMinutes = cooldownMinutes != null && cooldownMinutes >= 1
          ? cooldownMinutes
          : 1;
      _rewardedAdsEnabled = data['rewardedAdsEnabled'] != false;
      _rewardedAdSettingsLoaded = true;
    });
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
      var entitlementGranted = false;
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
          entitlementGranted = true;
          _processedPurchaseIds.add(purchaseToken);
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

      if (entitlementGranted && purchase.pendingCompletePurchase) {
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
      autoConsume: false,
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

  Future<void> _cancelRewardChallenge(String? challengeId) async {
    if (challengeId == null || challengeId.isEmpty) return;
    try {
      await FirebaseFunctions.instanceFor(region: 'europe-west1')
          .httpsCallable('cancelListingRewardChallenge')
          .call({'challengeId': challengeId});
    } catch (error) {
      debugPrint('Tamamlanmayan reklam oturumu iptal edilemedi: $error');
    }
  }

  Future<void> _watchRewardedAdForListingRight() async {
    if (_isRewardLoading) return;
    if (!_rewardedAdsEnabled) return;
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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => _isRewardLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tr('login_required_create_listing'))),
        );
      }
      return;
    }

    String? activeChallengeId;
    try {
      await FirebaseAppCheck.instance.getToken(true);
      final challenge =
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('startListingRewardChallenge')
              .call({'adUnitId': adUnitId});
      final challengeData = challenge.data;
      final customData = challengeData is Map
          ? (challengeData['customData'] ?? challengeData['challengeId'])
                ?.toString()
                .trim()
          : null;
      if (customData == null || customData.isEmpty) {
        throw StateError('reward_verification_session_missing');
      }
      activeChallengeId = customData;

      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) async {
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

            try {
              await ad.setServerSideOptions(
                ServerSideVerificationOptions(
                  userId: user.uid,
                  customData: customData,
                ),
              );
              await ad.show(
                onUserEarnedReward: (ad, reward) {
                  hasEarnedReward = true;
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          tr('rewarded_ad_server_verification_pending'),
                          style: LocalFonts.poppins(),
                        ),
                      ),
                    );
                  }
                },
              );
            } catch (error) {
              ad.dispose();
              if (mounted) {
                setState(() => _isRewardLoading = false);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('${tr('ad_open_failed_prefix')}: $error'),
                  ),
                );
              }
            }
          },
          onAdFailedToLoad: (error) {
            unawaited(_cancelRewardChallenge(activeChallengeId));
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
    } on FirebaseFunctionsException catch (e) {
      await _cancelRewardChallenge(activeChallengeId);
      if (mounted) {
        setState(() => _isRewardLoading = false);
        final serverMessage = e.message ?? '';
        final message = e.code == 'resource-exhausted'
            ? serverMessage.toLowerCase().contains('gunluk')
                  ? tr(
                      'rewarded_ad_daily_limit_reached',
                    ).replaceFirst('%s', _rewardDailyMax.toString())
                  : tr(
                      'rewarded_ad_cooldown_wait',
                    ).replaceFirst('%s', _rewardCooldownMinutes.toString())
            : '${tr('rewarded_ad_assign_failed_prefix')} (${e.code}): ${serverMessage.isEmpty ? tr('unknown_server_error') : serverMessage}';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (error) {
      await _cancelRewardChallenge(activeChallengeId);
      if (mounted) {
        setState(() => _isRewardLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${tr('rewarded_ad_assign_failed_prefix')}: $error'),
          ),
        );
      }
    }
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
    _draftSaveTimer?.cancel();
    if (_draftReady && _draftOwnerUid != null) {
      unawaited(_persistListingDraft());
    }
    _userLimitSubscription?.cancel();
    _purchaseSubscription?.cancel();
    _listingRightSettingsSubscription?.cancel();
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
    final List<XFile> pickedFiles = await _picker.pickMultiImage(
      maxWidth: 1080,
      maxHeight: 1080,
      imageQuality: 85,
    );
    await _processPickedImages(pickedFiles);
  }

  Future<void> _takeListingPhoto() async {
    if (_optimizedImages.length >= 15) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('photo_limit_reached'))));
      return;
    }
    final photo = await Navigator.push<XFile>(
      context,
      MaterialPageRoute(builder: (_) => const ListingCameraScreen()),
    );
    if (photo != null && mounted) {
      await _processPickedImages([photo]);
    }
  }

  Future<void> _showPhotoSourceOptions() async {
    if (_isLoading) return;
    final source = await showModalBottomSheet<_ListingPhotoSource>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: Text(tr('take_photo')),
              onTap: () =>
                  Navigator.pop(sheetContext, _ListingPhotoSource.camera),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: Text(tr('choose_from_gallery')),
              onTap: () =>
                  Navigator.pop(sheetContext, _ListingPhotoSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (source == _ListingPhotoSource.camera) {
      await _takeListingPhoto();
    } else if (source == _ListingPhotoSource.gallery) {
      await _pickMultipleImages();
    }
  }

  Future<void> _processPickedImages(List<XFile> pickedFiles) async {
    if (pickedFiles.isNotEmpty) {
      setState(() {
        _isLoading = true;
        _loadingText = tr('processing_photos_wait');
      });

      final loopCount = pickedFiles.length > 15 ? 15 : pickedFiles.length;
      try {
        for (int i = 0; i < loopCount; i++) {
          if (_optimizedImages.length >= 15) break;

          setState(() {
            _loadingText = "${tr('processing_photos')} (${i + 1}/$loopCount)";
          });
          await Future.delayed(const Duration(milliseconds: 300));

          final originalBytes = await pickedFiles[i].readAsBytes();
          final watermarkedBytes = await _addWatermark(originalBytes);
          final compressedBytes = await _compressImage(watermarkedBytes);
          _optimizedImages.add(compressedBytes ?? watermarkedBytes);
        }
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
            _loadingText = "";
          });
        }
      }
      if (mounted) setState(() {});
    }
  }

  Future<void> _editDefectMarkers() async {
    final markers = await Navigator.push<List<DefectMarker>>(
      context,
      MaterialPageRoute(
        builder: (context) => DefectMarkerEditorScreen(
          images: _optimizedImages.map<ImageProvider>(MemoryImage.new).toList(),
          initialMarkers: _defectMarkers,
        ),
      ),
    );
    if (markers != null && mounted) {
      setState(() => _defectMarkers = markers);
    }
  }

  void _removePhotoAt(int index) {
    setState(() {
      _optimizedImages.removeAt(index);
      _defectMarkers = removeDefectMarkerImage(_defectMarkers, index);
    });
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
            _featureTextControllers[f]!.addListener(_scheduleDraftSave);
          } else if (f is Map) {
            String name = f['name'];
            List<String> options = List<String>.from(f['options'] ?? []);
            _categoryFeatures.add({'name': name, 'options': options});
            if (options.isEmpty) {
              _featureTextControllers[name] = TextEditingController();
              _featureTextControllers[name]!.addListener(_scheduleDraftSave);
            } else {
              _featureDropdownValues[name] = null;
            }
          }
        }
      });
    }
  }

  Future<void> _showCategoryPicker(
    String parentId,
    String currentPath, [
    String currentDisplayPath = "",
    Map<String, String>? currentAttributes,
  ]) async {
    var emptyCategorySubmitted = false;
    final action = await showModalBottomSheet<_CategoryPickerAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getCategoriesStream(parentId),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('categories_load_failed'),
                    textAlign: TextAlign.center,
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
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
              if (!emptyCategorySubmitted) {
                emptyCategorySubmitted = true;
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!context.mounted) return;
                  Navigator.pop(
                    context,
                    _CategoryPickerAction.selectCategory(
                      categoryId: parentId,
                      path: currentPath,
                      displayPath: currentDisplayPath,
                      attributes: currentAttributes ?? {},
                    ),
                  );
                });
              }
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
                            Navigator.pop(
                              context,
                              _CategoryPickerAction.openCategory(
                                parentId: grandParentId,
                                path: pathParts.join(' > '),
                                displayPath: displayParts.join(' > '),
                                attributes: currentAttributes ?? {},
                              ),
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
                              _CategoryPickerAction.selectCategory(
                                categoryId: clickedId,
                                path: newPath,
                                displayPath: newDisplayPath,
                                attributes: newAttributes,
                              ),
                            );
                          } else {
                            Navigator.pop(
                              context,
                              _CategoryPickerAction.openCategory(
                                parentId: clickedId,
                                path: newPath,
                                displayPath: newDisplayPath,
                                attributes: newAttributes,
                              ),
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
    if (!mounted || action == null) return;

    final categoryId = action.categoryId;
    if (categoryId != null) {
      setState(() {
        selectedCategoryId = categoryId;
        selectedCategoryName = action.path.split(' > ').last;
        fullCategoryPath = action.path;
        fullCategoryDisplayPath = action.displayPath;
        _autoAttributes = action.attributes;
        _showCategoryValidation = false;
      });
      _scheduleDraftSave();
      _fetchCategoryFeatures(categoryId);
      return;
    }

    await _showCategoryPicker(
      action.parentId,
      action.path,
      action.displayPath,
      action.attributes,
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
    if (_titleController.text.trim().length > 120) {
      missingFields.add(tr('listing_title'));
    }
    if (_descriptionController.text.trim().isEmpty) {
      missingFields.add(tr('description'));
    }
    final priceDigits = _priceController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (priceDigits.isEmpty || (int.tryParse(priceDigits) ?? 0) <= 0) {
      missingFields.add(tr('price_tl'));
    }
    if (_selectedCity?.trim().isEmpty ?? true) {
      missingFields.add(tr('city'));
    }
    if (_selectedDistrict?.trim().isEmpty ?? true) {
      missingFields.add(tr('district'));
    }

    return missingFields;
  }

  void _nextStep() {
    setState(() => _showStep1Validation = true);
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
    _scheduleDraftSave();
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
      _scheduleDraftSave();
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

  Future<_ListingPreviewAction?> _showListingPreview() {
    final price =
        double.tryParse(
          _priceController.text.replaceAll(RegExp(r'[^0-9]'), ''),
        ) ??
        0;
    final formattedPrice = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: '₺',
      decimalDigits: 0,
    ).format(price);

    return showDialog<_ListingPreviewAction>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(tr('listing_preview_title')),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: Image.memory(
                      _optimizedImages.first,
                      width: 88,
                      height: 88,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          tr('listing_cover_photo'),
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_optimizedImages.length} ${tr('listing_photos_count')}',
                          style: LocalFonts.poppins(fontSize: 12),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(
                            dialogContext,
                            _ListingPreviewAction.editListingInfo,
                          ),
                          child: Text(tr('edit_listing_details')),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const Divider(height: 24),
              Text(
                _titleController.text.trim(),
                style: LocalFonts.poppins(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                formattedPrice,
                style: LocalFonts.poppins(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${_selectedCity ?? ''}, ${_selectedDistrict ?? ''}',
                style: LocalFonts.poppins(fontSize: 12),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _ListingPreviewAction.editListingInfo,
                  ),
                  child: Text(tr('edit_listing_details')),
                ),
              ),
              const Divider(height: 16),
              Text(
                fullCategoryDisplayPath.isEmpty
                    ? selectedCategoryName
                    : fullCategoryDisplayPath,
                style: LocalFonts.poppins(),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => Navigator.pop(
                    dialogContext,
                    _ListingPreviewAction.editCategory,
                  ),
                  child: Text(tr('edit_category')),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ListingPreviewAction.cancel),
            child: Text(tr('cancel')),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.pop(dialogContext, _ListingPreviewAction.publish),
            child: Text(tr('confirm_publish')),
          ),
        ],
      ),
    );
  }

  Future<void> _submitListing() async {
    if (_getMissingRequiredFields().isNotEmpty) {
      setState(() => _currentStep = 1);
      _nextStep();
      return;
    }

    if (selectedCategoryId == null) {
      setState(() {
        _currentStep = 2;
        _showCategoryValidation = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_select_category'))));
      return;
    }

    final previewAction = await _showListingPreview();
    if (!mounted) return;
    if (previewAction == _ListingPreviewAction.editListingInfo) {
      setState(() => _currentStep = 1);
      _scheduleDraftSave();
      return;
    }
    if (previewAction == _ListingPreviewAction.editCategory) {
      setState(() => _currentStep = 2);
      return;
    }
    if (previewAction != _ListingPreviewAction.publish) return;

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
        final uploadedImageIndices = <int, int>{};
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
              uploadedImageIndices[i] = 0;
            } else {
              uploadedImageIndices[i] = additionalImages.length + 1;
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
              defectMarkers: _defectMarkers
                  .where(
                    (marker) =>
                        uploadedImageIndices.containsKey(marker.imageIndex),
                  )
                  .map(
                    (marker) => marker
                        .copyWith(
                          imageIndex: uploadedImageIndices[marker.imageIndex],
                        )
                        .toMap(),
                  )
                  .toList(),
              offerMinimumAmount: double.tryParse(
                _offerMinimumAmountController.text.trim().replaceAll(',', '.'),
              ),
              autoRenew: false,
              tradeEnabled: _tradeEnabled,
              cashOnDeliveryAvailable: _cashOnDeliveryAvailable,
            );
            if (success && mounted) {
              _draftReady = false;
              _draftSaveTimer?.cancel();
              await _deleteListingDraft();
              if (!mounted) return;
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
    if (_checkingLimit || !_draftReady) {
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
                    if (_rewardedAdSettingsLoaded && _rewardedAdsEnabled) ...[
                      TextButton.icon(
                        onPressed: _isRewardLoading
                            ? null
                            : _watchRewardedAdForListingRight,
                        icon: _isRewardLoading
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.ondemand_video_rounded),
                        label: Text(
                          tr('watch_ad_get_plus_one_right'),
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.w600,
                          ),
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
                onPressed: () {
                  setState(() => _currentStep = 1);
                  _scheduleDraftSave();
                },
              )
            : null,
      ),
      body: SafeArea(
        child: _isLoading
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildDraftNotice(),
                    _currentStep == 1 ? _buildStep1() : _buildStep2(),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildDraftNotice() {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.save_outlined, color: AppColors.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              tr(
                _hasLocalDraft
                    ? 'listing_draft_saved_notice'
                    : 'listing_draft_local_notice',
              ),
              style: LocalFonts.poppins(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStep1() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        GestureDetector(
          onTap: _showPhotoSourceOptions,
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
                  tr('add_listing_photos'),
                  style: LocalFonts.poppins(color: AppColors.primary),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('listing_photo_guidance'),
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(
                    color: Colors.grey[700],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (_showStep1Validation && _optimizedImages.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              tr('listing_photo_required'),
              style: LocalFonts.poppins(color: Colors.red, fontSize: 12),
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
                  _defectMarkers = reorderDefectMarkerImage(
                    _defectMarkers,
                    oldIndex,
                    newIndex,
                  );
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
                        onTap: () => _removePhotoAt(index),
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
        if (_optimizedImages.isNotEmpty)
          OutlinedButton.icon(
            onPressed: _editDefectMarkers,
            icon: const Icon(Icons.warning_amber_rounded),
            label: Text(
              '${tr('mark_photo_defects')} (${_defectMarkers.length})',
            ),
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _titleController,
          onChanged: (_) => setState(() {}),
          maxLength: 120,
          decoration: InputDecoration(
            labelText: tr('listing_title'),
            helperText: tr('listing_title_character_limit'),
            errorText:
                _showStep1Validation && _titleController.text.trim().isEmpty
                ? tr('field_required')
                : _titleController.text.trim().length > 120
                ? tr('listing_title_too_long')
                : null,
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
            errorText:
                _showStep1Validation && _priceController.text.trim().isEmpty
                ? tr('field_required')
                : _priceController.text.trim().isNotEmpty &&
                      (int.tryParse(
                                _priceController.text.replaceAll(
                                  RegExp(r'[^0-9]'),
                                  '',
                                ),
                              ) ??
                              0) <=
                          0
                ? tr('price_must_be_positive')
                : null,
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
                  onChanged: (value) {
                    setState(() => _offersEnabled = value);
                    _scheduleDraftSave();
                  },
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
                    onChanged: (value) {
                      setState(() => _offerValidityHours = value ?? 24);
                      _scheduleDraftSave();
                    },
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
                    onChanged: (value) {
                      setState(() => _offerMinimumPercent = value ?? 70);
                      _scheduleDraftSave();
                    },
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
            onChanged: (value) {
              setState(() => _tradeEnabled = value);
              _scheduleDraftSave();
            },
          ),
        ),
        Card(
          child: SwitchListTile(
            title: Text(tr('cash_on_delivery_option')),
            subtitle: Text(tr('cash_on_delivery_option_desc')),
            value: _cashOnDeliveryAvailable,
            onChanged: (value) {
              setState(() => _cashOnDeliveryAvailable = value);
              _scheduleDraftSave();
            },
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
                  errorText:
                      _showStep1Validation &&
                          (_selectedCity?.trim().isEmpty ?? true)
                      ? tr('field_required')
                      : null,
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
                  _scheduleDraftSave();
                },
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: DropdownButtonFormField<String>(
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: tr('district'),
                  errorText:
                      _showStep1Validation &&
                          (_selectedDistrict?.trim().isEmpty ?? true)
                      ? tr('field_required')
                      : null,
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
                  _scheduleDraftSave();
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
              _scheduleDraftSave();
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
            helperText: tr('description_character_count'),
            counterText: '${_descriptionController.text.length}',
            errorText:
                _showStep1Validation &&
                    _descriptionController.text.trim().isEmpty
                ? tr('field_required')
                : null,
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
          subtitle: _showCategoryValidation && selectedCategoryId == null
              ? Text(
                  tr('please_select_category'),
                  style: LocalFonts.poppins(color: Colors.red, fontSize: 12),
                )
              : null,
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
                        onChanged: (val) {
                          setState(() => _featureDropdownValues[name] = val);
                          _scheduleDraftSave();
                        },
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

enum _ListingPhotoSource { camera, gallery }

enum _ListingPreviewAction { cancel, publish, editListingInfo, editCategory }

class _CategoryPickerAction {
  final String parentId;
  final String path;
  final String displayPath;
  final Map<String, String> attributes;
  final String? categoryId;

  const _CategoryPickerAction.openCategory({
    required this.parentId,
    required this.path,
    required this.displayPath,
    required this.attributes,
  }) : categoryId = null;

  const _CategoryPickerAction.selectCategory({
    required this.path,
    required this.displayPath,
    required this.attributes,
    required this.categoryId,
  }) : parentId = '';
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
