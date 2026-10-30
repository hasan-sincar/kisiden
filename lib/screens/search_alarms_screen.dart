import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../utils/turkey_locations.dart';
import '../utils/translations.dart';
import '../utils/theme_colors.dart';
import 'all_listings_screen.dart';

class SearchAlarmsScreen extends StatefulWidget {
  const SearchAlarmsScreen({super.key});
  @override
  State<SearchAlarmsScreen> createState() => _SearchAlarmsScreenState();
}

class _SearchAlarmsScreenState extends State<SearchAlarmsScreen> {
  final DatabaseService _dbService = DatabaseService();

  void _showAddAlarmModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const AddAlarmModal(),
    );
  }

  Widget _buildAlarmOverview(int count) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 6),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tr('search_alarms_intro'),
                  style: LocalFonts.poppins(
                    color: const Color(0xFF7B8799),
                    fontSize: 11,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tr('search_alarms_count').replaceFirst('%s', '$count'),
                  style: LocalFonts.poppins(
                    color: const Color(0xFF243047),
                    fontSize: 15,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(13),
            ),
            child: const Icon(
              Icons.notifications_active_rounded,
              color: AppColors.primary,
              size: 22,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAlarmCard(QueryDocumentSnapshot alarm) {
    final data = alarm.data() as Map<String, dynamic>;
    final rawPath = data['categoryPath'];
    final categoryPath = rawPath is String ? rawPath : '';
    final categoryName = categoryPath.isEmpty
        ? tr('category')
        : categoryPath.split(' > ').last;
    final city = data['city']?.toString();
    final district = data['district']?.toString();
    final minPrice = data['minPrice'];
    final maxPrice = data['maxPrice'];
    final hasPriceRange = minPrice != null || maxPrice != null;
    final maxIsUnlimited = maxPrice == null || maxPrice == 0;
    final priceText =
        '${minPrice ?? 0}₺ - ${maxIsUnlimited ? tr('unlimited') : '$maxPrice₺'}';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE9EEF6)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF1C2B45).withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 15, 10, 15),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: const Icon(
                Icons.notifications_active_rounded,
                color: AppColors.secondary,
                size: 23,
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    categoryName,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: LocalFonts.poppins(
                      color: const Color(0xFF243047),
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  if (categoryPath.contains(' > ')) ...[
                    const SizedBox(height: 2),
                    Text(
                      categoryPath,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: LocalFonts.poppins(
                        color: const Color(0xFF8994A6),
                        fontSize: 10,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 7,
                    runSpacing: 7,
                    children: [
                      if ((city ?? '').isNotEmpty)
                        _buildAlarmTag(
                          Icons.location_on_outlined,
                          [
                            city,
                            if ((district ?? '').isNotEmpty) district,
                          ].join(' · '),
                          const Color(0xFF28776F),
                        ),
                      if (hasPriceRange)
                        _buildAlarmTag(
                          Icons.payments_outlined,
                          priceText,
                          const Color(0xFF39804C),
                        ),
                    ],
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: tr('delete'),
              onPressed: () => _dbService.deleteSearchAlarm(alarm.id),
              style: IconButton.styleFrom(
                foregroundColor: Colors.red.shade400,
                backgroundColor: Colors.red.withValues(alpha: 0.06),
                visualDensity: VisualDensity.compact,
              ),
              icon: const Icon(Icons.delete_outline_rounded, size: 21),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlarmTag(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: LocalFonts.poppins(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 94,
              height: 94,
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.07),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.notifications_none_rounded,
                size: 48,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              tr('no_alarms_set'),
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(
                color: const Color(0xFF243047),
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              tr('search_alarms_empty_hint'),
              textAlign: TextAlign.center,
              style: LocalFonts.poppins(
                color: const Color(0xFF7B8799),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Colors.grey[50],
        elevation: 0,
        title: Text(
          tr('search_alarms'),
          style: LocalFonts.poppins(
            color: const Color(0xFF243047),
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('search_alarms')
              .where('userId', isEqualTo: uid)
              .orderBy('createdAt', descending: true)
              .snapshots(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tr('search_alarms_load_failed'),
                    textAlign: TextAlign.center,
                    style: LocalFonts.poppins(color: Colors.red.shade700),
                  ),
                ),
              );
            }
            if (!snapshot.hasData) {
              return const Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              );
            }

            final alarms = snapshot.data!.docs;
            return Column(
              children: [
                _buildAlarmOverview(alarms.length),
                Expanded(
                  child: alarms.isEmpty
                      ? _buildEmptyState()
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
                          itemCount: alarms.length,
                          itemBuilder: (context, index) =>
                              _buildAlarmCard(alarms[index]),
                        ),
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAlarmModal,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 3,
        icon: const Icon(Icons.add_alert_rounded),
        label: Text(
          tr('set_alarm'),
          style: LocalFonts.poppins(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}

class AddAlarmModal extends StatefulWidget {
  const AddAlarmModal({super.key});
  @override
  State<AddAlarmModal> createState() => _AddAlarmModalState();
}

class _AddAlarmModalState extends State<AddAlarmModal> {
  final DatabaseService _dbService = DatabaseService();
  String? _selectedCategoryId;
  String _fullCategoryPath = "";
  String _fullCategoryDisplayPath = "";
  final TextEditingController _minPriceController = TextEditingController();
  final TextEditingController _maxPriceController = TextEditingController();
  String? _selectedCity;
  String? _selectedDistrict;

  final List<Map<String, dynamic>> _categoryFeatures = [];
  final Map<String, String?> _featureDropdownValues = {};

  // ÇÖZÜM: Kategori seçildiğinde o kategoriye ait ek özellikleri getirir
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
        _featureDropdownValues.clear();
        for (var f in rawFeatures) {
          if (f is Map) {
            String name = f['name'];
            List<String> options = List<String>.from(f['options'] ?? []);
            if (options.isNotEmpty) {
              _categoryFeatures.add({'name': name, 'options': options});
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
  ]) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return StreamBuilder<QuerySnapshot>(
          stream: _dbService.getCategoriesStream(parentId),
          builder: (ctx, snapshot) {
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
                  _selectedCategoryId = parentId;
                  _fullCategoryPath = currentPath;
                  _fullCategoryDisplayPath = currentDisplayPath;
                });
                _fetchCategoryFeatures(parentId);
                Navigator.pop(ctx);
              });
              return Center(
                child: Text(tr('approving'), style: LocalFonts.poppins()),
              );
            }
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    currentDisplayPath.isEmpty
                        ? tr('select_category')
                        : currentDisplayPath,
                    style: LocalFonts.poppins(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue[800],
                    ),
                  ),
                ),
                Expanded(
                  child: ListView.builder(
                    itemCount: docs.length,
                    itemBuilder: (ctx, index) {
                      var docData = docs[index].data() as Map<String, dynamic>;
                      String originalName = docData['name'];
                      String translatedName = getTranslatedText(
                        docData,
                        'name',
                      );
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
                          Navigator.pop(ctx);

                          var subCats = await FirebaseFirestore.instance
                              .collection('categories')
                              .where('parentId', isEqualTo: clickedId)
                              .limit(1)
                              .get();
                          if (subCats.docs.isEmpty) {
                            setState(() {
                              _selectedCategoryId = clickedId;
                              _fullCategoryPath = newPath;
                              _fullCategoryDisplayPath = newDisplayPath;
                            });
                            _fetchCategoryFeatures(clickedId);
                          } else {
                            if (context.mounted)
                              _showCategoryPicker(
                                clickedId,
                                newPath,
                                newDisplayPath,
                              );
                          }
                        },
                      );
                    },
                  ),
                ),
                if (currentPath.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedCategoryId = parentId;
                          _fullCategoryPath = currentPath;
                          _fullCategoryDisplayPath = currentDisplayPath;
                        });
                        _fetchCategoryFeatures(parentId);
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 45),
                      ),
                      child: Text(
                        '${tr('all')} "$currentDisplayPath"',
                        style: LocalFonts.poppins(color: Colors.white),
                      ),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _saveAlarm() async {
    if (_fullCategoryPath.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(tr('please_select_category'))));
      return;
    }

    double minPrice = double.tryParse(_minPriceController.text) ?? 0;
    double maxPrice = double.tryParse(_maxPriceController.text) ?? 0;
    Map<String, String> featuresToSave = {};
    _featureDropdownValues.forEach((key, val) {
      if (val != null && val.isNotEmpty) featuresToSave[key] = val;
    });

    // 1. Önce alarmı veritabanına her zamanki gibi kaydet
    await _dbService.addSearchAlarm(
      _fullCategoryPath,
      minPrice,
      maxPrice,
      _selectedCity,
      _selectedDistrict,
      featuresToSave,
    );

    // 2. Hemen arka planda bu kriterlere uygun aktif ilan var mı bak
    int matchCount = await _dbService.checkActiveListingsForAlarm(
      categoryPath: _fullCategoryPath,
      minPrice: minPrice,
      maxPrice: maxPrice,
      city: _selectedCity,
      district: _selectedDistrict,
      features: featuresToSave,
    );

    // 3. Eğer ilan varsa Müjde popup'ı çıkar!
    if (matchCount > 0) {
      if (mounted) {
        showDialog(
          context: context,
          builder: (c) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.celebration, size: 60, color: Colors.orange),
                const SizedBox(height: 16),
                Text(
                  "🎉 Müjde!",
                  style: LocalFonts.poppins(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  "Alarmınızı kaydettik ancak beklemenize hiç gerek yok! Şu an sistemimizde tam aradığınız özelliklere uygun $matchCount adet aktif ilan bulunuyor. Hemen incelemek ister misiniz?",
                  textAlign: TextAlign.center,
                  style: LocalFonts.poppins(fontSize: 14),
                ),
              ],
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pop(context);
                },
                child: Text(
                  "Daha Sonra",
                  style: LocalFonts.poppins(color: Colors.grey),
                ),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(c);
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                      builder: (_) => AllListingsScreen(
                        initialFilters: {
                          'categoryName': _fullCategoryPath,
                          'city': _selectedCity,
                          'district': _selectedDistrict,
                          'minPrice': minPrice,
                          'maxPrice': maxPrice,
                        },
                      ),
                    ),
                  );
                },
                child: Text(
                  tr('review_now'),
                  style: LocalFonts.poppins(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    } else {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(tr('alarm_created_success'))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
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
                  'Yeni Alarm Kur',
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
            const SizedBox(height: 16),

            InkWell(
              onTap: () => _showCategoryPicker("", "", ""),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  color: Colors.blue[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.category, color: Colors.blue[800]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _fullCategoryDisplayPath.isEmpty
                            ? tr('select_category_mandatory')
                            : _fullCategoryDisplayPath,
                        style: LocalFonts.poppins(
                          color: Colors.blue[900],
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Icon(Icons.arrow_drop_down, color: Colors.blue),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            if (_categoryFeatures.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.amber[50],
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber[100]!),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tr('category_specific_filters'),
                      style: LocalFonts.poppins(
                        fontWeight: FontWeight.bold,
                        color: Colors.amber[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    ..._categoryFeatures.map((feature) {
                      String name = feature['name'];
                      List<String> options = feature['options'];
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: DropdownButtonFormField<String>(
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: name,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                              borderSide: BorderSide.none,
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 12,
                            ),
                          ),
                          initialValue: _featureDropdownValues[name],
                          items: [
                            DropdownMenuItem(
                              value: null,
                              child: Text(tr('does_not_matter')),
                            ),
                            ...options.toSet().map(
                              (opt) => DropdownMenuItem(
                                value: opt,
                                child: Text(
                                  opt,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) => setState(
                            () => _featureDropdownValues[name] = val,
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 16),
            ],

            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _minPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('min_price'),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: TextField(
                    controller: _maxPriceController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: tr('max_price'),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: tr('city'),
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    initialValue: _selectedCity,
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr('all'))),
                      ...turkeyLocations.keys.map(
                        (city) => DropdownMenuItem(
                          value: city,
                          child: Text(city, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (val) {
                      setState(() {
                        _selectedCity = val;
                        _selectedDistrict = null;
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
                      filled: true,
                      fillColor: Colors.grey[100],
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    initialValue: _selectedDistrict,
                    items: [
                      DropdownMenuItem(value: null, child: Text(tr('all'))),
                      if (_selectedCity != null)
                        ...turkeyLocations[_selectedCity]!.map(
                          (d) => DropdownMenuItem(
                            value: d,
                            child: Text(d, overflow: TextOverflow.ellipsis),
                          ),
                        ),
                    ],
                    onChanged: (val) => setState(() => _selectedDistrict = val),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saveAlarm,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.amber[600],
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                tr('save_alarm'),
                style: LocalFonts.poppins(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
