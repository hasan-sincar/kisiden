import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/database_service.dart';
import '../utils/turkey_locations.dart';
import '../utils/translations.dart';
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(
          tr('search_alarms'),
          style: LocalFonts.poppins(
            color: Colors.black87,
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
            if (!snapshot.hasData)
              return const Center(child: CircularProgressIndicator());
            var alarms = snapshot.data!.docs;

            if (alarms.isEmpty) {
              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.notifications_off_outlined,
                      size: 80,
                      color: Colors.grey[300],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      tr('no_alarms_set'),
                      style: LocalFonts.poppins(
                        color: Colors.grey,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton.icon(
                      onPressed: _showAddAlarmModal,
                      icon: const Icon(Icons.add_alert, color: Colors.white),
                      label: Text(
                        tr('set_new_alarm'),
                        style: LocalFonts.poppins(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: alarms.length,
              itemBuilder: (context, index) {
                var data = alarms[index].data() as Map<String, dynamic>;
                String catName =
                    data['categoryPath']?.split(' > ').last ?? tr('category');

                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Material(
                    color: Colors.transparent,
                    borderRadius: BorderRadius.circular(16),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: Colors.amber[50],
                        child: Icon(
                          Icons.notifications_active,
                          color: Colors.amber[600],
                        ),
                      ),
                      title: Text(
                        catName,
                        style: LocalFonts.poppins(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          if (data['city'] != null)
                            Text(
                              '📍 ${data['city']} ${data['district'] != null ? "- ${data['district']}" : ""}',
                              style: LocalFonts.poppins(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          if (data['minPrice'] != null ||
                              data['maxPrice'] != null)
                            Text(
                              '💰 ${data['minPrice'] ?? 0}₺ - ${data['maxPrice'] == 0 || data['maxPrice'] == null ? tr('unlimited') : "${data['maxPrice']}₺"}',
                              style: LocalFonts.poppins(
                                fontSize: 12,
                                color: Colors.green[700],
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                        ],
                      ),
                      trailing: IconButton(
                        icon: const Icon(
                          Icons.delete_outline,
                          color: Colors.red,
                        ),
                        onPressed: () =>
                            _dbService.deleteSearchAlarm(alarms[index].id),
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddAlarmModal,
        backgroundColor: Colors.amber[600],
        elevation: 0,
        icon: const Icon(Icons.add, color: Colors.white),
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
