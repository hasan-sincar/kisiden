import 'dart:async';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'dart:ui'; // YENİ: Buzlu cam efekti için eklendi
import 'package:flutter/foundation.dart'; // Web ve platform kontrolü için eklendi
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cached_network_image/cached_network_image.dart'; // YENİ: Resimlerin önbelleğe alınması için
import '../services/database_service.dart';
import '../utils/turkey_locations.dart';
import 'add_listing_screen.dart';
import 'listing_detail_screen.dart';
import 'inbox_screen.dart';
import 'profile_screen.dart';
import 'showcase_list_screen.dart';
import 'notifications_screen.dart';
import 'all_listings_screen.dart';
import 'nearby_listings_screen.dart';
import 'viewed_listings_screen.dart';
import 'urgent_listings_screen.dart';
import 'search_alarms_screen.dart';
import 'favorites_screen.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';
import '../utils/auth_gate.dart';
import '../utils/home_widget_sync.dart';
import '../main.dart'; // YENİ: pendingDeepLink'e erişmek için
import '../widgets/app_download_banner.dart'; // YENİ: Akıllı Uygulama İndirme Banner'ı
import '../services/viewed_listings_service.dart';

part 'home_screen_controller.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen>
    with SingleTickerProviderStateMixin {
  Widget _buildNearbyListingsPreview(List<String> hiddenUsers) {
    final position = _userPosition;
    if (position == null) return const SizedBox();

    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'active')
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const SizedBox();
        final nearbyDocs = snapshot.data!.docs.where((doc) {
          final data = doc.data() as Map<String, dynamic>;
          final lat = (data['lat'] as num?)?.toDouble();
          final lng = (data['lng'] as num?)?.toDouble();
          if (lat == null ||
              lng == null ||
              hiddenUsers.contains(data['sellerId'])) {
            return false;
          }
          return Geolocator.distanceBetween(
                position.latitude,
                position.longitude,
                lat,
                lng,
              ) <=
              20000;
        }).toList();

        nearbyDocs.sort((a, b) {
          final aData = a.data() as Map<String, dynamic>;
          final bData = b.data() as Map<String, dynamic>;
          final aDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            (aData['lat'] as num).toDouble(),
            (aData['lng'] as num).toDouble(),
          );
          final bDistance = Geolocator.distanceBetween(
            position.latitude,
            position.longitude,
            (bData['lat'] as num).toDouble(),
            (bData['lng'] as num).toDouble(),
          );
          return aDistance.compareTo(bDistance);
        });

        if (nearbyDocs.isEmpty) return const SizedBox();
        final previewDocs = nearbyDocs.take(10).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Text(
                    tr('nearby_listings'),
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 17,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            const NearbyListingsScreen(initialDistance: 20),
                      ),
                    ),
                    child: Text(
                      tr('see_all'),
                      style: LocalFonts.poppins(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(
              height: 215,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: previewDocs.length,
                itemBuilder: (context, index) {
                  final doc = previewDocs[index];
                  final data = doc.data() as Map<String, dynamic>;
                  final image = data['imageUrl']?.toString() ?? '';
                  final price =
                      data['price']?.toString().split('.').first ?? '';
                  final distance = Geolocator.distanceBetween(
                    position.latitude,
                    position.longitude,
                    (data['lat'] as num).toDouble(),
                    (data['lng'] as num).toDouble(),
                  );
                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            ListingDetailScreen(data: data, listingId: doc.id),
                      ),
                    ),
                    child: Container(
                      width: 155,
                      margin: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ClipRRect(
                              borderRadius: const BorderRadius.vertical(
                                top: Radius.circular(16),
                              ),
                              child: image.isEmpty
                                  ? const Center(
                                      child: Icon(Icons.image_outlined),
                                    )
                                  : CachedNetworkImage(
                                      imageUrl: image,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                    ),
                            ),
                          ),
                          Padding(
                            padding: const EdgeInsets.fromLTRB(10, 7, 10, 8),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '$price TL',
                                  style: LocalFonts.poppins(
                                    color: AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  data['title']?.toString() ?? '',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: LocalFonts.poppins(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  '${(distance / 1000).toStringAsFixed(1)} km',
                                  style: LocalFonts.poppins(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildRecentlyViewedSection() {
    return ValueListenableBuilder<int>(
      valueListenable: ViewedListingsService.revision,
      builder: (context, _, __) => FutureBuilder<List<Map<String, dynamic>>>(
        future: ViewedListingsService.load(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) return const SizedBox();
          final preview = entries.take(5).toList();
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tr('recently_viewed'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 17,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    TextButton(
                      style: TextButton.styleFrom(
                        minimumSize: Size.zero,
                        padding: EdgeInsets.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        visualDensity: VisualDensity.compact,
                      ),
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const ViewedListingsScreen(),
                        ),
                      ),
                      child: Text(
                        tr('see_all'),
                        style: LocalFonts.poppins(
                          color: AppColors.primary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ...preview.map((entry) {
                final data = Map<String, dynamic>.from(entry['data'] as Map);
                final image = data['imageUrl']?.toString() ?? '';
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 4,
                  ),
                  child: ListTile(
                    leading: image.isEmpty
                        ? const Icon(Icons.image_outlined)
                        : ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              image,
                              width: 56,
                              height: 56,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) =>
                                  const Icon(Icons.broken_image_outlined),
                            ),
                          ),
                    title: Text(
                      data['title']?.toString() ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LocalFonts.poppins(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      '${data['price'] ?? ''} • ${data['city'] ?? ''}',
                      style: LocalFonts.poppins(color: Colors.grey[600]),
                    ),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ListingDetailScreen(
                          data: data,
                          listingId: entry['id'].toString(),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ],
          );
        },
      ),
    );
  }

  String _listingLocationText(Map<String, dynamic> data) {
    final city = data['city'];
    final district = data['district'];
    if (city == null || district == null) return '';
    final features = data['features'];
    final neighborhood = features is Map
        ? features['Mahalle']?.toString().trim()
        : null;
    final base = '${_formatLocation(city)}, ${_formatLocation(district)}';
    return neighborhood == null || neighborhood.isEmpty
        ? base
        : '$base, ${_formatLocation(neighborhood)}';
  }

  void updateState(VoidCallback callback) {
    if (mounted) setState(callback);
  }

  String _currentParentId = "";
  String _currentParentName = "";
  String _filterCategoryName = "";
  String _currentParentDisplayName = "";
  String _filterCategoryDisplayName = "";
  String _sortBy = 'date_desc';
  double _distance = 30.0;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocusNode = FocusNode();
  String _searchText = "";
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();
  String? _filterNeighborhood;

  String? _filterCity;
  String? _filterDistrict;

  double? _parsePrice(dynamic value) {
    if (value is num) return value.toDouble();
    final normalized = value
        ?.toString()
        .replaceAll(RegExp(r'[^0-9,.-]'), '')
        .replaceAll(',', '.');
    return normalized == null ? null : double.tryParse(normalized);
  }

  final int _lastUnreadCount = 0;
  int _lastNotifCount = 0;
  bool _isFirstNotifLoad = true;
  Position? _userPosition;

  final ScrollController _scrollController = ScrollController();
  int _documentLimit = 20;
  bool _isLoadingMore = false;
  bool _isFiltering = false; // YENİ: Filtreleme animasyonu için state
  bool _isFilterModalOpening = false;
  bool _isCategoryPickerOpening = false;
  bool _isHandlingBack = false;
  QuerySnapshot? _cachedListingsSnapshot;
  late final AnimationController _urgentPulseController;
  late final Animation<double> _urgentPulseScale;

  // Kategori Özellikleri (Filtreleme için)
  final List<Map<String, dynamic>> _categoryFeatures = [];
  final Map<String, String?> _featureDropdownValues = {};

  // SESLİ ARAMA DEĞİŞKENLERİ
  final stt.SpeechToText _speechToText = stt.SpeechToText();
  bool _isListening = false;

  Future<void> _handlePushNavigation(String? type, String? targetId) async {
    if (!mounted || type == null) return;

    if (type == 'listing' && targetId != null && targetId.isNotEmpty) {
      var doc = await FirebaseFirestore.instance
          .collection('listings')
          .doc(targetId)
          .get();
      if (doc.exists && mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ListingDetailScreen(
              data: doc.data() as Map<String, dynamic>,
              listingId: targetId,
            ),
          ),
        );
      }
      return;
    }

    if (type == 'chat') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const InboxScreen()),
      );
      return;
    }

    if (type == 'category_promo' && targetId != null && targetId.isNotEmpty) {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => AllListingsScreen(
            initialFilters: {'categoryName': targetId},
            customTitle: '$targetId ${tr('listings_suffix')}',
          ),
        ),
      );
      return;
    }

    if (type == 'campaign' || type == 'announcement') {
      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const NotificationsScreen()),
      );
      return;
    }
  }

  @override
  void initState() {
    super.initState();
    _urgentPulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1150),
    )..repeat();
    _urgentPulseScale =
        TweenSequence<double>([
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.0,
              end: 1.24,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 10,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.24,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 10,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 7),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.0,
              end: 1.16,
            ).chain(CurveTween(curve: Curves.easeOut)),
            weight: 9,
          ),
          TweenSequenceItem(
            tween: Tween<double>(
              begin: 1.16,
              end: 1.0,
            ).chain(CurveTween(curve: Curves.easeIn)),
            weight: 9,
          ),
          TweenSequenceItem(tween: ConstantTween<double>(1.0), weight: 55),
        ]).animate(
          CurvedAnimation(parent: _urgentPulseController, curve: Curves.linear),
        );
    _currentParentName = tr('all');
    _filterCategoryName = tr('all');
    _currentParentDisplayName = tr('all');
    _filterCategoryDisplayName = tr('all');
    _loadPreferences();
    _initSpeech();

    _scrollController.addListener(() {
      if (_scrollController.position.pixels >=
          _scrollController.position.maxScrollExtent - 200) {
        if (!_isLoadingMore) {
          setState(() {
            _isLoadingMore = true;
            _documentLimit += 20;
          });
          Future.delayed(const Duration(milliseconds: 1000), () {
            if (mounted) setState(() => _isLoadingMore = false);
          });
        }
      }
    });

    // PUSH NOTIFICATION CLICK ACTIONS
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) async {
      String? type = message.data['type'];
      String? targetId = message.data['targetId'];
      await _handlePushNavigation(type, targetId);
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) async {
      if (message != null) {
        String? type = message.data['type'];
        String? targetId = message.data['targetId'];
        await _handlePushNavigation(type, targetId);
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      isAppReady = true; // Uygulamanın açılışı tamamlandı
      _getUserLocation(); // YENİ: Ekran çizildikten sonra konum izni ister, böylece açılışta garanti çıkar
      _checkPendingDeepLink();
    });
  }

  @override
  void dispose() {
    _urgentPulseController.dispose();
    _searchController.dispose();
    _searchFocusNode.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _neighborhoodController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _dismissSearchFocus() {
    _searchFocusNode.unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
  }

  bool _hasActiveFilters() {
    return _searchText.trim().isNotEmpty ||
        _filterCategoryName != tr('all') ||
        _filterCity != null ||
        _filterDistrict != null ||
        (_filterNeighborhood?.trim().isNotEmpty ?? false) ||
        _minPriceController.text.trim().isNotEmpty ||
        _maxPriceController.text.trim().isNotEmpty ||
        _distance < 30.0 ||
        _featureDropdownValues.values.any(
          (value) => value != null && value.isNotEmpty,
        );
  }

  Future<void> _resetHomeFilters() async {
    if (!mounted) return;
    _dismissSearchFocus();
    setState(() {
      _searchController.clear();
      _searchText = '';
      _filterCategoryName = tr('all');
      _filterCategoryDisplayName = tr('all');
      _currentParentId = '';
      _currentParentName = tr('all');
      _currentParentDisplayName = tr('all');
      _filterCity = null;
      _filterDistrict = null;
      _filterNeighborhood = null;
      _neighborhoodController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _distance = 30.0;
      for (final key in _featureDropdownValues.keys) {
        _featureDropdownValues[key] = null;
      }
    });
    await _savePreferences();
    if (!mounted) return;
    await _fetchCategoryFeatures('');
  }

  Widget _buildUrgentNavIcon({required bool active}) {
    return AnimatedBuilder(
      animation: _urgentPulseController,
      builder: (context, child) {
        final double beatStrength =
            (((_urgentPulseScale.value - 1.0) / 0.24).clamp(
              0.0,
              1.0,
            )).toDouble();
        final double passivePulse =
            1.0 + ((_urgentPulseScale.value - 1.0) * 0.88);
        return Transform.scale(
          scale: active ? _urgentPulseScale.value : passivePulse,
          child: Icon(
            active
                ? Icons.notifications_active_rounded
                : Icons.notifications_active_outlined,
            size: active ? 26 : 25,
            color: const Color(0xFFFF5A1F),
            shadows: [
              Shadow(
                color: const Color(0xFFFF5A1F).withValues(
                  alpha: active
                      ? (0.42 + (beatStrength * 0.36))
                      : (0.24 + (beatStrength * 0.22)),
                ),
                blurRadius: active
                    ? (11 + (beatStrength * 8))
                    : (7 + (beatStrength * 5)),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final double screenWidth = MediaQuery.sizeOf(
      context,
    ).width; // YENİ: Klavye açıldığında tüm sayfanın saniyede 60 kez baştan çizilmesini ve kilitlenmesini engeller.
    final int crossAxisCount = screenWidth > 1200
        ? 5
        : (screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2));
    final double gridAspectRatio = screenWidth > 600 ? 0.8 : 0.72;

    // --- YENİ: PAGINATION VE FİLTRELEME SORGUSU ---
    Query _buildListingsQuery() {
      final bool isSearchMode = _searchText.trim().isNotEmpty;
      final String rawSearch = _searchText.trim();
      final bool hasCategoryFilter =
          !isSearchMode && _filterCategoryName != tr('all');
      final bool hasLocationFilter =
          !isSearchMode &&
          (_filterCity != null ||
              _filterDistrict != null ||
              (_filterNeighborhood?.trim().isNotEmpty ?? false));
      final bool isExactListingNoSearch = RegExp(
        r'^\d{8,}$',
      ).hasMatch(rawSearch);

      if (isExactListingNoSearch) {
        return FirebaseFirestore.instance
            .collection('listings')
            .where('status', isEqualTo: 'active')
            .where('listingNo', isEqualTo: rawSearch)
            .limit(20);
      }

      Query query = FirebaseFirestore.instance
          .collection('listings')
          .where('status', isEqualTo: 'active');

      // Sıralama
      // Fiyat sıralaması seçildiyse daima fiyat alanına göre sırala.
      // Firestore'da price aralığı varken de aynı alan üzerinden orderBy güvenlidir.
      if (_sortBy == 'price_asc' || _sortBy == 'price_desc') {
        query = query.orderBy('price', descending: _sortBy == 'price_desc');
      } else {
        query = query.orderBy('createdAt', descending: _sortBy != 'date_asc');
      }

      // Arama sırasında sonuç kaçırmamak için daha geniş pencere getir.
      final int effectiveLimit =
          (isSearchMode ||
              hasCategoryFilter ||
              hasLocationFilter ||
              _distance < 30.0 ||
              _minPriceController.text.trim().isNotEmpty ||
              _maxPriceController.text.trim().isNotEmpty)
          ? 1000
          : _documentLimit;
      return query.limit(effectiveLimit);
    }

    return StreamBuilder<DocumentSnapshot>(
      stream: AuthGate.isRegistered && currentUser != null
          ? FirebaseFirestore.instance
                .collection('users')
                .doc(currentUser.uid)
                .snapshots()
          : const Stream<DocumentSnapshot>.empty(),
      builder: (context, userSnap) {
        List<String> hiddenUsers = [];
        if (userSnap.hasData && userSnap.data!.exists) {
          var userData = userSnap.data!.data() as Map<String, dynamic>;
          hiddenUsers = [
            ...List<String>.from(userData['blockedUsers'] ?? []),
            ...List<String>.from(userData['blockedBy'] ?? []),
          ];
          if (userData['bannedUntil'] != null &&
              (userData['bannedUntil'] as Timestamp).toDate().isAfter(
                DateTime.now(),
              )) {
            return Scaffold(
              body: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.block, size: 80, color: Colors.red),
                      const SizedBox(height: 16),
                      Text(
                        tr('account_suspended'),
                        style: LocalFonts.poppins(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }
        }

        return PopScope(
          canPop:
              !_isHandlingBack &&
              !_hasActiveFilters() &&
              !_searchFocusNode.hasFocus &&
              FocusManager.instance.primaryFocus == null,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;

            if (_hasActiveFilters()) {
              if (_isHandlingBack) return;
              setState(() => _isHandlingBack = true);
              _resetHomeFilters().whenComplete(() {
                if (mounted) {
                  setState(() => _isHandlingBack = false);
                }
              });
              return;
            }

            // Açık klavyeyi kapatmadan ana sayfadan çıkılmasına izin verme.
            if (_searchFocusNode.hasFocus ||
                FocusManager.instance.primaryFocus != null) {
              _dismissSearchFocus();
            }
          },
          child: Scaffold(
            resizeToAvoidBottomInset:
                false, // YENİ: Anasayfada arama yaparken klavyenin ekranı yukarı doğru sıkıştırmasını iptal eder, klavye anında üste çıkar.
            extendBody: true,
            backgroundColor: const Color(0xFFF8F9FA),
            appBar: AppBar(
              backgroundColor: Colors.white,
              elevation: 0.5,
              centerTitle: false,
              title: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tr('app_name'),
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                      fontSize: 24,
                    ),
                  ),
                  Text(
                    tr('slogan'),
                    style: LocalFonts.poppins(
                      fontSize: 11,
                      color: Colors.grey[500],
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              actions: [
                IconButton(
                  icon: const Icon(Icons.sort_rounded, color: Colors.black87),
                  onPressed: _showSortModal,
                ),
                IconButton(
                  icon: const Icon(Icons.tune_rounded, color: Colors.black87),
                  onPressed: _showFilterModal,
                ),
                if (AuthGate.isRegistered && currentUser != null)
                  StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('users')
                        .doc(currentUser.uid)
                        .collection('notifications')
                        .where('isRead', isEqualTo: false)
                        .snapshots(),
                    builder: (context, notifSnap) {
                      int notifCount = notifSnap.hasData
                          ? notifSnap.data!.docs.length
                          : 0;
                      HomeWidgetSync.syncUnreadNotifications(notifCount);
                      if (!_isFirstNotifLoad && notifCount > _lastNotifCount)
                        _playSound();
                      if (notifSnap.hasData) _isFirstNotifLoad = false;
                      _lastNotifCount = notifCount;
                      return IconButton(
                        icon: Badge(
                          isLabelVisible: notifCount > 0,
                          label: Text(notifCount.toString()),
                          child: const Icon(
                            Icons.notifications_none_rounded,
                            color: Colors.black87,
                          ),
                        ),
                        onPressed: () {
                          FocusScope.of(context).unfocus();
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const NotificationsScreen(),
                            ),
                          );
                        },
                      );
                    },
                  )
                else
                  Builder(
                    builder: (context) {
                      HomeWidgetSync.syncUnreadNotifications(0);
                      return IconButton(
                        icon: const Icon(
                          Icons.notifications_none_rounded,
                          color: Colors.black87,
                        ),
                        onPressed: () => AuthGate.requireRegisteredUser(
                          context,
                          message: tr('login_required_notifications'),
                        ),
                      );
                    },
                  ),
                const SizedBox(width: 8),
              ],
            ),
            body: SafeArea(
              child: Stack(
                children: [
                  RefreshIndicator(
                    color: AppColors.primary, // Yenileme animasyonunun rengi
                    backgroundColor: Colors.white,
                    onRefresh: () async {
                      setState(() {
                        _documentLimit = 20;
                      }); // Sayfalamayı başa sar
                      await Future.delayed(
                        const Duration(milliseconds: 600),
                      ); // Şık bir animasyon süresi
                    },
                    child: SingleChildScrollView(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                            child: Row(
                              children: [
                                Material(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(14),
                                  elevation: 0,
                                  child: InkWell(
                                    onTap: () => _showCategoryPickerForFilter(
                                      "",
                                      "",
                                      "",
                                      false,
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                    child: Container(
                                      width: 134,
                                      height: 56,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(14),
                                        border: Border.all(
                                          color: const Color(0x1F000000),
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.dashboard_customize_rounded,
                                            size: 18,
                                            color: Colors.grey[800],
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              _filterCategoryName == tr('all')
                                                  ? tr('category')
                                                  : _filterCategoryDisplayName,
                                              style: LocalFonts.poppins(
                                                fontSize: 12.5,
                                                fontWeight: FontWeight.w600,
                                                color: Colors.grey[900],
                                              ),
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          Icon(
                                            Icons.expand_more_rounded,
                                            size: 18,
                                            color: Colors.grey[700],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 1),
                                Expanded(
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(14),
                                      border: Border.all(
                                        color: const Color(0x14000000),
                                      ),
                                    ),
                                    child: TextField(
                                      controller: _searchController,
                                      focusNode: _searchFocusNode,
                                      autofocus: false,
                                      cursorColor: Colors.black87,
                                      decoration: InputDecoration(
                                        filled: false,
                                        fillColor: Colors.transparent,
                                        hintText: tr('search_hint'),
                                        hintStyle: LocalFonts.poppins(
                                          color: Colors.grey[500],
                                          fontSize: 13,
                                        ),
                                        prefixIcon: Icon(
                                          Icons.search_rounded,
                                          color: Colors.grey[800],
                                          size: 22,
                                        ),
                                        suffixIcon: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            if (_searchText.isEmpty)
                                              IconButton(
                                                icon: Icon(
                                                  _isListening
                                                      ? Icons.mic
                                                      : Icons.mic_none,
                                                  color: _isListening
                                                      ? Colors.red
                                                      : Colors.grey[800],
                                                ),
                                                onPressed:
                                                    _speechToText.isNotListening
                                                    ? _startListening
                                                    : _stopListening,
                                              ),
                                            if (_searchText.isNotEmpty)
                                              IconButton(
                                                icon: const Icon(
                                                  Icons.close_rounded,
                                                  color: Colors.grey,
                                                ),
                                                onPressed: () {
                                                  _searchFocusNode.unfocus();
                                                  FocusManager
                                                      .instance
                                                      .primaryFocus
                                                      ?.unfocus();
                                                  setState(() {
                                                    _searchController.clear();
                                                    _searchText = "";
                                                  });
                                                  _savePreferences();
                                                  _stopListening();
                                                },
                                              ),
                                          ],
                                        ),
                                        border: InputBorder.none,
                                        enabledBorder: InputBorder.none,
                                        focusedBorder: InputBorder.none,
                                        contentPadding:
                                            const EdgeInsets.symmetric(
                                              vertical: 16,
                                            ),
                                      ),
                                      onChanged: (val) {
                                        setState(() {
                                          _searchText = val.toLowerCase();
                                          _isFiltering = true;
                                        });
                                        _savePreferences();
                                        Future.delayed(
                                          const Duration(milliseconds: 500),
                                          () {
                                            if (mounted &&
                                                _searchText ==
                                                    val.toLowerCase()) {
                                              setState(
                                                () => _isFiltering = false,
                                              );
                                            }
                                          },
                                        );
                                      },
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          if (_filterCategoryName == tr('all') &&
                              _searchText.isEmpty)
                            StreamBuilder<QuerySnapshot>(
                              stream: FirebaseFirestore.instance
                                  .collection('listings')
                                  .where(
                                    'showcaseUntil',
                                    isGreaterThanOrEqualTo: Timestamp.now(),
                                  )
                                  .snapshots(),
                              builder: (context, snapshot) {
                                if (!snapshot.hasData ||
                                    snapshot.data!.docs.isEmpty)
                                  return const SizedBox();
                                var showcaseDocs = snapshot.data!.docs.where((
                                  doc,
                                ) {
                                  var data = doc.data() as Map<String, dynamic>;
                                  return !hiddenUsers.contains(
                                    data['sellerId'],
                                  );
                                }).toList();

                                // Vitrine en son eklenenler en solda (başta) görünsün diye client-side sıralama
                                showcaseDocs.sort((a, b) {
                                  var dataA = a.data() as Map<String, dynamic>;
                                  var dataB = b.data() as Map<String, dynamic>;
                                  Timestamp? timeA =
                                      dataA['showcasedAt'] ??
                                      dataA['createdAt'];
                                  Timestamp? timeB =
                                      dataB['showcasedAt'] ??
                                      dataB['createdAt'];
                                  if (timeA == null && timeB == null) return 0;
                                  if (timeA == null) return 1;
                                  if (timeB == null) return -1;
                                  return timeB.compareTo(
                                    timeA,
                                  ); // Azalan sıralama (En yeni en başta)
                                });

                                if (showcaseDocs.isEmpty)
                                  return const SizedBox();
                                return Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        16,
                                        12,
                                        16,
                                        8,
                                      ),
                                      child: Row(
                                        children: [
                                          Text(
                                            tr('showcase'),
                                            style: LocalFonts.poppins(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 17,
                                            ),
                                          ),
                                          const Spacer(),
                                          TextButton(
                                            style: TextButton.styleFrom(
                                              minimumSize: Size.zero,
                                              padding: EdgeInsets.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              visualDensity:
                                                  VisualDensity.compact,
                                            ),
                                            onPressed: () {
                                              FocusScope.of(context).unfocus();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      const ShowcaseListScreen(),
                                                ),
                                              );
                                            },
                                            child: Text(
                                              tr('see_all'),
                                              style: LocalFonts.poppins(
                                                color: AppColors.primary,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      height: 215,
                                      child: ListView.builder(
                                        physics: const BouncingScrollPhysics(),
                                        scrollDirection: Axis.horizontal,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                        ),
                                        itemCount: showcaseDocs.length,
                                        itemBuilder: (context, index) {
                                          var data =
                                              showcaseDocs[index].data()
                                                  as Map<String, dynamic>;
                                          String formattedPrice = data['price']
                                              .toString()
                                              .split('.')
                                              .first
                                              .replaceAllMapped(
                                                RegExp(r'\B(?=(\d{3})+(?!\d))'),
                                                (m) => '.',
                                              );
                                          List<String> allImages = [];
                                          if (data['imageUrl'] != null &&
                                              data['imageUrl']
                                                  .toString()
                                                  .isNotEmpty)
                                            allImages.add(
                                              data['imageUrl'].toString(),
                                            );
                                          if (data['additionalImages'] !=
                                              null) {
                                            for (var img
                                                in data['additionalImages']) {
                                              if (img.toString().isNotEmpty)
                                                allImages.add(img.toString());
                                            }
                                          }
                                          if (allImages.isEmpty)
                                            allImages.add('');
                                          return InkWell(
                                            onTap: () {
                                              FocusScope.of(context).unfocus();
                                              Navigator.push(
                                                context,
                                                MaterialPageRoute(
                                                  builder: (context) =>
                                                      ListingDetailScreen(
                                                        data: data,
                                                        listingId:
                                                            showcaseDocs[index]
                                                                .id,
                                                      ),
                                                ),
                                              );
                                            },
                                            child: Container(
                                              width: 155,
                                              margin:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.circular(16),
                                                boxShadow: [
                                                  BoxShadow(
                                                    color: AppColors.secondary
                                                        .withValues(
                                                          alpha: 0.15,
                                                        ),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 3),
                                                  ),
                                                ],
                                                border: Border.all(
                                                  color: AppColors.secondary
                                                      .withValues(alpha: 0.6),
                                                  width: 1.5,
                                                ),
                                              ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Expanded(
                                                    child: ClipRRect(
                                                      borderRadius:
                                                          const BorderRadius.vertical(
                                                            top:
                                                                Radius.circular(
                                                                  14,
                                                                ),
                                                          ),
                                                      child: SizedBox(
                                                        width: double.infinity,
                                                        child:
                                                            allImages
                                                                .first
                                                                .isEmpty
                                                            ? const Icon(
                                                                Icons.image,
                                                                color:
                                                                    Colors.grey,
                                                              )
                                                            : Stack(
                                                                fit: StackFit
                                                                    .expand,
                                                                children: [
                                                                  CachedNetworkImage(
                                                                    imageUrl:
                                                                        allImages
                                                                            .first,
                                                                    fit: BoxFit
                                                                        .cover,
                                                                    placeholder: (c, u) => const Center(
                                                                      child: SizedBox(
                                                                        width:
                                                                            20,
                                                                        height:
                                                                            20,
                                                                        child: CircularProgressIndicator(
                                                                          strokeWidth:
                                                                              2,
                                                                        ),
                                                                      ),
                                                                    ),
                                                                    errorWidget:
                                                                        (
                                                                          c,
                                                                          u,
                                                                          e,
                                                                        ) => const Icon(
                                                                          Icons
                                                                              .image_not_supported,
                                                                          color:
                                                                              Colors.grey,
                                                                        ),
                                                                  ),
                                                                ],
                                                              ),
                                                      ),
                                                    ),
                                                  ),
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          12,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          '₺$formattedPrice',
                                                          maxLines: 1,
                                                          softWrap: false,
                                                          overflow:
                                                              TextOverflow.clip,
                                                          style:
                                                              LocalFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                fontSize: 17,
                                                                color: AppColors
                                                                    .primary,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        Text(
                                                          data['title'] ?? '',
                                                          maxLines: 1,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              LocalFonts.poppins(
                                                                fontSize: 12,
                                                                color: Colors
                                                                    .black87,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w500,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 4,
                                                        ),
                                                        if (data['city'] !=
                                                                null &&
                                                            data['district'] !=
                                                                null)
                                                          Text(
                                                            _listingLocationText(
                                                              data,
                                                            ),
                                                            style:
                                                                LocalFonts.poppins(
                                                                  fontSize: 10,
                                                                  color: Colors
                                                                      .grey[600],
                                                                ),
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ],
                                );
                              },
                            ),

                          if (_filterCategoryName == tr('all') &&
                              _searchText.isEmpty &&
                              _filterCity == null &&
                              _filterDistrict == null &&
                              (_filterNeighborhood?.trim().isEmpty ?? true) &&
                              _minPriceController.text.isEmpty &&
                              _maxPriceController.text.isEmpty &&
                              _distance >= 30.0 &&
                              !_featureDropdownValues.values.any(
                                (value) => value != null && value.isNotEmpty,
                              ))
                            _buildAuctionShowcase(), // MÜZAYEDE VİTRİNİ

                          if (_filterCategoryName == tr('all') &&
                              _searchText.isEmpty &&
                              _filterCity == null &&
                              _filterDistrict == null &&
                              (_filterNeighborhood?.trim().isEmpty ?? true) &&
                              _minPriceController.text.isEmpty &&
                              _maxPriceController.text.isEmpty &&
                              _distance >= 30.0 &&
                              !_featureDropdownValues.values.any(
                                (value) => value != null && value.isNotEmpty,
                              ))
                            _buildNearbyListingsPreview(hiddenUsers),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(
                              16.0,
                              0,
                              16.0,
                              16.0,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _isFiltering
                                    ? Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(40.0),
                                          child: Column(
                                            children: [
                                              const CircularProgressIndicator(),
                                              const SizedBox(height: 16),
                                              Text(
                                                tr('filtering_results'),
                                                style: LocalFonts.poppins(
                                                  color: Colors.grey,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      )
                                    : StreamBuilder<QuerySnapshot>(
                                        stream: _buildListingsQuery()
                                            .snapshots(),
                                        initialData: _cachedListingsSnapshot,
                                        builder: (context, snapshot) {
                                          if (snapshot.hasError) {
                                            return Center(
                                              child: Padding(
                                                padding: const EdgeInsets.all(
                                                  24.0,
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Icon(
                                                      Icons.error_outline,
                                                      color: Colors.redAccent,
                                                      size: 34,
                                                    ),
                                                    const SizedBox(height: 10),
                                                    Text(
                                                      tr(
                                                        'no_listings_found_criteria',
                                                      ),
                                                      textAlign:
                                                          TextAlign.center,
                                                      style: LocalFonts.poppins(
                                                        color: Colors.grey[700],
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }
                                          if (!snapshot.hasData)
                                            return const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            );
                                          _cachedListingsSnapshot =
                                              snapshot.data;
                                          var filteredDocs = snapshot.data!.docs.where((
                                            doc, // ÖNEMLİ: Arama ve Mesafe gibi karmaşık sorgular Firestore ile doğrudan yapılamaz.
                                            // Bu yüzden bu iki filtreyi mecburen istemci tarafında bırakıyoruz.
                                            // İdeal çözüm için aşağıda "Ek İyileştirme Önerileri" bölümünü okuyun.
                                          ) {
                                            var data =
                                                doc.data()
                                                    as Map<String, dynamic>;
                                            if (hiddenUsers.contains(
                                              data['sellerId'],
                                            ))
                                              return false;

                                            final bool isSearchMode =
                                                _searchText.trim().isNotEmpty;

                                            bool matchLocation = true;
                                            if (!isSearchMode &&
                                                _filterCity != null) {
                                              matchLocation =
                                                  _normalizeText(
                                                    data['city']?.toString() ??
                                                        '',
                                                  ) ==
                                                  _normalizeText(_filterCity!);
                                            }
                                            if (matchLocation &&
                                                !isSearchMode &&
                                                _filterDistrict != null) {
                                              matchLocation =
                                                  _normalizeText(
                                                    data['district']
                                                            ?.toString() ??
                                                        '',
                                                  ) ==
                                                  _normalizeText(
                                                    _filterDistrict!,
                                                  );
                                            }
                                            if (!matchLocation) return false;

                                            // YENİ: AKILLI ARAMA MANTIĞI (Çoklu kelime, Türkçe karakter duyarsız, açıklama içi arama)
                                            bool matchSearch = true;
                                            if (_searchText.isNotEmpty) {
                                              String normSearch =
                                                  _normalizeText(_searchText);
                                              String normTitle = _normalizeText(
                                                data['title']?.toString() ?? '',
                                              );
                                              String normDesc = _normalizeText(
                                                data['description']
                                                        ?.toString() ??
                                                    '',
                                              );
                                              String normCat = _normalizeText(
                                                data['categoryPath']
                                                        ?.toString() ??
                                                    '',
                                              );

                                              List<String> searchWords =
                                                  normSearch
                                                      .split(' ')
                                                      .where(
                                                        (w) => w.isNotEmpty,
                                                      )
                                                      .toList();
                                              for (String word in searchWords) {
                                                if (!normTitle.contains(word) &&
                                                    !normDesc.contains(word) &&
                                                    !normCat.contains(word) &&
                                                    !(data['listingNo']
                                                            ?.toString()
                                                            .contains(word) ??
                                                        false)) {
                                                  matchSearch = false;
                                                  break;
                                                }
                                              }
                                            }

                                            bool matchNeighborhood = true;
                                            if (!isSearchMode &&
                                                _filterNeighborhood != null &&
                                                _filterNeighborhood!
                                                    .isNotEmpty) {
                                              Map<String, dynamic>?
                                              listingFeatures =
                                                  data['features'] != null
                                                  ? Map<String, dynamic>.from(
                                                      data['features'],
                                                    )
                                                  : null;
                                              String? listingMahalle =
                                                  listingFeatures?['Mahalle']
                                                      ?.toString();
                                              if (listingMahalle == null ||
                                                  !listingMahalle
                                                      .toLowerCase()
                                                      .contains(
                                                        _filterNeighborhood!
                                                            .toLowerCase(),
                                                      )) {
                                                matchNeighborhood = false;
                                              }
                                            }
                                            bool matchDistance = true;
                                            if (!isSearchMode &&
                                                _distance < 30.0 &&
                                                _userPosition != null) {
                                              final num? lat =
                                                  data['lat'] as num?;
                                              final num? lng =
                                                  data['lng'] as num?;
                                              if (lat != null && lng != null) {
                                                double dist =
                                                    Geolocator.distanceBetween(
                                                      _userPosition!.latitude,
                                                      _userPosition!.longitude,
                                                      lat.toDouble(),
                                                      lng.toDouble(),
                                                    );
                                                if ((dist / 1000) > _distance)
                                                  matchDistance = false;
                                              } else {
                                                matchDistance =
                                                    false; // YENİ: İlanın konumu yoksa ve mesafe filtresi uygulanmışsa dahil etme
                                              }
                                            }

                                            bool matchFeatures = true;
                                            if (!isSearchMode) {
                                              _featureDropdownValues.forEach((
                                                key,
                                                val,
                                              ) {
                                                if (val != null &&
                                                    val.isNotEmpty) {
                                                  Map<String, dynamic>?
                                                  listingFeatures;
                                                  if (data['features'] !=
                                                      null) {
                                                    listingFeatures =
                                                        Map<
                                                          String,
                                                          dynamic
                                                        >.from(
                                                          data['features'],
                                                        );
                                                  }
                                                  if (listingFeatures == null ||
                                                      listingFeatures[key] !=
                                                          val) {
                                                    matchFeatures = false;
                                                  }
                                                }
                                              });
                                            }

                                            bool matchCategory = true;
                                            if (!isSearchMode &&
                                                _filterCategoryName !=
                                                    tr('all')) {
                                              final String categoryPath =
                                                  data['categoryPath']
                                                      ?.toString() ??
                                                  '';
                                              matchCategory =
                                                  categoryPath ==
                                                      _filterCategoryName ||
                                                  categoryPath.startsWith(
                                                    '${_filterCategoryName} > ',
                                                  );
                                            }

                                            bool matchPrice = true;
                                            if (!isSearchMode) {
                                              final minPrice = _parsePrice(
                                                _minPriceController.text,
                                              );
                                              final maxPrice = _parsePrice(
                                                _maxPriceController.text,
                                              );
                                              final listingPrice = _parsePrice(
                                                data['price'],
                                              );
                                              if (minPrice != null &&
                                                  (listingPrice == null ||
                                                      listingPrice <
                                                          minPrice)) {
                                                matchPrice = false;
                                              }
                                              if (maxPrice != null &&
                                                  (listingPrice == null ||
                                                      listingPrice >
                                                          maxPrice)) {
                                                matchPrice = false;
                                              }
                                            }

                                            return matchSearch &&
                                                matchCategory &&
                                                matchDistance &&
                                                matchNeighborhood &&
                                                matchFeatures &&
                                                matchPrice;
                                          }).toList();

                                          // Kullanıcının herhangi bir filtre uygulayıp uygulamadığını kontrol et.
                                          // Bu, sadece filtresiz durumda sayfa sonuna gelindiğinde "yükleniyor"
                                          // animasyonunu göstermek için kullanılır.
                                          bool hasAnyFilter =
                                              _searchText.isNotEmpty ||
                                              _filterCategoryName !=
                                                  tr('all') ||
                                              _filterCity != null ||
                                              _filterDistrict != null ||
                                              (_filterNeighborhood
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false) ||
                                              _minPriceController
                                                  .text
                                                  .isNotEmpty ||
                                              _maxPriceController
                                                  .text
                                                  .isNotEmpty ||
                                              _distance < 30.0 ||
                                              _featureDropdownValues.values.any(
                                                (v) =>
                                                    v != null && v.isNotEmpty,
                                              );

                                          // --- YENİ: Arama yapıldıysa sadece o kelimenin geçtiği kategorileri üstte listele ---
                                          Set<String> matchedCategories = {};
                                          if (_searchText.isNotEmpty) {
                                            for (var doc in filteredDocs) {
                                              String? cat =
                                                  (doc.data()
                                                      as Map<
                                                        String,
                                                        dynamic
                                                      >)['categoryPath'];
                                              if (cat != null)
                                                matchedCategories.add(cat);
                                            }
                                          }

                                          if (filteredDocs.isEmpty) {
                                            return Center(
                                              child: Padding(
                                                padding: const EdgeInsets.only(
                                                  top: 40,
                                                ),
                                                child: Column(
                                                  children: [
                                                    const Icon(
                                                      Icons.search_off_rounded,
                                                      size: 60,
                                                      color: Colors.grey,
                                                    ),
                                                    const SizedBox(height: 16),
                                                    Text(
                                                      tr(
                                                        'no_listings_found_criteria',
                                                      ),
                                                      style: LocalFonts.poppins(
                                                        color: Colors.grey,
                                                      ),
                                                    ),
                                                    const SizedBox(height: 16),
                                                    ElevatedButton.icon(
                                                      onPressed: () {
                                                        FocusScope.of(
                                                          context,
                                                        ).unfocus();
                                                        Navigator.push(
                                                          context,
                                                          MaterialPageRoute(
                                                            builder: (context) =>
                                                                const SearchAlarmsScreen(),
                                                          ),
                                                        );
                                                      },
                                                      icon: const Icon(
                                                        Icons
                                                            .notifications_active,
                                                        color: Colors.white,
                                                      ),
                                                      label: Text(
                                                        tr('set_search_alarm'),
                                                        style:
                                                            LocalFonts.poppins(
                                                              color:
                                                                  Colors.white,
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                            ),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            AppColors.secondary,
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                12,
                                                              ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          }

                                          Widget categorySuggestions =
                                              const SizedBox();
                                          if (matchedCategories.isNotEmpty) {
                                            categorySuggestions = Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Padding(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                      ),
                                                  child: Text(
                                                    tr('related_categories'),
                                                    style: LocalFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 13,
                                                      color: Colors.grey[700],
                                                    ),
                                                  ),
                                                ),
                                                SingleChildScrollView(
                                                  scrollDirection:
                                                      Axis.horizontal,
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 16.0,
                                                        vertical: 8,
                                                      ),
                                                  child: Row(
                                                    children: matchedCategories
                                                        .map(
                                                          (cat) => Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  right: 8.0,
                                                                ),
                                                            child: ActionChip(
                                                              backgroundColor:
                                                                  AppColors
                                                                      .primary
                                                                      .withValues(
                                                                        alpha:
                                                                            0.1,
                                                                      ),
                                                              side: BorderSide(
                                                                color: AppColors
                                                                    .primary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.2,
                                                                    ),
                                                              ),
                                                              label: Text(
                                                                cat
                                                                    .split(
                                                                      ' > ',
                                                                    )
                                                                    .last,
                                                                style: LocalFonts.poppins(
                                                                  fontSize: 12,
                                                                  color: AppColors
                                                                      .primary,
                                                                ),
                                                              ),
                                                              onPressed: () {
                                                                setState(() {
                                                                  _filterCategoryName =
                                                                      cat;
                                                                  _filterCategoryDisplayName =
                                                                      cat
                                                                          .split(
                                                                            ' > ',
                                                                          )
                                                                          .last;
                                                                  _searchController
                                                                      .clear();
                                                                  _searchText =
                                                                      "";
                                                                });
                                                                _savePreferences();
                                                              },
                                                            ),
                                                          ),
                                                        )
                                                        .toList(),
                                                  ),
                                                ),
                                                const Divider(),
                                              ],
                                            );
                                          }

                                          bool isDefaultView =
                                              _filterCategoryName ==
                                                  tr('all') &&
                                              _searchText.isEmpty &&
                                              _filterCity == null &&
                                              _filterDistrict == null &&
                                              (_filterNeighborhood
                                                      ?.trim()
                                                      .isEmpty ??
                                                  true) &&
                                              _minPriceController
                                                  .text
                                                  .isEmpty &&
                                              _maxPriceController
                                                  .text
                                                  .isEmpty &&
                                              _distance >= 30.0 &&
                                              !_featureDropdownValues.values
                                                  .any(
                                                    (value) =>
                                                        value != null &&
                                                        value.isNotEmpty,
                                                  );

                                          Widget allListingsHeader =
                                              const SizedBox();
                                          final visibleDefaultDocs =
                                              filteredDocs.take(20).toList();
                                          if (isDefaultView &&
                                              filteredDocs.isNotEmpty) {
                                            allListingsHeader = Column(
                                              children: [
                                                const BannerAdWidget(),
                                                SizedBox(
                                                  height: 28,
                                                  child: Row(
                                                    children: [
                                                      Text(
                                                        tr('all_listings'),
                                                        style:
                                                            LocalFonts.poppins(
                                                              fontWeight:
                                                                  FontWeight
                                                                      .bold,
                                                              fontSize: 17,
                                                            ),
                                                      ),
                                                      const Spacer(),
                                                      TextButton(
                                                        style: TextButton.styleFrom(
                                                          minimumSize:
                                                              Size.zero,
                                                          padding:
                                                              EdgeInsets.zero,
                                                          tapTargetSize:
                                                              MaterialTapTargetSize
                                                                  .shrinkWrap,
                                                          visualDensity:
                                                              VisualDensity
                                                                  .compact,
                                                        ),
                                                        onPressed: () {
                                                          FocusScope.of(
                                                            context,
                                                          ).unfocus();
                                                          Navigator.push(
                                                            context,
                                                            MaterialPageRoute(
                                                              builder: (context) =>
                                                                  const AllListingsScreen(),
                                                            ),
                                                          );
                                                        },
                                                        child: Text(
                                                          tr('see_all'),
                                                          style:
                                                              LocalFonts.poppins(
                                                                color: AppColors
                                                                    .primary,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                                const SizedBox(height: 8),
                                              ],
                                            );
                                          }

                                          bool isFiltered =
                                              _filterCategoryName !=
                                                  tr('all') ||
                                              _searchText.isNotEmpty ||
                                              _filterCity != null ||
                                              _filterDistrict != null ||
                                              (_filterNeighborhood
                                                      ?.trim()
                                                      .isNotEmpty ??
                                                  false) ||
                                              _minPriceController
                                                  .text
                                                  .isNotEmpty ||
                                              _maxPriceController
                                                  .text
                                                  .isNotEmpty ||
                                              _distance < 30.0 ||
                                              _featureDropdownValues.values.any(
                                                (value) =>
                                                    value != null &&
                                                    value.isNotEmpty,
                                              );

                                          Widget resultsWidget;
                                          if (isFiltered) {
                                            resultsWidget = ListView.separated(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              itemCount: filteredDocs.length,
                                              separatorBuilder:
                                                  (context, index) =>
                                                      (index + 1) % 5 == 0
                                                      ? const BannerAdWidget()
                                                      : const SizedBox(
                                                          height: 12,
                                                        ),
                                              itemBuilder: (context, index) {
                                                var data =
                                                    filteredDocs[index].data()
                                                        as Map<String, dynamic>;

                                                String
                                                formattedPrice = data['price']
                                                    .toString()
                                                    .split('.')
                                                    .first
                                                    .replaceAllMapped(
                                                      RegExp(
                                                        r'\B(?=(\d{3})+(?!\d))',
                                                      ),
                                                      (m) => '.',
                                                    );
                                                List<String> allImages = [];
                                                if (data['imageUrl'] != null &&
                                                    data['imageUrl']
                                                        .toString()
                                                        .isNotEmpty)
                                                  allImages.add(
                                                    data['imageUrl'].toString(),
                                                  );
                                                if (data['additionalImages'] !=
                                                    null) {
                                                  for (var img
                                                      in data['additionalImages']) {
                                                    if (img
                                                        .toString()
                                                        .isNotEmpty)
                                                      allImages.add(
                                                        img.toString(),
                                                      );
                                                  }
                                                }
                                                if (allImages.isEmpty)
                                                  allImages.add('');
                                                bool isCatShowcased =
                                                    data['categoryShowcaseUntil'] !=
                                                        null &&
                                                    (data['categoryShowcaseUntil']
                                                            as Timestamp)
                                                        .toDate()
                                                        .isAfter(
                                                          DateTime.now(),
                                                        );

                                                return InkWell(
                                                  onTap: () {
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus();
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ListingDetailScreen(
                                                              data: data,
                                                              listingId:
                                                                  filteredDocs[index]
                                                                      .id,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    height: 115,
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            3,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Container(
                                                      decoration: isCatShowcased
                                                          ? BoxDecoration(
                                                              border: Border.all(
                                                                color: AppColors
                                                                    .secondary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                                width: 2,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            )
                                                          : null,
                                                      child: Row(
                                                        children: [
                                                          ClipRRect(
                                                            borderRadius:
                                                                const BorderRadius.horizontal(
                                                                  left:
                                                                      Radius.circular(
                                                                        16,
                                                                      ),
                                                                ),
                                                            child: SizedBox(
                                                              width: 115,
                                                              height: 115,
                                                              child:
                                                                  allImages
                                                                      .first
                                                                      .isEmpty
                                                                  ? const Icon(
                                                                      Icons
                                                                          .image,
                                                                      color: Colors
                                                                          .grey,
                                                                    )
                                                                  : Stack(
                                                                      fit: StackFit
                                                                          .expand,
                                                                      children: [
                                                                        PageView.builder(
                                                                          itemCount:
                                                                              allImages.length,
                                                                          itemBuilder:
                                                                              (
                                                                                context,
                                                                                imgIndex,
                                                                              ) => CachedNetworkImage(
                                                                                imageUrl: allImages[imgIndex],
                                                                                fit: BoxFit.cover,
                                                                                placeholder:
                                                                                    (
                                                                                      c,
                                                                                      u,
                                                                                    ) => const Center(
                                                                                      child: SizedBox(
                                                                                        width: 20,
                                                                                        height: 20,
                                                                                        child: CircularProgressIndicator(
                                                                                          strokeWidth: 2,
                                                                                        ),
                                                                                      ),
                                                                                    ),
                                                                                errorWidget:
                                                                                    (
                                                                                      c,
                                                                                      u,
                                                                                      e,
                                                                                    ) => const Icon(
                                                                                      Icons.image_not_supported,
                                                                                      color: Colors.grey,
                                                                                    ),
                                                                              ),
                                                                        ),
                                                                      ],
                                                                    ),
                                                            ),
                                                          ),
                                                          Expanded(
                                                            child: Padding(
                                                              padding:
                                                                  const EdgeInsets.all(
                                                                    10,
                                                                  ),
                                                              child: Column(
                                                                crossAxisAlignment:
                                                                    CrossAxisAlignment
                                                                        .start,
                                                                mainAxisAlignment:
                                                                    MainAxisAlignment
                                                                        .center,
                                                                children: [
                                                                  Text(
                                                                    data['title'] ??
                                                                        '',
                                                                    maxLines: 2,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                    style: LocalFonts.poppins(
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w600,
                                                                      fontSize:
                                                                          13,
                                                                      color: Colors
                                                                          .black87,
                                                                      height:
                                                                          1.2,
                                                                    ),
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child: FittedBox(
                                                                          fit: BoxFit
                                                                              .scaleDown,
                                                                          alignment:
                                                                              Alignment.centerLeft,
                                                                          child: Text(
                                                                            '₺$formattedPrice',
                                                                            style: LocalFonts.poppins(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: AppColors.primary,
                                                                              fontSize: 17,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      if (isCatShowcased)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                8.0,
                                                                          ),
                                                                          child: Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              horizontal: 6,
                                                                              vertical: 2,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: AppColors.secondary,
                                                                              borderRadius: BorderRadius.circular(
                                                                                4,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              tr(
                                                                                'highlighted',
                                                                              ),
                                                                              style: LocalFonts.poppins(
                                                                                color: Colors.white,
                                                                                fontSize: 8,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      if (data['isPro'] ==
                                                                          true)
                                                                        Padding(
                                                                          padding: const EdgeInsets.only(
                                                                            left:
                                                                                8.0,
                                                                          ),
                                                                          child: Container(
                                                                            padding: const EdgeInsets.symmetric(
                                                                              horizontal: 6,
                                                                              vertical: 2,
                                                                            ),
                                                                            decoration: BoxDecoration(
                                                                              color: AppColors.secondary,
                                                                              borderRadius: BorderRadius.circular(
                                                                                4,
                                                                              ),
                                                                            ),
                                                                            child: Text(
                                                                              'PRO',
                                                                              style: LocalFonts.poppins(
                                                                                color: Colors.white,
                                                                                fontSize: 8,
                                                                                fontWeight: FontWeight.bold,
                                                                              ),
                                                                            ),
                                                                          ),
                                                                        ),
                                                                    ],
                                                                  ),
                                                                  const SizedBox(
                                                                    height: 4,
                                                                  ),
                                                                  if (data['city'] !=
                                                                          null &&
                                                                      data['district'] !=
                                                                          null)
                                                                    Text(
                                                                      _listingLocationText(
                                                                        data,
                                                                      ),
                                                                      style: LocalFonts.poppins(
                                                                        fontSize:
                                                                            11,
                                                                        color: Colors
                                                                            .grey[600],
                                                                      ),
                                                                      maxLines:
                                                                          1,
                                                                      overflow:
                                                                          TextOverflow
                                                                              .ellipsis,
                                                                    ),
                                                                ],
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          } else {
                                            resultsWidget = GridView.builder(
                                              shrinkWrap: true,
                                              physics:
                                                  const NeverScrollableScrollPhysics(),
                                              gridDelegate:
                                                  SliverGridDelegateWithFixedCrossAxisCount(
                                                    crossAxisCount:
                                                        crossAxisCount,
                                                    childAspectRatio:
                                                        gridAspectRatio,
                                                    crossAxisSpacing: 16,
                                                    mainAxisSpacing: 16,
                                                  ),
                                              itemCount:
                                                  visibleDefaultDocs.length,
                                              itemBuilder: (context, index) {
                                                var data =
                                                    visibleDefaultDocs[index]
                                                            .data()
                                                        as Map<String, dynamic>;
                                                String
                                                formattedPrice = data['price']
                                                    .toString()
                                                    .split('.')
                                                    .first
                                                    .replaceAllMapped(
                                                      RegExp(
                                                        r'\B(?=(\d{3})+(?!\d))',
                                                      ),
                                                      (m) => '.',
                                                    );
                                                List<String> allImages = [];
                                                if (data['imageUrl'] != null &&
                                                    data['imageUrl']
                                                        .toString()
                                                        .isNotEmpty)
                                                  allImages.add(
                                                    data['imageUrl'].toString(),
                                                  );
                                                if (data['additionalImages'] !=
                                                    null) {
                                                  for (var img
                                                      in data['additionalImages']) {
                                                    if (img
                                                        .toString()
                                                        .isNotEmpty)
                                                      allImages.add(
                                                        img.toString(),
                                                      );
                                                  }
                                                }
                                                if (allImages.isEmpty)
                                                  allImages.add('');
                                                bool isCatShowcased =
                                                    data['categoryShowcaseUntil'] !=
                                                        null &&
                                                    (data['categoryShowcaseUntil']
                                                            as Timestamp)
                                                        .toDate()
                                                        .isAfter(
                                                          DateTime.now(),
                                                        );
                                                final proUntil =
                                                    data['proUntil'];
                                                final bool isPro =
                                                    proUntil is Timestamp &&
                                                        proUntil
                                                            .toDate()
                                                            .isAfter(
                                                              DateTime.now(),
                                                            ) ||
                                                    (proUntil == null &&
                                                        data['isPro'] == true);
                                                return InkWell(
                                                  onTap: () {
                                                    FocusScope.of(
                                                      context,
                                                    ).unfocus();
                                                    Navigator.push(
                                                      context,
                                                      MaterialPageRoute(
                                                        builder: (context) =>
                                                            ListingDetailScreen(
                                                              data: data,
                                                              listingId:
                                                                  filteredDocs[index]
                                                                      .id,
                                                            ),
                                                      ),
                                                    );
                                                  },
                                                  child: Container(
                                                    decoration: BoxDecoration(
                                                      color: Colors.white,
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            16,
                                                          ),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: Colors.black
                                                              .withValues(
                                                                alpha: 0.05,
                                                              ),
                                                          blurRadius: 10,
                                                          offset: const Offset(
                                                            0,
                                                            4,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Container(
                                                      decoration: isCatShowcased
                                                          ? BoxDecoration(
                                                              border: Border.all(
                                                                color: AppColors
                                                                    .secondary
                                                                    .withValues(
                                                                      alpha:
                                                                          0.5,
                                                                    ),
                                                                width: 2,
                                                              ),
                                                              borderRadius:
                                                                  BorderRadius.circular(
                                                                    16,
                                                                  ),
                                                            )
                                                          : null,
                                                      child: Column(
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Expanded(
                                                            child: ClipRRect(
                                                              borderRadius:
                                                                  const BorderRadius.vertical(
                                                                    top:
                                                                        Radius.circular(
                                                                          16,
                                                                        ),
                                                                  ),
                                                              child: SizedBox(
                                                                width: double
                                                                    .infinity,
                                                                child:
                                                                    allImages
                                                                        .first
                                                                        .isEmpty
                                                                    ? const Icon(
                                                                        Icons
                                                                            .image,
                                                                        color: Colors
                                                                            .grey,
                                                                      )
                                                                    : Stack(
                                                                        fit: StackFit
                                                                            .expand,
                                                                        children: [
                                                                          PageView.builder(
                                                                            itemCount:
                                                                                allImages.length,
                                                                            itemBuilder:
                                                                                (
                                                                                  context,
                                                                                  imgIndex,
                                                                                ) => CachedNetworkImage(
                                                                                  imageUrl: allImages[imgIndex],
                                                                                  fit: BoxFit.cover,
                                                                                  placeholder:
                                                                                      (
                                                                                        c,
                                                                                        u,
                                                                                      ) => const Center(
                                                                                        child: SizedBox(
                                                                                          width: 20,
                                                                                          height: 20,
                                                                                          child: CircularProgressIndicator(
                                                                                            strokeWidth: 2,
                                                                                          ),
                                                                                        ),
                                                                                      ),
                                                                                  errorWidget:
                                                                                      (
                                                                                        c,
                                                                                        u,
                                                                                        e,
                                                                                      ) => const Icon(
                                                                                        Icons.image_not_supported,
                                                                                        color: Colors.grey,
                                                                                      ),
                                                                                ),
                                                                          ),
                                                                        ],
                                                                      ),
                                                              ),
                                                            ),
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.all(
                                                                  12,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                SizedBox(
                                                                  height: 28,
                                                                  child: Row(
                                                                    children: [
                                                                      Expanded(
                                                                        child: FittedBox(
                                                                          fit: BoxFit
                                                                              .scaleDown,
                                                                          alignment:
                                                                              Alignment.centerLeft,
                                                                          child: Text(
                                                                            '₺$formattedPrice',
                                                                            style: LocalFonts.poppins(
                                                                              fontWeight: FontWeight.bold,
                                                                              color: Colors.blue[900],
                                                                              fontSize: 17,
                                                                            ),
                                                                          ),
                                                                        ),
                                                                      ),
                                                                      const Spacer(),
                                                                      if (isCatShowcased)
                                                                        const Icon(
                                                                          Icons
                                                                              .stars,
                                                                          color:
                                                                              Colors.orange,
                                                                          size:
                                                                              16,
                                                                        ),
                                                                      if (isPro)
                                                                        const Icon(
                                                                          Icons
                                                                              .verified,
                                                                          color:
                                                                              AppColors.secondary,
                                                                          size:
                                                                              16,
                                                                        ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 6,
                                                                ),
                                                                Text(
                                                                  data['title'] ??
                                                                      '',
                                                                  maxLines: 1,
                                                                  overflow:
                                                                      TextOverflow
                                                                          .ellipsis,
                                                                  style: LocalFonts.poppins(
                                                                    fontSize:
                                                                        13,
                                                                    color: Colors
                                                                        .black87,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                if (data['city'] !=
                                                                        null &&
                                                                    data['district'] !=
                                                                        null)
                                                                  Text(
                                                                    _listingLocationText(
                                                                      data,
                                                                    ),
                                                                    style: LocalFonts.poppins(
                                                                      fontSize:
                                                                          10,
                                                                      color: Colors
                                                                          .grey[600],
                                                                    ),
                                                                    maxLines: 1,
                                                                    overflow:
                                                                        TextOverflow
                                                                            .ellipsis,
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            );
                                          }

                                          return Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              if (matchedCategories.isNotEmpty)
                                                categorySuggestions,
                                              allListingsHeader,
                                              resultsWidget,
                                              if (isDefaultView)
                                                _buildRecentlyViewedSection(),

                                              // Alta kaydırırken loading animasyonu çıkart
                                              if (_isLoadingMore &&
                                                  !hasAnyFilter)
                                                Padding(
                                                  padding: EdgeInsets.symmetric(
                                                    vertical: 20,
                                                  ),
                                                  child: Center(
                                                    child:
                                                        CircularProgressIndicator(),
                                                  ),
                                                ),
                                            ],
                                          );
                                        },
                                      ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: 0,
                          ), // Alt menü ile son ilanlar arasında küçük bir güvenli alan
                        ],
                      ),
                    ),
                  ),
                  // YENİ EKLEDİĞİMİZ WEB BANNER WIDGET'I BURADA
                  const Align(
                    alignment: Alignment.bottomCenter,
                    child: AppDownloadBanner(),
                  ),
                ],
              ),
            ),

            bottomNavigationBar: StreamBuilder<QuerySnapshot>(
              stream: AuthGate.isRegistered && currentUser != null
                  ? FirebaseFirestore.instance
                        .collection('chats')
                        .where('participants', arrayContains: currentUser.uid)
                        .snapshots()
                  : const Stream<QuerySnapshot>.empty(),
              builder: (context, chatSnap) {
                int unread = 0;
                if (chatSnap.hasData) {
                  for (var doc in chatSnap.data!.docs) {
                    if ((doc.data() as Map)['unreadBy']?.contains(
                          currentUser?.uid,
                        ) ??
                        false)
                      unread++;
                  }
                }
                return SafeArea(
                  child: Container(
                    margin: const EdgeInsets.only(
                      left: 20,
                      right: 20,
                      bottom: 0,
                    ),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(24),
                      child: BackdropFilter(
                        filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                        child: Container(
                          height: 65,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.85),
                            border: Border.all(
                              color: Colors.white.withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: MediaQuery.removePadding(
                            context: context,
                            removeBottom: true,
                            child: BottomNavigationBar(
                              backgroundColor: Colors.transparent,
                              elevation: 0,
                              type: BottomNavigationBarType.fixed,
                              selectedItemColor: AppColors.primary,
                              unselectedItemColor: Colors.grey[500],
                              showSelectedLabels: false,
                              showUnselectedLabels: false,
                              selectedFontSize: 0,
                              unselectedFontSize: 0,
                              currentIndex: 0,
                              items: [
                                BottomNavigationBarItem(
                                  icon: const Icon(
                                    Icons.home_outlined,
                                    size: 26,
                                  ),
                                  activeIcon: const Icon(
                                    Icons.home_rounded,
                                    size: 28,
                                    color: AppColors.primary,
                                  ),
                                  label: tr('home'),
                                ),
                                BottomNavigationBarItem(
                                  icon: Badge(
                                    isLabelVisible: unread > 0,
                                    label: Text(unread.toString()),
                                    child: const Icon(
                                      Icons.chat_bubble_outline_rounded,
                                      size: 24,
                                    ),
                                  ),
                                  activeIcon: Badge(
                                    isLabelVisible: unread > 0,
                                    label: Text(unread.toString()),
                                    child: const Icon(
                                      Icons.chat_bubble_rounded,
                                      size: 26,
                                      color: AppColors.primary,
                                    ),
                                  ),
                                  label: tr('messages'),
                                ),
                                BottomNavigationBarItem(
                                  icon: Transform.scale(
                                    scale: 1.35,
                                    child: Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  activeIcon: Transform.scale(
                                    scale: 1.35,
                                    child: Container(
                                      height: 32,
                                      width: 32,
                                      decoration: BoxDecoration(
                                        color: AppColors.secondary,
                                        shape: BoxShape.circle,
                                        boxShadow: [
                                          BoxShadow(
                                            color: AppColors.secondary
                                                .withValues(alpha: 0.4),
                                            blurRadius: 4,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.add,
                                        color: Colors.white,
                                        size: 22,
                                      ),
                                    ),
                                  ),
                                  label: tr('sell'),
                                ),
                                BottomNavigationBarItem(
                                  icon: _buildUrgentNavIcon(active: false),
                                  activeIcon: _buildUrgentNavIcon(active: true),
                                  label: 'Acil',
                                ),
                                BottomNavigationBarItem(
                                  icon: const Icon(
                                    Icons.person_outline_rounded,
                                    size: 26,
                                  ),
                                  activeIcon: const Icon(
                                    Icons.person_rounded,
                                    size: 28,
                                    color: AppColors.primary,
                                  ),
                                  label: tr('account'),
                                ),
                              ],
                              onTap: (index) {
                                FocusScope.of(
                                  context,
                                ).unfocus(); // YENİ: Başka sayfaya geçerken klavyeyi / odağı temizle
                                if (index == 0) {
                                  if (Navigator.canPop(context)) {
                                    Navigator.popUntil(
                                      context,
                                      (route) => route.isFirst,
                                    );
                                  } else {
                                    setState(() {
                                      _filterCategoryName = tr('all');
                                      _filterCategoryDisplayName = tr('all');
                                      _currentParentId = '';
                                      _currentParentName = tr('all');
                                      _currentParentDisplayName = tr('all');
                                      _searchController.clear();
                                      _searchText = '';
                                    });
                                    _savePreferences();
                                    _fetchCategoryFeatures("");
                                  }
                                }
                                if (index == 1) {
                                  AuthGate.requireRegisteredUser(
                                    context,
                                    message: tr('login_required_messages'),
                                  ).then((allowed) {
                                    if (allowed && context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const InboxScreen(),
                                        ),
                                      ).then((_) {
                                        if (mounted) _dismissSearchFocus();
                                      });
                                    }
                                  });
                                }
                                if (index == 2) {
                                  AuthGate.requireRegisteredUser(
                                    context,
                                    message: tr(
                                      'login_required_create_listing',
                                    ),
                                  ).then((allowed) {
                                    if (allowed && context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AddListingScreen(),
                                        ),
                                      ).then((_) {
                                        if (mounted) _dismissSearchFocus();
                                      });
                                    }
                                  });
                                }
                                if (index == 3) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          const UrgentListingsScreen(),
                                    ),
                                  ).then((_) {
                                    if (mounted) _dismissSearchFocus();
                                  });
                                }
                                if (index == 4) {
                                  AuthGate.requireRegisteredUser(
                                    context,
                                    message: tr('login_required_account'),
                                  ).then((allowed) {
                                    if (allowed && context.mounted) {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ProfileScreen(),
                                        ),
                                      ).then((_) {
                                        if (mounted) _dismissSearchFocus();
                                      });
                                    }
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

class BannerAdWidget extends StatefulWidget {
  const BannerAdWidget({super.key});
  @override
  State<BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _isLoaded = false;
  bool _isActive = false;
  @override
  void initState() {
    super.initState();
    _scheduleAdLoad();
  }

  Future<void> _scheduleAdLoad() async {
    if (kIsWeb) {
      await _fetchAdSettingsAndLoad();
      return;
    }

    await Future.delayed(const Duration(seconds: 8));
    if (!mounted) return;
    await _fetchAdSettingsAndLoad();
  }

  Future<void> _fetchAdSettingsAndLoad() async {
    try {
      var doc = await FirebaseFirestore.instance
          .collection('settings')
          .doc('ads')
          .get();
      String androidId = 'ca-app-pub-3940256099942544/6300978111';
      String iosId = 'ca-app-pub-3940256099942544/2934735716';
      bool active = true;
      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        active = data['isActive'] ?? true;
        if (data['androidId']?.toString().isNotEmpty ?? false)
          androidId = data['androidId'];
        if (data['iosId']?.toString().isNotEmpty ?? false)
          iosId = data['iosId'];
      }
      if (!active) return;

      if (kIsWeb) {
        if (mounted)
          setState(() {
            _isLoaded = true;
            _isActive = true;
          });
        return;
      }

      _bannerAd = BannerAd(
        adUnitId: defaultTargetPlatform == TargetPlatform.android
            ? androidId
            : iosId,
        request: const AdRequest(),
        size: AdSize.banner,
        listener: BannerAdListener(
          onAdLoaded: (ad) {
            if (mounted)
              setState(() {
                _isLoaded = true;
                _isActive = true;
              });
          },
          onAdFailedToLoad: (ad, err) {
            ad.dispose();
          },
        ),
      )..load();
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _bannerAd?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoaded && _isActive) {
      if (kIsWeb) {
        // Google AdSense İçin Web Boşluğu
        return Container(
          alignment: Alignment.center,
          width: double.infinity,
          height: 90,
          margin: const EdgeInsets.only(bottom: 8, top: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            tr('adsense_placeholder_area'),
            style: LocalFonts.poppins(color: Colors.grey),
          ),
        );
      }
      if (_bannerAd != null) {
        return Container(
          alignment: Alignment.center,
          width: _bannerAd!.size.width.toDouble(),
          height: _bannerAd!.size.height.toDouble(),
          margin: const EdgeInsets.only(bottom: 8, top: 4),
          child: AdWidget(ad: _bannerAd!),
        );
      }
    }
    return const SizedBox(height: 8);
  }
}
