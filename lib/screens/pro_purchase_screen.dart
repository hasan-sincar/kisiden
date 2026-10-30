import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import '../utils/translations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class ProPurchaseScreen extends StatefulWidget {
  const ProPurchaseScreen({super.key});

  @override
  State<ProPurchaseScreen> createState() => _ProPurchaseScreenState();
}

class _ProPurchaseScreenState extends State<ProPurchaseScreen> {
  final InAppPurchase _inAppPurchase = InAppPurchase.instance;
  late StreamSubscription<List<PurchaseDetails>> _subscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _userDocumentSubscription;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>?
  _rewardedAdSettingsSubscription;

  bool _isAvailable = false;
  List<ProductDetails> _products = [];
  bool _isLoading = true;
  bool _isPro = false;
  bool _isRewardLoading = false;
  bool _rewardedAdSettingsLoaded = false;
  bool _rewardedAdsEnabled = true;
  int? _remainingProDays;
  int? _proListingLimit;
  int _usedListings = 0;
  int _currentLimit = 10;
  String _rewardedAndroidAdUnitId = '';
  String _rewardedIosAdUnitId = '';
  int _rewardDailyMax = 3;
  int _rewardCooldownMinutes = 1;
  Object? _rewardedAdSettingsError;

  final List<String> _kProductIds = <String>[
    'pro_3_ay',
    'pro_6_ay',
    'pro_12_ay',
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
      onError: (error) {},
    );
    _initStoreInfo();
    _checkProStatus();
    _listenForAdminListingRights();
    _listenForRewardedAdSettings();
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
    _rewardedAdSettingsSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkProStatus() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (userDoc.exists && userDoc.data() != null) {
        Map<String, dynamic> data = userDoc.data() as Map<String, dynamic>;
        int limit = 10;
        final adminListingLimit = (data['adminListingLimit'] as num?)?.toInt();

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
              limit = proLimit > 0 ? proLimit : 10; // Paket limiti kullanılır
            }
            if (mounted) {
              setState(() {
                _isPro = true;
                _remainingProDays = endDateTime
                    .difference(DateTime.now())
                    .inDays;
                _proListingLimit = limit;
              });
            }
          }
        }

        QuerySnapshot listings = await FirebaseFirestore.instance
            .collection('listings')
            .where('sellerId', isEqualTo: user.uid)
            .where('status', whereIn: ['active', 'pending'])
            .get();

        if (mounted) {
          setState(() {
            _usedListings = listings.docs.length;
            _currentLimit = limit;
          });
        }
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

  void _listenForRewardedAdSettings() {
    _rewardedAdSettingsSubscription = FirebaseFirestore.instance
        .collection('settings')
        .doc('listing_rights')
        .snapshots()
        .listen(
          (snapshot) {
            final data = snapshot.data() ?? <String, dynamic>{};
            if (!mounted) return;
            setState(() {
              _rewardedAndroidAdUnitId = (data['rewardedAndroidAdUnitId'] ?? '')
                  .toString()
                  .trim();
              _rewardedIosAdUnitId = (data['rewardedIosAdUnitId'] ?? '')
                  .toString()
                  .trim();
              _rewardDailyMax =
                  (data['rewardDailyMax'] as num?)?.toInt() ?? _rewardDailyMax;
              final cooldown = data['rewardCooldownMinutes'];
              final cooldownMinutes = cooldown is num
                  ? cooldown.toInt()
                  : int.tryParse(cooldown?.toString() ?? '');
              _rewardCooldownMinutes =
                  cooldownMinutes != null && cooldownMinutes >= 1
                  ? cooldownMinutes
                  : 1;
              _rewardedAdsEnabled = data['rewardedAdsEnabled'] != false;
              _rewardedAdSettingsLoaded = true;
              _rewardedAdSettingsError = null;
            });
          },
          onError: (Object error) {
            if (!mounted) return;
            setState(() {
              _rewardedAdSettingsError = error;
              _rewardedAdsEnabled = false;
              _rewardedAdSettingsLoaded = true;
            });
          },
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
    if (_rewardedAdSettingsError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${tr('rewarded_ad_assign_failed_prefix')}: $_rewardedAdSettingsError',
          ),
        ),
      );
      return;
    }
    if (!_rewardedAdSettingsLoaded) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tr('login_required_create_listing'))),
      );
      return;
    }

    final adUnitId = _resolveRewardedAdUnitId();
    if (adUnitId.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('rewarded_ad_not_supported'))));
      return;
    }

    setState(() => _isRewardLoading = true);
    String? activeChallengeId;
    try {
      await FirebaseAppCheck.instance.getToken(true);
      final challenge =
          await FirebaseFunctions.instanceFor(region: 'europe-west1')
              .httpsCallable('startListingRewardChallenge')
              .call({'adUnitId': adUnitId});

      String? customData;
      final challengeData = challenge.data;
      if (challengeData is Map) {
        final value =
            challengeData['customData'] ?? challengeData['challengeId'];
        if (value is String && value.trim().isNotEmpty) {
          customData = value.trim();
        }
      }
      if (customData == null) {
        throw StateError('reward_verification_session_missing');
      }
      activeChallengeId = customData;

      RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            _showRewardedAd(ad, user.uid, customData);
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
    } on FirebaseFunctionsException catch (error) {
      await _cancelRewardChallenge(activeChallengeId);
      if (mounted) {
        setState(() => _isRewardLoading = false);
        final serverMessage = error.message ?? '';
        final message = error.code == 'resource-exhausted'
            ? serverMessage.toLowerCase().contains('gunluk')
                  ? tr(
                      'rewarded_ad_daily_limit_reached',
                    ).replaceFirst('%s', _rewardDailyMax.toString())
                  : serverMessage.toLowerCase().contains('reklam hakki')
                  ? tr(
                      'rewarded_ad_cooldown_wait',
                    ).replaceFirst('%s', _rewardCooldownMinutes.toString())
                  : tr('rewarded_ad_retry_short')
            : '${tr('rewarded_ad_assign_failed_prefix')} (${error.code}): ${serverMessage.isEmpty ? tr('unknown_server_error') : serverMessage}';
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

  Future<void> _showRewardedAd(
    RewardedAd ad,
    String userId,
    String? customData,
  ) async {
    var hasEarnedReward = false;
    ad.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        ad.dispose();
        if (mounted) {
          setState(() => _isRewardLoading = false);
          if (!hasEarnedReward) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(tr('watch_ad_until_end_for_reward'))),
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
              content: Text('${tr('ad_open_failed_prefix')}: ${error.message}'),
            ),
          );
        }
      },
    );

    try {
      await ad.setServerSideOptions(
        ServerSideVerificationOptions(userId: userId, customData: customData),
      );
      await ad.show(
        onUserEarnedReward: (ad, reward) {
          hasEarnedReward = true;
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(tr('rewarded_ad_server_verification_pending')),
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
          SnackBar(content: Text('${tr('ad_open_failed_prefix')}: $error')),
        );
      }
    }
  }

  Future<void> _listenToPurchaseUpdated(
    List<PurchaseDetails> purchaseDetailsList,
  ) async {
    for (var purchaseDetails in purchaseDetailsList) {
      var entitlementGranted = false;
      if (purchaseDetails.status == PurchaseStatus.pending) {
        // Satın alma bekleniyor
      } else {
        if (purchaseDetails.status == PurchaseStatus.error) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(tr('purchase_cancelled_or_error'))),
          );
        } else if (purchaseDetails.status == PurchaseStatus.purchased ||
            purchaseDetails.status == PurchaseStatus.restored) {
          final product = _products.cast<ProductDetails?>().firstWhere(
            (p) => p?.id == purchaseDetails.productID,
            orElse: () => null,
          );
          if (product == null) return; // Ürün detayı bulunamazsa işlemi durdur
          try {
            await FirebaseFunctions.instanceFor(
              region: 'europe-west1',
            ).httpsCallable('activateProPurchase').call({
              'productId': purchaseDetails.productID,
              'purchaseId': purchaseDetails.purchaseID,
              'purchasePlatform': purchaseDetails.verificationData.source,
              'verificationData': {
                'source': purchaseDetails.verificationData.source,
                'serverVerificationData':
                    purchaseDetails.verificationData.serverVerificationData,
                'localVerificationData':
                    purchaseDetails.verificationData.localVerificationData,
              },
            });
            entitlementGranted = true;
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text(tr('pro_success_msg'))));
              Navigator.pop(context);
            }
          } catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(
                context,
              ).showSnackBar(SnackBar(content: Text('${tr('error')}: $e')));
            }
          }
        }
        if (entitlementGranted && purchaseDetails.pendingCompletePurchase) {
          await _inAppPurchase.completePurchase(purchaseDetails);
        }
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
    _inAppPurchase.buyNonConsumable(purchaseParam: purchaseParam);
  }

  @override
  Widget build(BuildContext context) {
    int remaining = _currentLimit - _usedListings;
    if (remaining < 0) remaining = 0;
    double progress = _currentLimit > 0 ? (_usedListings / _currentLimit) : 0;
    if (progress > 1.0) progress = 1.0;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FC),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildStoreHeader(),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_isPro && _remainingProDays != null) ...[
                          _buildActiveProCard(),
                          const SizedBox(height: 24),
                        ],
                        _buildListingUsageCard(remaining, progress),
                        const SizedBox(height: 30),
                        _buildSectionHeading(tr('privileges')),
                        const SizedBox(height: 14),
                        _buildBenefitsGrid(),
                        const SizedBox(height: 30),
                        _buildSectionHeading(tr('package_options')),
                        const SizedBox(height: 14),
                        _buildPackageCard('pro_3_ay', tr('buy_pro_3_months')),
                        const SizedBox(height: 12),
                        _buildPackageCard(
                          'pro_6_ay',
                          tr('buy_pro_6_months'),
                          isPopular: true,
                        ),
                        const SizedBox(height: 12),
                        _buildPackageCard('pro_12_ay', tr('buy_pro_12_months')),
                        const SizedBox(height: 28),
                        if (_rewardedAdSettingsLoaded &&
                            _rewardedAdsEnabled) ...[
                          _buildRewardedAdCard(),
                          const SizedBox(height: 22),
                        ],
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 16,
                              color: Colors.blueGrey.shade400,
                            ),
                            const SizedBox(width: 7),
                            Flexible(
                              child: Text(
                                tr('purchase_secure_info'),
                                textAlign: TextAlign.center,
                                style: LocalFonts.poppins(
                                  fontSize: 11,
                                  color: Colors.blueGrey.shade500,
                                  height: 1.4,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildStoreHeader() {
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 8,
        20,
        28,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF142C67), Color(0xFF0757C8), Color(0xFF2787F5)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(30)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: () => Navigator.pop(context),
                icon: const Icon(
                  Icons.arrow_back_ios_new_rounded,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              Expanded(
                child: Text(
                  tr('pro_store'),
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            height: 66,
            width: 66,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.14),
              shape: BoxShape.circle,
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.28),
                width: 1.2,
              ),
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 37,
              color: Color(0xFFFFD76A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            tr('premium_privileges'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(
              fontSize: 23,
              height: 1.25,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tr('pro_store'),
            textAlign: TextAlign.center,
            style: LocalFonts.poppins(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.82),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeading(String title) {
    return Text(
      title,
      style: LocalFonts.poppins(
        fontSize: 19,
        fontWeight: FontWeight.w700,
        color: const Color(0xFF17233C),
      ),
    );
  }

  Widget _buildListingUsageCard(int remaining, double progress) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFE7ECF5)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF193B7A).withValues(alpha: 0.06),
            blurRadius: 20,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                height: 42,
                width: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF1FF),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: const Icon(
                  Icons.inventory_2_outlined,
                  color: Color(0xFF1455C0),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tr('used_listings'),
                  style: LocalFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF536078),
                  ),
                ),
              ),
              Text(
                '$_usedListings / $_currentLimit',
                style: LocalFonts.poppins(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF17233C),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: const Color(0xFFE9EDF5),
              color: remaining == 0
                  ? const Color(0xFFE45A63)
                  : const Color(0xFF246BDF),
            ),
          ),
          const SizedBox(height: 11),
          Text(
            remaining == 0
                ? tr('listing_limit_full_upgrade')
                : tr(
                    'remaining_free_listings',
                  ).replaceAll('%s', remaining.toString()),
            style: LocalFonts.poppins(
              fontSize: 12,
              height: 1.4,
              color: remaining == 0
                  ? const Color(0xFFC63E4C)
                  : const Color(0xFF68758B),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveProCard() {
    final currentPackage = _proListingLimit == 25
        ? tr('pro_3_months')
        : _proListingLimit == 60
        ? tr('pro_6_months')
        : _proListingLimit == 250
        ? tr('pro_12_months')
        : tr('pro_package');

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF098A78), Color(0xFF21A886)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF07836F).withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.verified_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  tr('pro_store_active'),
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              const Icon(Icons.auto_awesome_rounded, color: Color(0xFFFFE38A)),
            ],
          ),
          const SizedBox(height: 16),
          _buildActivePlanDetail(tr('current_package'), currentPackage),
          const SizedBox(height: 9),
          _buildActivePlanDetail(
            tr('remaining_time'),
            '$_remainingProDays ${tr('days')}',
          ),
        ],
      ),
    );
  }

  Widget _buildActivePlanDetail(String label, String value) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: LocalFonts.poppins(
              color: Colors.white.withValues(alpha: 0.78),
              fontSize: 12,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: LocalFonts.poppins(
              color: Colors.white,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildBenefitsGrid() {
    final benefits = <(IconData, Color, String)>[
      (
        Icons.rocket_launch_rounded,
        const Color(0xFF7856D8),
        tr('higher_listing_limits'),
      ),
      (
        Icons.auto_awesome_rounded,
        const Color(0xFFEF8B32),
        tr('pro_gift_showcase'),
      ),
      (
        Icons.workspace_premium_rounded,
        const Color(0xFFD39A18),
        tr('pro_badge_profile'),
      ),
      (
        Icons.support_agent_rounded,
        const Color(0xFF2878CE),
        tr('priority_support'),
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = (constraints.maxWidth - 12) / 2;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: benefits
              .map(
                (benefit) => SizedBox(
                  width: cardWidth,
                  child: _buildBenefitCard(benefit.$1, benefit.$2, benefit.$3),
                ),
              )
              .toList(),
        );
      },
    );
  }

  Widget _buildBenefitCard(IconData icon, Color color, String text) {
    return Container(
      constraints: const BoxConstraints(minHeight: 116),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFE7ECF5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            height: 37,
            width: 37,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 21),
          ),
          const SizedBox(height: 11),
          Text(
            text,
            style: LocalFonts.poppins(
              fontSize: 11.5,
              height: 1.35,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF27334A),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRewardedAdCard() {
    final canWatchAd = !_isRewardLoading && _rewardedAdSettingsLoaded;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD8E5FF)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                height: 44,
                width: 44,
                decoration: BoxDecoration(
                  color: const Color(0xFFDCE8FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.ondemand_video_rounded,
                  color: Color(0xFF245EC4),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('watch_ad_get_plus_one_right'),
                      style: LocalFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF173B80),
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${tr('rewarded_ad_daily_limit_prefix')}$_rewardDailyMax ${tr('rewarded_ad_daily_limit_middle')}$_rewardCooldownMinutes ${tr('rewarded_ad_daily_limit_suffix')}',
                      style: LocalFonts.poppins(
                        fontSize: 11,
                        height: 1.4,
                        color: const Color(0xFF64728A),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: canWatchAd ? _watchRewardedAdForListingRight : null,
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF245EC4),
                disabledBackgroundColor: const Color(0xFFB9C8E2),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(13),
                ),
              ),
              icon: _isRewardLoading
                  ? const SizedBox(
                      height: 17,
                      width: 17,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.play_circle_outline_rounded, size: 20),
              label: Text(
                tr('watch_ad_get_plus_one_right'),
                style: LocalFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPackageCard(
    String productId,
    String title, {
    bool isPopular = false,
  }) {
    final product = _products.cast<ProductDetails?>().firstWhere(
      (item) => item?.id == productId,
      orElse: () => null,
    );

    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(19),
      child: InkWell(
        borderRadius: BorderRadius.circular(19),
        onTap: product == null ? null : () => _buyProduct(productId),
        child: Container(
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(19),
            border: Border.all(
              color: isPopular
                  ? const Color(0xFFF1C34B)
                  : const Color(0xFFE5EAF2),
              width: isPopular ? 1.6 : 1,
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF193B7A).withValues(alpha: 0.045),
                blurRadius: 14,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: isPopular
                      ? const Color(0xFFFFF4D5)
                      : const Color(0xFFEEF3FC),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.workspace_premium_rounded,
                  color: isPopular
                      ? const Color(0xFFC88D08)
                      : const Color(0xFF4169AA),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (isPopular) ...[
                      Container(
                        margin: const EdgeInsets.only(bottom: 5),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFFF0C2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          tr('best_seller'),
                          style: LocalFonts.poppins(
                            fontSize: 8,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF9B6A00),
                          ),
                        ),
                      ),
                    ],
                    Text(
                      title,
                      style: LocalFonts.poppins(
                        fontSize: 13,
                        height: 1.3,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF202C43),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      product?.price ?? tr('product_not_found'),
                      style: LocalFonts.poppins(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: product == null
                            ? const Color(0xFF8792A4)
                            : const Color(0xFF245EC4),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                product == null
                    ? Icons.lock_outline_rounded
                    : Icons.arrow_forward_rounded,
                color: product == null
                    ? const Color(0xFF9AA4B3)
                    : const Color(0xFF245EC4),
                size: 21,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
