import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../utils/turkey_locations.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';
import 'listing_detail_screen.dart';

class NearbyListingsScreen extends StatefulWidget {
  const NearbyListingsScreen({super.key});

  @override
  State<NearbyListingsScreen> createState() => _NearbyListingsScreenState();
}

class _NearbyListingsScreenState extends State<NearbyListingsScreen> {
  String _filterCategoryName = "Tümü";
  String _currentParentId = "";
  String _currentParentName = "Tümü";
  String _sortBy = 'distance_asc'; // Varsayılan: Yakından Uzağa
  double _distance = 30.0;
  bool _isGridView = false;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();

  String? _filterCity;
  String? _filterDistrict;
  String? _filterNeighborhood;
  Position? _userPosition;

  @override
  void initState() {
    super.initState();
    _getUserLocation();
    _loadPreferences();
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _filterCity = prefs.getString('nearby_filterCity');
        _filterDistrict = prefs.getString('nearby_filterDistrict');
        _distance = prefs.getDouble('nearby_distance') ?? 30.0;
        _sortBy = prefs.getString('nearby_sortBy') ?? 'distance_asc';
        _isGridView = prefs.getBool('nearby_isGridView') ?? false;
        _minPriceController.text = prefs.getString('nearby_minPrice') ?? "";
        _maxPriceController.text = prefs.getString('nearby_maxPrice') ?? "";
        _filterNeighborhood = prefs.getString('nearby_filterNeighborhood');
        _neighborhoodController.text = _filterNeighborhood ?? "";
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_filterCity != null) {
        await prefs.setString('nearby_filterCity', _filterCity!);
      } else {
        await prefs.remove('nearby_filterCity');
      }
      if (_filterDistrict != null) {
        await prefs.setString('nearby_filterDistrict', _filterDistrict!);
      } else {
        await prefs.remove('nearby_filterDistrict');
      }
      await prefs.setDouble('nearby_distance', _distance);
      await prefs.setString('nearby_sortBy', _sortBy);
      await prefs.setBool('nearby_isGridView', _isGridView);
      await prefs.setString('nearby_minPrice', _minPriceController.text);
      await prefs.setString('nearby_maxPrice', _maxPriceController.text);
      if (_filterNeighborhood != null && _filterNeighborhood!.isNotEmpty) {
        await prefs.setString(
          'nearby_filterNeighborhood',
          _filterNeighborhood!,
        );
      } else if (_neighborhoodController.text.isNotEmpty) {
        await prefs.setString(
          'nearby_filterNeighborhood',
          _neighborhoodController.text,
        );
      } else {
        await prefs.remove('nearby_filterNeighborhood');
      }
    } catch (e) {
      print(e);
    }
  }

  @override
  void dispose() {
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _neighborhoodController.dispose();
    super.dispose();
  }

  Future<void> _getUserLocation() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever)
        return;

      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() => _userPosition = position);
      }

      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (serviceEnabled) {
        position = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.low,
          timeLimit: const Duration(seconds: 10),
        );
        if (mounted) setState(() => _userPosition = position);
      }
    } catch (e) {
      print(e);
    }
  }

  String _formatLocation(String? text) {
    if (text == null || text.isEmpty) return '';
    return text
        .split(' ')
        .map((word) {
          if (word.isEmpty) return '';
          return word[0].toUpperCase() + word.substring(1).toLowerCase();
        })
        .join(' ');
  }

  void _showCategoryPickerForFilter(String parentId, String currentPath) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StreamBuilder<QuerySnapshot>(
          stream: DatabaseService().getCategoriesStream(parentId),
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
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    currentPath.isEmpty ? tr('select_category') : currentPath,
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    currentPath.isEmpty
                        ? tr('all_reset_filter')
                        : '${tr('all')} "$currentPath"',
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.green[700],
                    ),
                  ),
                  trailing: const Icon(Icons.check, color: Colors.green),
                  onTap: () {
                    setState(() {
                      _filterCategoryName = currentPath.isEmpty
                          ? 'Tümü'
                          : currentPath.split(' > ').last;
                      if (_filterCategoryName == 'Tümü') {
                        _currentParentId = "";
                        _currentParentName = "Tümü";
                      } else {
                        _currentParentId = parentId;
                        _currentParentName = _filterCategoryName;
                      }
                    });
                    _savePreferences();
                    Navigator.pop(context);
                    _showFilterModal();
                  },
                ),
                const Divider(),
                if (docs.isEmpty)
                  Expanded(
                    child: Center(
                      child: Text(
                        tr('no_subcategories'),
                        style: LocalFonts.poppins(),
                      ),
                    ),
                  ),
                if (docs.isNotEmpty)
                  Expanded(
                    child: ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        String clickedId = docs[index].id;
                        String originalName = docs[index]['name'];
                        return ListTile(
                          title: Text(
                            originalName,
                            style: LocalFonts.poppins(),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () async {
                            String newPath = currentPath.isEmpty
                                ? originalName
                                : "$currentPath > $originalName";
                            Navigator.pop(context);

                            var subCats = await FirebaseFirestore.instance
                                .collection('categories')
                                .where('parentId', isEqualTo: clickedId)
                                .limit(1)
                                .get();
                            if (subCats.docs.isEmpty) {
                              setState(() {
                                _filterCategoryName = newPath.split(' > ').last;
                                _currentParentId = clickedId;
                                _currentParentName = _filterCategoryName;
                              });
                              _savePreferences();
                              if (context.mounted) _showFilterModal();
                            } else {
                              if (context.mounted)
                                _showCategoryPickerForFilter(
                                  clickedId,
                                  newPath,
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

  void _showFilterModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('filter'),
                          style: LocalFonts.poppins(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const Divider(),
                    const SizedBox(height: 10),

                    Text(
                      tr('price_range'),
                      style: LocalFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _minPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('min_price'),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {});
                              setState(() {});
                              _savePreferences();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextField(
                            controller: _maxPriceController,
                            keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: tr('max_price'),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            onChanged: (val) {
                              setModalState(() {});
                              setState(() {});
                              _savePreferences();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          tr('distance'),
                          style: LocalFonts.poppins(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                          ),
                        ),
                        Text(
                          _distance == 30.0
                              ? tr('all')
                              : '${_distance.toStringAsFixed(1)} km',
                          style: LocalFonts.poppins(
                            color: AppColors.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    Slider(
                      value: _distance,
                      min: 0.1,
                      max: 30.0,
                      divisions: 300,
                      activeColor: AppColors.primary,
                      onChanged: (val) {
                        setModalState(() => _distance = val);
                        setState(() => _distance = val);
                        _savePreferences();
                      },
                    ),
                    if (_userPosition == null)
                      InkWell(
                        onTap: () async {
                          await _getUserLocation();
                          setModalState(() {});
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Text(
                            '${tr('location_permission_warning')} (Tekrar Dene)',
                            style: LocalFonts.poppins(
                              fontSize: 10,
                              color: Colors.red,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),

                    Text(
                      tr('location_filter'),
                      style: LocalFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('city'),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            initialValue: _filterCity,
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(tr('all')),
                              ),
                              ...turkeyLocations.keys.map(
                                (city) => DropdownMenuItem(
                                  value: city,
                                  child: Text(
                                    city,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),
                            ],
                            onChanged: (val) {
                              setModalState(() {
                                _filterCity = val;
                                _filterDistrict = null;
                                _filterNeighborhood = null;
                                _neighborhoodController.clear();
                              });
                              setState(() {
                                _filterCity = val;
                                _filterDistrict = null;
                                _filterNeighborhood = null;
                                _neighborhoodController.clear();
                              });
                              _savePreferences();
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: DropdownButtonFormField<String>(
                            isExpanded: true,
                            decoration: InputDecoration(
                              labelText: tr('district'),
                              border: const OutlineInputBorder(),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 12,
                              ),
                            ),
                            initialValue: _filterDistrict,
                            items: [
                              DropdownMenuItem(
                                value: null,
                                child: Text(tr('all')),
                              ),
                              if (_filterCity != null)
                                ...turkeyLocations[_filterCity]!.map(
                                  (d) => DropdownMenuItem(
                                    value: d,
                                    child: Text(
                                      d,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ),
                            ],
                            onChanged: (val) {
                              setModalState(() => _filterDistrict = val);
                              setState(() => _filterDistrict = val);
                              _savePreferences();
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: _neighborhoodController,
                      decoration: InputDecoration(
                        labelText: tr('neighborhood_optional'),
                        border: const OutlineInputBorder(),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 12,
                        ),
                      ),
                      onChanged: (val) {
                        setModalState(() => _filterNeighborhood = val);
                        setState(() => _filterNeighborhood = val);
                        _savePreferences();
                      },
                    ),
                    const SizedBox(height: 24),

                    Text(
                      tr('category_selection'),
                      style: LocalFonts.poppins(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 8),
                    InkWell(
                      onTap: () {
                        Navigator.pop(context);
                        _showCategoryPickerForFilter("", "");
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _filterCategoryName,
                              style: LocalFonts.poppins(fontSize: 15),
                            ),
                            const Icon(
                              Icons.arrow_drop_down,
                              color: Colors.grey,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        minimumSize: const Size(double.infinity, 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        tr('show_results'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showSortModal() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tr('sort_criteria'),
                style: LocalFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.location_on),
                title: Text(
                  'En Yakın İlanlar',
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'distance_asc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'distance_asc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = 'distance_asc');
                  _savePreferences();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  tr('newest_listings'),
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'date_desc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'date_desc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = 'date_desc');
                  _savePreferences();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  tr('oldest_listings'),
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'date_asc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'date_asc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = 'date_asc');
                  _savePreferences();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_upward),
                title: Text(
                  tr('price_low_to_high'),
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'price_asc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'price_asc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = 'price_asc');
                  _savePreferences();
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_downward),
                title: Text(
                  tr('price_high_to_low'),
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'price_desc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'price_desc'
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () {
                  setState(() => _sortBy = 'price_desc');
                  _savePreferences();
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = screenWidth > 1200
        ? 5
        : (screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2));
    final double gridAspectRatio = screenWidth > 600 ? 0.8 : 0.72;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('nearby_listings'),
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              color: Colors.black87,
            ),
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
              _savePreferences();
            },
          ),
          IconButton(
            icon: const Icon(Icons.sort_rounded, color: Colors.black87),
            onPressed: _showSortModal,
          ),
          IconButton(
            icon: const Icon(Icons.tune_rounded, color: Colors.black87),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(FirebaseAuth.instance.currentUser!.uid)
            .snapshots(),
        builder: (context, userSnap) {
          List<String> hiddenUsers = [];
          if (userSnap.hasData && userSnap.data!.exists) {
            var userData = userSnap.data!.data() as Map<String, dynamic>;
            hiddenUsers = [
              ...List<String>.from(userData['blockedUsers'] ?? []),
              ...List<String>.from(userData['blockedBy'] ?? []),
            ];
          }
          return StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance
                .collection('listings')
                .where('status', isEqualTo: 'active')
                .snapshots(),
            builder: (context, snapshot) {
              if (!snapshot.hasData)
                return const Center(child: CircularProgressIndicator());

              var filteredDocs = snapshot.data!.docs.where((doc) {
                var data = doc.data() as Map<String, dynamic>;
                if (hiddenUsers.contains(data['sellerId'])) return false;
                bool matchCategory =
                    (_filterCategoryName == 'Tümü' ||
                    (data['categoryPath']?.toString().contains(
                          _filterCategoryName,
                        ) ??
                        false));
                bool matchCity =
                    _filterCity == null || data['city'] == _filterCity;
                bool matchDistrict =
                    _filterDistrict == null ||
                    data['district'] == _filterDistrict;
                bool matchNeighborhood = true;
                if (_filterNeighborhood != null &&
                    _filterNeighborhood!.isNotEmpty) {
                  Map<String, dynamic>? listingFeatures =
                      data['features'] != null
                      ? Map<String, dynamic>.from(data['features'])
                      : null;
                  String? listingMahalle = listingFeatures?['Mahalle']
                      ?.toString();
                  if (listingMahalle == null ||
                      !listingMahalle.toLowerCase().contains(
                        _filterNeighborhood!.toLowerCase(),
                      )) {
                    matchNeighborhood = false;
                  }
                }
                bool matchDistance = true;
                if (_distance < 30.0 && _userPosition != null) {
                  double? lat = data['lat'];
                  double? lng = data['lng'];
                  if (lat != null && lng != null) {
                    double dist = Geolocator.distanceBetween(
                      _userPosition!.latitude,
                      _userPosition!.longitude,
                      lat,
                      lng,
                    );
                    if ((dist / 1000) > _distance) matchDistance = false;
                  }
                }
                bool matchPrice = true;
                double listingPrice =
                    double.tryParse(data['price'].toString()) ?? 0.0;
                double? minP = double.tryParse(_minPriceController.text);
                double? maxP = double.tryParse(_maxPriceController.text);
                if (minP != null && listingPrice < minP) matchPrice = false;
                if (maxP != null && listingPrice > maxP) matchPrice = false;

                return matchCategory &&
                    matchDistance &&
                    matchCity &&
                    matchDistrict &&
                    matchNeighborhood &&
                    matchPrice;
              }).toList();

              filteredDocs.sort((a, b) {
                var dataA = a.data() as Map<String, dynamic>;
                var dataB = b.data() as Map<String, dynamic>;
                bool aCatShowcase =
                    _filterCategoryName != 'Tümü' &&
                    dataA['categoryShowcaseUntil'] != null &&
                    (dataA['categoryShowcaseUntil'] as Timestamp)
                        .toDate()
                        .isAfter(DateTime.now());
                bool bCatShowcase =
                    _filterCategoryName != 'Tümü' &&
                    dataB['categoryShowcaseUntil'] != null &&
                    (dataB['categoryShowcaseUntil'] as Timestamp)
                        .toDate()
                        .isAfter(DateTime.now());
                if (aCatShowcase && !bCatShowcase) return -1;
                if (!aCatShowcase && bCatShowcase) return 1;

                if (_sortBy == 'distance_asc' && _userPosition != null) {
                  double? latA = dataA['lat'];
                  double? lngA = dataA['lng'];
                  double? latB = dataB['lat'];
                  double? lngB = dataB['lng'];
                  if (latA == null || lngA == null) return 1;
                  if (latB == null || lngB == null) return -1;
                  double distA = Geolocator.distanceBetween(
                    _userPosition!.latitude,
                    _userPosition!.longitude,
                    latA,
                    lngA,
                  );
                  double distB = Geolocator.distanceBetween(
                    _userPosition!.latitude,
                    _userPosition!.longitude,
                    latB,
                    lngB,
                  );
                  return distA.compareTo(distB);
                }

                if (_sortBy == 'price_asc')
                  return (dataA['price'] as num).compareTo(
                    dataB['price'] as num,
                  );
                if (_sortBy == 'price_desc')
                  return (dataB['price'] as num).compareTo(
                    dataA['price'] as num,
                  );
                if (_sortBy == 'date_asc')
                  return (dataA['createdAt'] ?? Timestamp.now()).compareTo(
                    dataB['createdAt'] ?? Timestamp.now(),
                  );
                return (dataB['createdAt'] ?? Timestamp.now()).compareTo(
                  dataA['createdAt'] ?? Timestamp.now(),
                );
              });

              if (filteredDocs.isEmpty)
                return Center(
                  child: Text(
                    'Aradığınız kriterde yakınınızda ilan bulunamadı.',
                    style: LocalFonts.poppins(color: Colors.grey),
                  ),
                );

              if (_isGridView) {
                return GridView.builder(
                  padding: const EdgeInsets.all(16),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    childAspectRatio: gridAspectRatio,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    var data =
                        filteredDocs[index].data() as Map<String, dynamic>;
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
                        data['imageUrl'].toString().isNotEmpty)
                      allImages.add(data['imageUrl'].toString());
                    if (data['additionalImages'] != null) {
                      for (var img in data['additionalImages']) {
                        if (img.toString().isNotEmpty)
                          allImages.add(img.toString());
                      }
                    }
                    if (allImages.isEmpty) allImages.add('');
                    bool isCatShowcased =
                        data['categoryShowcaseUntil'] != null &&
                        (data['categoryShowcaseUntil'] as Timestamp)
                            .toDate()
                            .isAfter(DateTime.now());
                    bool isPro = data['isPro'] ?? false;

                    String distanceText = "";
                    if (_userPosition != null &&
                        data['lat'] != null &&
                        data['lng'] != null) {
                      double dist =
                          Geolocator.distanceBetween(
                            _userPosition!.latitude,
                            _userPosition!.longitude,
                            data['lat'],
                            data['lng'],
                          ) /
                          1000;
                      distanceText = '${dist.toStringAsFixed(1)} km';
                    }

                    return InkWell(
                      onTap: () {
                        FocusScope.of(context).unfocus();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ListingDetailScreen(
                              data: data,
                              listingId: filteredDocs[index].id,
                            ),
                          ),
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Container(
                          decoration: isCatShowcased
                              ? BoxDecoration(
                                  border: Border.all(
                                    color: AppColors.secondary.withValues(
                                      alpha: 0.5,
                                    ),
                                    width: 2,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                )
                              : null,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: ClipRRect(
                                  borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(16),
                                  ),
                                  child: SizedBox(
                                    width: double.infinity,
                                    child: allImages.first.isEmpty
                                        ? const Icon(
                                            Icons.image,
                                            color: Colors.grey,
                                          )
                                        : Stack(
                                            fit: StackFit.expand,
                                            children: [
                                              PageView.builder(
                                                itemCount: allImages.length,
                                                itemBuilder:
                                                    (
                                                      context,
                                                      imgIndex,
                                                    ) => Image.network(
                                                      allImages[imgIndex],
                                                      fit: BoxFit.cover,
                                                      errorBuilder: (c, e, s) =>
                                                          const Icon(
                                                            Icons
                                                                .image_not_supported,
                                                            color: Colors.grey,
                                                          ),
                                                    ),
                                              ),
                                              if (distanceText.isNotEmpty)
                                                Positioned(
                                                  top: 6,
                                                  left: 6,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.white
                                                          .withValues(
                                                            alpha: 0.9,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.location_on,
                                                          color:
                                                              AppColors.primary,
                                                          size: 10,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          distanceText,
                                                          style:
                                                              LocalFonts.poppins(
                                                                color: AppColors
                                                                    .primary,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              if (allImages.length > 1)
                                                Positioned(
                                                  bottom: 6,
                                                  right: 6,
                                                  child: Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 6,
                                                          vertical: 3,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.black
                                                          .withValues(
                                                            alpha: 0.65,
                                                          ),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        const Icon(
                                                          Icons.photo_library,
                                                          color: Colors.white,
                                                          size: 12,
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          '${allImages.length}',
                                                          style:
                                                              LocalFonts.poppins(
                                                                color: Colors
                                                                    .white,
                                                                fontSize: 10,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                            ],
                                          ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(
                                          '₺$formattedPrice',
                                          style: LocalFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.blue[900],
                                            fontSize: 16,
                                          ),
                                        ),
                                        const Spacer(),
                                        if (isCatShowcased)
                                          const Icon(
                                            Icons.stars,
                                            color: Colors.orange,
                                            size: 16,
                                          ),
                                        if (isPro)
                                          const Icon(
                                            Icons.verified,
                                            color: AppColors.secondary,
                                            size: 16,
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    Text(
                                      data['title'] ?? '',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: LocalFonts.poppins(
                                        fontSize: 13,
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    if (data['city'] != null &&
                                        data['district'] != null)
                                      Text(
                                        '${_formatLocation(data['city'])}, ${_formatLocation(data['district'])}',
                                        style: LocalFonts.poppins(
                                          fontSize: 10,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filteredDocs.length,
                separatorBuilder: (context, index) => (index + 1) % 5 == 0
                    ? const BannerAdWidget()
                    : const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  var data = filteredDocs[index].data() as Map<String, dynamic>;
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
                      data['imageUrl'].toString().isNotEmpty)
                    allImages.add(data['imageUrl'].toString());
                  if (data['additionalImages'] != null) {
                    for (var img in data['additionalImages']) {
                      if (img.toString().isNotEmpty)
                        allImages.add(img.toString());
                    }
                  }
                  if (allImages.isEmpty) allImages.add('');
                  bool isCatShowcased =
                      data['categoryShowcaseUntil'] != null &&
                      (data['categoryShowcaseUntil'] as Timestamp)
                          .toDate()
                          .isAfter(DateTime.now());

                  String distanceText = "";
                  if (_userPosition != null &&
                      data['lat'] != null &&
                      data['lng'] != null) {
                    double dist =
                        Geolocator.distanceBetween(
                          _userPosition!.latitude,
                          _userPosition!.longitude,
                          data['lat'],
                          data['lng'],
                        ) /
                        1000;
                    distanceText = '${dist.toStringAsFixed(1)} km';
                  }

                  return InkWell(
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ListingDetailScreen(
                          data: data,
                          listingId: filteredDocs[index].id,
                        ),
                      ),
                    ),
                    child: Container(
                      height: 115,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Container(
                        decoration: isCatShowcased
                            ? BoxDecoration(
                                border: Border.all(
                                  color: Colors.orange.shade300,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(16),
                              )
                            : null,
                        child: Row(
                          children: [
                            ClipRRect(
                              borderRadius: const BorderRadius.horizontal(
                                left: Radius.circular(16),
                              ),
                              child: SizedBox(
                                width: 115,
                                height: 115,
                                child: allImages.first.isEmpty
                                    ? const Icon(
                                        Icons.image,
                                        color: Colors.grey,
                                      )
                                    : Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          PageView.builder(
                                            itemCount: allImages.length,
                                            itemBuilder: (context, imgIndex) =>
                                                Image.network(
                                                  allImages[imgIndex],
                                                  fit: BoxFit.cover,
                                                ),
                                          ),
                                          if (distanceText.isNotEmpty)
                                            Positioned(
                                              top: 4,
                                              left: 4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.white
                                                      .withValues(alpha: 0.9),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.location_on,
                                                      color: AppColors.primary,
                                                      size: 8,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      distanceText,
                                                      style: LocalFonts.poppins(
                                                        color:
                                                            AppColors.primary,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          if (allImages.length > 1)
                                            Positioned(
                                              bottom: 4,
                                              right: 4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 4,
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  color: Colors.black
                                                      .withValues(alpha: 0.65),
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    const Icon(
                                                      Icons.photo_library,
                                                      color: Colors.white,
                                                      size: 8,
                                                    ),
                                                    const SizedBox(width: 2),
                                                    Text(
                                                      '${allImages.length}',
                                                      style: LocalFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 8,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                              ),
                            ),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      data['title'] ?? '',
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: LocalFonts.poppins(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 13,
                                        color: Colors.black87,
                                        height: 1.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          '₺$formattedPrice',
                                          style: LocalFonts.poppins(
                                            fontWeight: FontWeight.bold,
                                            color: AppColors.primary,
                                            fontSize: 15,
                                          ),
                                        ),
                                        if (isCatShowcased)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              left: 8.0,
                                            ),
                                            child: Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 6,
                                                    vertical: 2,
                                                  ),
                                              decoration: BoxDecoration(
                                                color: Colors.orange,
                                                borderRadius:
                                                    BorderRadius.circular(4),
                                              ),
                                              child: Text(
                                                tr('highlighted'),
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
                                    const SizedBox(height: 4),
                                    if (data['city'] != null &&
                                        data['district'] != null)
                                      Text(
                                        '${_formatLocation(data['city'])}, ${_formatLocation(data['district'])}',
                                        style: LocalFonts.poppins(
                                          fontSize: 11,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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
            },
          );
        },
      ),
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
      if (kIsWeb) return;
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
    if (_isLoaded && _bannerAd != null && _isActive) {
      return Container(
        alignment: Alignment.center,
        width: _bannerAd!.size.width.toDouble(),
        height: _bannerAd!.size.height.toDouble(),
        margin: const EdgeInsets.symmetric(vertical: 12),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox();
  }
}
