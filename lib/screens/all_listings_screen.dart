import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../services/banner_ad_settings_service.dart';
import '../utils/theme_colors.dart';
import '../utils/turkey_locations.dart';
import '../utils/translations.dart';
import 'listing_detail_screen.dart';
import 'listing_comparison_screen.dart';

class AllListingsScreen extends StatefulWidget {
  final Map<String, dynamic>? initialFilters;
  final bool urgentOnly;
  final String? customTitle;

  const AllListingsScreen({
    super.key,
    this.initialFilters,
    this.urgentOnly = false,
    this.customTitle,
  });

  @override
  State<AllListingsScreen> createState() => _AllListingsScreenState();
}

class _AllListingsScreenState extends State<AllListingsScreen> {
  Widget _distanceBadge(String distanceText) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.location_on, color: Colors.blue[800], size: 11),
          const SizedBox(width: 3),
          Text(
            distanceText,
            style: LocalFonts.poppins(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: Colors.blue[800],
            ),
          ),
        ],
      ),
    );
  }

  String _filterCategoryName = "Tümü";
  String _currentParentId = "";
  String _currentParentName = "Tümü";
  bool _urgentOnly = false;
  String _sortBy = 'date_desc';
  int? _createdWithinHours;
  double _distance = 30.0;
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  final TextEditingController _neighborhoodController = TextEditingController();

  String? _filterCity;
  String? _filterDistrict;
  String? _filterNeighborhood;
  Position? _userPosition;
  bool _isGridView = false;
  QuerySnapshot? _cachedListingsSnapshot;
  final Map<String, Map<String, dynamic>> _selectedListings = {};

  void _toggleComparisonSelection(String listingId, Map<String, dynamic> data) {
    if (_selectedListings.containsKey(listingId)) {
      setState(() => _selectedListings.remove(listingId));
      return;
    }

    if (_selectedListings.length >= 4) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(tr('comparison_limit_reached').replaceFirst('%s', '4')),
        ),
      );
      return;
    }

    setState(() {
      _selectedListings[listingId] = Map<String, dynamic>.from(data);
    });
  }

  Widget _comparisonToggleButton(String listingId, Map<String, dynamic> data) {
    final isSelected = _selectedListings.containsKey(listingId);
    return Material(
      color: isSelected
          ? Colors.blue[800]
          : Colors.white.withValues(alpha: 0.95),
      shape: const CircleBorder(),
      child: IconButton(
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints.tightFor(width: 34, height: 34),
        visualDensity: VisualDensity.compact,
        tooltip: tr(
          isSelected ? 'remove_from_comparison' : 'add_to_comparison',
        ),
        icon: Icon(
          isSelected ? Icons.check_rounded : Icons.compare_arrows_rounded,
          color: isSelected ? Colors.white : Colors.black87,
          size: 20,
        ),
        onPressed: () => _toggleComparisonSelection(listingId, data),
      ),
    );
  }

  void _openComparison() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => ListingComparisonScreen(
          listings: _selectedListings.entries.toList(),
        ),
      ),
    );
  }

  Widget _buildComparisonBar() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                tr(
                  'comparison_selection_count',
                ).replaceFirst('%s', _selectedListings.length.toString()),
                style: LocalFonts.poppins(fontWeight: FontWeight.w600),
              ),
            ),
            IconButton(
              onPressed: () => setState(_selectedListings.clear),
              tooltip: tr('clear_selection'),
              icon: const Icon(Icons.clear_all_rounded),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _selectedListings.length >= 2 ? _openComparison : null,
              child: Text(tr('compare_listings')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResultsHeader(int count) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
      child: Row(
        children: [
          Icon(Icons.inventory_2_outlined, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            tr('listing_results_count').replaceFirst('%s', count.toString()),
            style: LocalFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    _getUserLocation();

    // Eğer Arama Alarmı gibi başka bir ekrandan filtrelerle gelindiyse onları uygula
    if (widget.initialFilters != null) {
      _applyInitialFilters(widget.initialFilters!);
    } else {
      _loadPreferences();
    }
  }

  void _applyInitialFilters(Map<String, dynamic> filters) {
    setState(() {
      if (filters['urgentOnly'] != null) {
        _urgentOnly = filters['urgentOnly'] == true;
      }
      if (filters['categoryName'] != null)
        _filterCategoryName = filters['categoryName']
            .toString()
            .split(' > ')
            .last;
      if (filters['categoryRoot'] != null) {
        _filterCategoryName = filters['categoryRoot'].toString().trim();
      }
      if (filters['city'] != null) _filterCity = filters['city'];
      if (filters['district'] != null) _filterDistrict = filters['district'];
      if (filters['neighborhood'] != null) {
        _filterNeighborhood = filters['neighborhood'];
        _neighborhoodController.text = _filterNeighborhood!;
      }
      if (filters['minPrice'] != null && filters['minPrice'] > 0)
        _minPriceController.text = filters['minPrice'].toStringAsFixed(0);
      if (filters['maxPrice'] != null &&
          filters['maxPrice'] < double.infinity &&
          filters['maxPrice'] > 0)
        _maxPriceController.text = filters['maxPrice'].toStringAsFixed(0);
      if (filters['createdWithinHours'] == 24 ||
          filters['createdWithinHours'] == 48) {
        _createdWithinHours = filters['createdWithinHours'] as int;
      }
    });
  }

  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      setState(() {
        _filterCity = prefs.getString('filterCity');
        _filterDistrict = prefs.getString('filterDistrict');
        _filterNeighborhood = prefs.getString('allListingsNeighborhood');
        _neighborhoodController.text = _filterNeighborhood ?? '';
        _distance = prefs.getDouble('allListingsDistance') ?? 30.0;
        _sortBy = prefs.getString('sortBy') ?? 'date_desc';
        final createdWithinHours = prefs.getInt(
          'allListingsCreatedWithinHours',
        );
        _createdWithinHours =
            createdWithinHours == 24 || createdWithinHours == 48
            ? createdWithinHours
            : null;
        _minPriceController.text = prefs.getString('minPrice') ?? "";
        _maxPriceController.text = prefs.getString('maxPrice') ?? "";
      });
    } catch (e) {
      print(e);
    }
  }

  Future<void> _savePreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_filterCity != null) {
        await prefs.setString('filterCity', _filterCity!);
      } else {
        await prefs.remove('filterCity');
      }
      if (_filterDistrict != null) {
        await prefs.setString('filterDistrict', _filterDistrict!);
      } else {
        await prefs.remove('filterDistrict');
      }
      if (_filterNeighborhood != null &&
          _filterNeighborhood!.trim().isNotEmpty) {
        await prefs.setString(
          'allListingsNeighborhood',
          _filterNeighborhood!.trim(),
        );
      } else {
        await prefs.remove('allListingsNeighborhood');
      }
      await prefs.setDouble('allListingsDistance', _distance);
      await prefs.setString('sortBy', _sortBy);
      if (_createdWithinHours == null) {
        await prefs.remove('allListingsCreatedWithinHours');
      } else {
        await prefs.setInt(
          'allListingsCreatedWithinHours',
          _createdWithinHours!,
        );
      }
      await prefs.setString('minPrice', _minPriceController.text);
      await prefs.setString('maxPrice', _maxPriceController.text);
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

  String? _matchFilterLocation(Iterable<String> values, String? candidate) {
    final normalized = (candidate ?? '').toLowerCase().replaceAll('ı', 'i');
    if (normalized.isEmpty) return null;
    for (final value in values) {
      final current = value.toLowerCase().replaceAll('ı', 'i');
      if (current == normalized ||
          current.contains(normalized) ||
          normalized.contains(current)) {
        return value;
      }
    }
    return null;
  }

  Future<void> _useCurrentLocationForFilter(
    void Function(void Function()) setModalState,
  ) async {
    await _getUserLocation();
    final position = _userPosition;
    if (position == null) return;
    final placemarks = await Geocoding().placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );
    if (placemarks.isEmpty) return;
    final place = placemarks.first;
    final city = _matchFilterLocation(
      turkeyLocations.keys,
      place.administrativeArea ?? place.locality,
    );
    if (city == null) return;
    final district = _matchFilterLocation(
      turkeyLocations[city] ?? const <String>[],
      place.subAdministrativeArea ?? place.locality,
    );
    setState(() {
      _filterCity = city;
      _filterDistrict = district;
      _filterNeighborhood = place.subLocality;
      _neighborhoodController.text = place.subLocality ?? '';
    });
    setModalState(() {});
    await _savePreferences();
  }

  Widget _filterSection({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey.shade100),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: LocalFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
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

      // Konum izni varsa, eski konumu (cache) alarak hemen filtrelemeyi aktif hale getiririz
      Position? position = await Geolocator.getLastKnownPosition();
      if (position != null && mounted) {
        setState(() => _userPosition = position);
      }

      // Konum servisi (GPS) açıksa anlık konumu almayı deneriz
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

  DateTime? _createdAt(Map<String, dynamic> listing) {
    final value = listing['createdAt'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    if (value is String) return DateTime.tryParse(value);
    return null;
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

  String _listingLocationText(Map<String, dynamic> data) {
    final city = data['city'];
    final district = data['district'];
    if (city == null || district == null) return '';
    final features = data['features'];
    final neighborhood = features is Map
        ? features['Mahalle']?.toString().trim()
        : null;
    final base =
        '${_formatLocation(city.toString())}, ${_formatLocation(district.toString())}';
    return neighborhood == null || neighborhood.isEmpty
        ? base
        : '$base, ${_formatLocation(neighborhood)}';
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
                    currentPath.isEmpty ? 'Kategori Seçin' : currentPath,
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                ListTile(
                  title: Text(
                    currentPath.isEmpty
                        ? 'Tümü (Filtreyi Sıfırla)'
                        : 'Tüm "$currentPath" İlanları',
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
                        'Alt kategori bulunmuyor.',
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
      useSafeArea: true,
      backgroundColor: const Color(0xFFF5F7FB),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.9,
      ),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 16,
                right: 16,
                top: 8,
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
                        IconButton.filledTonal(
                          style: IconButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: Colors.black87,
                          ),
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    _filterSection(
                      title: tr('price_range'),
                      child: Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _minPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('min_price'),
                                filled: true,
                                fillColor: const Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
                                ),
                              ),
                              onChanged: (val) {
                                setModalState(() {});
                                setState(() {});
                                _savePreferences();
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: TextField(
                              controller: _maxPriceController,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                labelText: tr('max_price'),
                                filled: true,
                                fillColor: const Color(0xFFF7F8FA),
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide.none,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 11,
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
                    ),
                    _filterSection(
                      title: tr('listing_time_filter'),
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          for (final option in <({int? hours, String key})>[
                            (hours: null, key: 'any_date'),
                            (hours: 24, key: 'last_24_hours'),
                            (hours: 48, key: 'last_48_hours'),
                          ])
                            ChoiceChip(
                              label: Text(tr(option.key)),
                              selected: _createdWithinHours == option.hours,
                              onSelected: (selected) {
                                final nextValue = selected
                                    ? option.hours
                                    : null;
                                setModalState(
                                  () => _createdWithinHours = nextValue,
                                );
                                setState(() => _createdWithinHours = nextValue);
                                _savePreferences();
                              },
                              selectedColor: AppColors.primary.withValues(
                                alpha: 0.12,
                              ),
                              side: BorderSide(
                                color: _createdWithinHours == option.hours
                                    ? AppColors.primary.withValues(alpha: 0.45)
                                    : Colors.grey.shade300,
                              ),
                              labelStyle: LocalFonts.poppins(
                                fontSize: 11,
                                fontWeight: _createdWithinHours == option.hours
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                                color: _createdWithinHours == option.hours
                                    ? AppColors.primary
                                    : Colors.black87,
                              ),
                              showCheckmark: false,
                            ),
                        ],
                      ),
                    ),

                    _filterSection(
                      title: tr('distance'),
                      child: Column(
                        children: [
                          Align(
                            alignment: Alignment.centerRight,
                            child: Text(
                              _distance == 30.0
                                  ? tr('all')
                                  : '${_distance.toStringAsFixed(1)} km',
                              style: LocalFonts.poppins(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
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
                            },
                            onChangeEnd: (val) {
                              _savePreferences();
                            },
                          ),
                        ],
                      ),
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
                            '* Konum izni verilmediği için mesafe filtresi çalışmaz. (Tekrar Dene)',
                            style: LocalFonts.poppins(
                              fontSize: 10,
                              color: Colors.red,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ),
                    _filterSection(
                      title: tr('location_filter'),
                      child: Column(
                        children: [
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () =>
                                  _useCurrentLocationForFilter(setModalState),
                              child: Text(tr('use_current_location')),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Row(
                            children: [
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: tr('city'),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
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
                              const SizedBox(width: 8),
                              Expanded(
                                child: DropdownButtonFormField<String>(
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: tr('district'),
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(
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
                          const SizedBox(height: 8),
                          TextField(
                            controller: _neighborhoodController,
                            decoration: InputDecoration(
                              labelText: tr('neighborhood_optional'),
                              filled: true,
                              fillColor: const Color(0xFFF7F8FA),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide.none,
                              ),
                            ),
                            onChanged: (value) {
                              setModalState(() => _filterNeighborhood = value);
                              setState(() => _filterNeighborhood = value);
                              _savePreferences();
                            },
                          ),
                        ],
                      ),
                    ),
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
                    const SizedBox(height: 12),
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
                'Sıralama Ölçütü',
                style: LocalFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.access_time),
                title: Text(
                  'En Yeni İlanlar',
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'date_desc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'date_desc'
                    ? Icon(Icons.check, color: Colors.blue[800])
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
                  'En Eski İlanlar',
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'date_asc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'date_asc'
                    ? Icon(Icons.check, color: Colors.blue[800])
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
                  'Fiyat: Düşükten Yükseğe',
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'price_asc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'price_asc'
                    ? Icon(Icons.check, color: Colors.blue[800])
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
                  'Fiyat: Yüksekten Düşüğe',
                  style: LocalFonts.poppins(
                    fontWeight: _sortBy == 'price_desc'
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                ),
                trailing: _sortBy == 'price_desc'
                    ? Icon(Icons.check, color: Colors.blue[800])
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
    final currentUserId = FirebaseAuth.instance.currentUser?.uid;
    final double screenWidth = MediaQuery.sizeOf(context).width;
    final int crossAxisCount = screenWidth > 1200
        ? 5
        : (screenWidth > 800 ? 4 : (screenWidth > 600 ? 3 : 2));
    final double gridAspectRatio = screenWidth > 600 ? 0.8 : 0.72;
    final String pageTitle =
        widget.customTitle ?? (_urgentOnly ? 'Acil İlanlar' : 'Tüm İlanlar');

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        centerTitle: false,
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.white,
        elevation: 0,
        title: Text(
          pageTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: LocalFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        actions: [
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: AppColors.primary.withValues(alpha: 0.08),
              foregroundColor: AppColors.primary,
            ),
            icon: Icon(
              _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
            ),
            tooltip: _isGridView ? 'Liste görünümü' : 'Izgara görünümü',
            onPressed: () {
              setState(() => _isGridView = !_isGridView);
            },
          ),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            icon: const Icon(Icons.sort_rounded),
            onPressed: _showSortModal,
          ),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
            ),
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showFilterModal,
          ),
        ],
      ),
      bottomNavigationBar: _selectedListings.isEmpty
          ? null
          : _buildComparisonBar(),
      body: SafeArea(
        child: StreamBuilder<DocumentSnapshot>(
          stream: currentUserId == null
              ? null
              : FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUserId)
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
              initialData: _cachedListingsSnapshot,
              builder: (context, snapshot) {
                if (!snapshot.hasData)
                  return const Center(child: CircularProgressIndicator());
                _cachedListingsSnapshot = snapshot.data;

                var filteredDocs = snapshot.data!.docs.where((doc) {
                  var data = doc.data() as Map<String, dynamic>;
                  if (hiddenUsers.contains(data['sellerId']))
                    return false; // YENİ: Engellenenleri gizle
                  final ts = data['urgentUntil'] as Timestamp?;
                  final isUrgentActive =
                      data['isUrgent'] == true &&
                      ts != null &&
                      ts.toDate().isAfter(DateTime.now());

                  // Acil ilanlar sadece acil sayfasında listelensin.
                  if (_urgentOnly) {
                    if (!isUrgentActive) return false;
                  } else {
                    // Sadece aktif acilleri gizle; süresi bitenler normal akışa geri düşsün.
                    if (isUrgentActive) return false;
                  }
                  final categoryText =
                      '${data['categoryPath'] ?? ''} ${data['category'] ?? ''}';
                  final matchCategory =
                      _filterCategoryName == 'Tümü' ||
                      categoryText.contains(_filterCategoryName);
                  bool matchCity =
                      _filterCity == null || data['city'] == _filterCity;
                  bool matchDistrict =
                      _filterDistrict == null ||
                      data['district'] == _filterDistrict;
                  final features = data['features'];
                  final listingNeighborhood = features is Map
                      ? features['Mahalle']?.toString().trim() ?? ''
                      : '';
                  final requestedNeighborhood =
                      _filterNeighborhood?.trim().toLowerCase() ?? '';
                  final matchNeighborhood =
                      requestedNeighborhood.isEmpty ||
                      listingNeighborhood.toLowerCase().contains(
                        requestedNeighborhood,
                      );
                  bool matchDistance = true;
                  if (_distance < 30.0) {
                    final num? lat = data['lat'] as num?;
                    final num? lng = data['lng'] as num?;
                    if (_userPosition != null && lat != null && lng != null) {
                      double dist = Geolocator.distanceBetween(
                        _userPosition!.latitude,
                        _userPosition!.longitude,
                        lat.toDouble(),
                        lng.toDouble(),
                      );
                      if ((dist / 1000) > _distance) matchDistance = false;
                    } else {
                      matchDistance = false;
                    }
                  }
                  bool matchPrice = true;
                  double listingPrice =
                      double.tryParse(data['price'].toString()) ?? 0.0;
                  double? minP = double.tryParse(_minPriceController.text);
                  double? maxP = double.tryParse(_maxPriceController.text);
                  if (minP != null && listingPrice < minP) matchPrice = false;
                  if (maxP != null && listingPrice > maxP) matchPrice = false;
                  bool matchCreatedAt = true;
                  if (_createdWithinHours != null) {
                    final createdAt = _createdAt(data);
                    final cutoff = DateTime.now().subtract(
                      Duration(hours: _createdWithinHours!),
                    );
                    matchCreatedAt =
                        createdAt != null && !createdAt.isBefore(cutoff);
                  }

                  return matchCategory &&
                      matchDistance &&
                      matchCity &&
                      matchDistrict &&
                      matchNeighborhood &&
                      matchPrice &&
                      matchCreatedAt;
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

                if (filteredDocs.isEmpty) {
                  return Center(
                    child: Container(
                      margin: const EdgeInsets.all(24),
                      padding: const EdgeInsets.all(28),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.search_off_rounded,
                            size: 44,
                            color: Colors.grey[400],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Aradığınız kriterde ilan bulunamadı.',
                            textAlign: TextAlign.center,
                            style: LocalFonts.poppins(
                              color: Colors.grey[700],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }

                return Column(
                  children: [
                    _buildResultsHeader(filteredDocs.length),
                    Expanded(
                      child: _isGridView
                          ? GridView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 4, 16, 18),
                              gridDelegate:
                                  SliverGridDelegateWithFixedCrossAxisCount(
                                    crossAxisCount: crossAxisCount,
                                    childAspectRatio: gridAspectRatio,
                                    crossAxisSpacing: 12,
                                    mainAxisSpacing: 12,
                                  ),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final listingId = filteredDocs[index].id;
                                var data =
                                    filteredDocs[index].data()
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
                                    data['imageUrl'].toString().isNotEmpty) {
                                  allImages.add(data['imageUrl'].toString());
                                }
                                if (data['additionalImages'] != null) {
                                  for (var img in data['additionalImages']) {
                                    if (img.toString().isNotEmpty) {
                                      allImages.add(img.toString());
                                    }
                                  }
                                }
                                if (allImages.isEmpty) allImages.add('');
                                String distanceText = '';
                                if (_distance < 30.0 &&
                                    _userPosition != null &&
                                    data['lat'] is num &&
                                    data['lng'] is num) {
                                  final distance =
                                      Geolocator.distanceBetween(
                                        _userPosition!.latitude,
                                        _userPosition!.longitude,
                                        (data['lat'] as num).toDouble(),
                                        (data['lng'] as num).toDouble(),
                                      ) /
                                      1000;
                                  distanceText =
                                      '${distance.toStringAsFixed(1)} km';
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
                                    clipBehavior: Clip.antiAlias,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.07,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.grey.shade100,
                                      ),
                                    ),
                                    child: Stack(
                                      children: [
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Expanded(
                                              child: ClipRRect(
                                                borderRadius:
                                                    const BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                                child: Stack(
                                                  fit: StackFit.expand,
                                                  children: [
                                                    if (allImages.first.isEmpty)
                                                      Container(
                                                        color: Colors.grey[200],
                                                        alignment:
                                                            Alignment.center,
                                                        child: const Icon(
                                                          Icons.image,
                                                          color: Colors.grey,
                                                        ),
                                                      )
                                                    else
                                                      Image.network(
                                                        allImages.first,
                                                        width: double.infinity,
                                                        fit: BoxFit.cover,
                                                      ),
                                                    if (distanceText.isNotEmpty)
                                                      Positioned(
                                                        top: 6,
                                                        left: 6,
                                                        child: _distanceBadge(
                                                          distanceText,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                            Padding(
                                              padding:
                                                  const EdgeInsets.fromLTRB(
                                                    10,
                                                    10,
                                                    10,
                                                    48,
                                                  ),
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    data['title'] ?? '',
                                                    maxLines: 2,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: LocalFonts.poppins(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      fontSize: 13,
                                                      color: Colors.black87,
                                                      height: 1.15,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  SizedBox(
                                                    height: 30,
                                                    child: Row(
                                                      children: [
                                                        Text(
                                                          '₺$formattedPrice',
                                                          maxLines: 1,
                                                          softWrap: false,
                                                          style:
                                                              LocalFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .blue[800],
                                                                fontSize: 16,
                                                              ),
                                                        ),
                                                        if (distanceText
                                                            .isNotEmpty) ...[
                                                          const SizedBox(
                                                            width: 8,
                                                          ),
                                                          _distanceBadge(
                                                            distanceText,
                                                          ),
                                                        ],
                                                      ],
                                                    ),
                                                  ),
                                                  const SizedBox(height: 2),
                                                  SizedBox(
                                                    height: 16,
                                                    child: Text(
                                                      data['city'] != null &&
                                                              data['district'] !=
                                                                  null
                                                          ? _listingLocationText(
                                                              data,
                                                            )
                                                          : '',
                                                      maxLines: 1,
                                                      overflow:
                                                          TextOverflow.ellipsis,
                                                      style: LocalFonts.poppins(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Positioned(
                                          right: 8,
                                          bottom: 8,
                                          child: _comparisonToggleButton(
                                            listingId,
                                            data,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            )
                          : ListView.separated(
                              padding: const EdgeInsets.all(16),
                              itemCount: filteredDocs.length,
                              separatorBuilder: (context, index) =>
                                  (index + 1) % 5 == 0
                                  ? const BannerAdWidget()
                                  : const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final listingId = filteredDocs[index].id;
                                var data =
                                    filteredDocs[index].data()
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
                                final ts = data['urgentUntil'] as Timestamp?;
                                final bool isUrgent =
                                    data['isUrgent'] == true &&
                                    ts != null &&
                                    ts.toDate().isAfter(DateTime.now());
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
                                    height: 136,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(16),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withValues(
                                            alpha: 0.07,
                                          ),
                                          blurRadius: 14,
                                          offset: const Offset(0, 5),
                                        ),
                                      ],
                                      border: Border.all(
                                        color: Colors.grey.shade100,
                                      ),
                                    ),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: isUrgent
                                            ? Border.all(
                                                color: Colors.red.shade300,
                                                width: 2,
                                              )
                                            : (isCatShowcased
                                                  ? Border.all(
                                                      color: Colors
                                                          .orange
                                                          .shade300,
                                                      width: 2,
                                                    )
                                                  : null),
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      child: Stack(
                                        children: [
                                          Padding(
                                            padding: EdgeInsets.only(
                                              top: isUrgent ? 18 : 0,
                                            ),
                                            child: Row(
                                              children: [
                                                ClipRRect(
                                                  borderRadius:
                                                      const BorderRadius.horizontal(
                                                        left: Radius.circular(
                                                          16,
                                                        ),
                                                      ),
                                                  child: SizedBox(
                                                    width: 115,
                                                    height: isUrgent
                                                        ? 118
                                                        : 136,
                                                    child: Stack(
                                                      fit: StackFit.expand,
                                                      children: [
                                                        if (allImages
                                                            .first
                                                            .isEmpty)
                                                          const Icon(
                                                            Icons.image,
                                                            color: Colors.grey,
                                                          )
                                                        else
                                                          PageView.builder(
                                                            itemCount: allImages
                                                                .length,
                                                            itemBuilder:
                                                                (
                                                                  context,
                                                                  imgIndex,
                                                                ) => Image.network(
                                                                  allImages[imgIndex],
                                                                  fit: BoxFit
                                                                      .cover,
                                                                ),
                                                          ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                                Expanded(
                                                  child: Padding(
                                                    padding:
                                                        const EdgeInsets.fromLTRB(
                                                          10,
                                                          8,
                                                          48,
                                                          8,
                                                        ),
                                                    child: Column(
                                                      crossAxisAlignment:
                                                          CrossAxisAlignment
                                                              .start,
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .start,
                                                      children: [
                                                        Text(
                                                          data['title'] ?? '',
                                                          maxLines: 2,
                                                          overflow: TextOverflow
                                                              .ellipsis,
                                                          style:
                                                              LocalFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .w600,
                                                                fontSize: 15,
                                                                color: Colors
                                                                    .black87,
                                                                height: 1.1,
                                                              ),
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        Row(
                                                          crossAxisAlignment:
                                                              CrossAxisAlignment
                                                                  .center,
                                                          children: [
                                                            Text(
                                                              '₺$formattedPrice',
                                                              maxLines: 1,
                                                              softWrap: false,
                                                              style: LocalFonts.poppins(
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                                color: Colors
                                                                    .blue[800],
                                                                fontSize: 17,
                                                              ),
                                                            ),
                                                            if (isCatShowcased)
                                                              Padding(
                                                                padding:
                                                                    const EdgeInsets.only(
                                                                      left: 8.0,
                                                                    ),
                                                                child: Container(
                                                                  padding:
                                                                      const EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            6,
                                                                        vertical:
                                                                            2,
                                                                      ),
                                                                  decoration: BoxDecoration(
                                                                    color: Colors
                                                                        .orange,
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          4,
                                                                        ),
                                                                  ),
                                                                  child: Text(
                                                                    'Öne Çıkan',
                                                                    style: LocalFonts.poppins(
                                                                      color: Colors
                                                                          .white,
                                                                      fontSize:
                                                                          8,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                              ),
                                                          ],
                                                        ),
                                                        const SizedBox(
                                                          height: 2,
                                                        ),
                                                        SizedBox(
                                                          height: 18,
                                                          child: Text(
                                                            data['city'] !=
                                                                        null &&
                                                                    data['district'] !=
                                                                        null
                                                                ? _listingLocationText(
                                                                    data,
                                                                  )
                                                                : '',
                                                            maxLines: 1,
                                                            overflow:
                                                                TextOverflow
                                                                    .ellipsis,
                                                            style:
                                                                LocalFonts.poppins(
                                                                  fontSize: 12,
                                                                  color: Colors
                                                                      .grey[600],
                                                                ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (isUrgent)
                                            Positioned(
                                              top: 0,
                                              left: 0,
                                              right: 0,
                                              child: Container(
                                                height: 20,
                                                decoration: BoxDecoration(
                                                  gradient:
                                                      const LinearGradient(
                                                        colors: [
                                                          Color(0xFFE53935),
                                                          Color(0xFFC62828),
                                                        ],
                                                      ),
                                                  borderRadius:
                                                      const BorderRadius.vertical(
                                                        top: Radius.circular(
                                                          14,
                                                        ),
                                                      ),
                                                ),
                                                child: Row(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    const Icon(
                                                      Icons
                                                          .notifications_active,
                                                      color: Colors.white,
                                                      size: 11,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      'ACİL İLAN',
                                                      style: LocalFonts.poppins(
                                                        color: Colors.white,
                                                        fontSize: 9,
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          Positioned(
                                            right: 8,
                                            bottom: 8,
                                            child: _comparisonToggleButton(
                                              listingId,
                                              data,
                                            ),
                                          ),
                                        ],
                                      ),
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
          },
        ),
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
    _fetchAdSettingsAndLoad();
  }

  Future<void> _fetchAdSettingsAndLoad() async {
    try {
      if (kIsWeb) return;
      final settings = await BannerAdSettings.load();
      if (!settings.isActive) return;
      _bannerAd = BannerAd(
        adUnitId: defaultTargetPlatform == TargetPlatform.android
            ? settings.androidId
            : settings.iosId,
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
        margin: const EdgeInsets.symmetric(vertical: 8),
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox(height: 8);
  }
}
