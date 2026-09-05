import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:appim/utils/local_fonts.dart';
import '../services/database_service.dart';
import '../utils/translations.dart';
import 'listing_detail_screen.dart';

class UrgentListingsScreen extends StatelessWidget {
  const UrgentListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const _UrgentListingsView();
  }
}

class _UrgentListingsView extends StatefulWidget {
  const _UrgentListingsView();

  @override
  State<_UrgentListingsView> createState() => _UrgentListingsViewState();
}

class _UrgentListingsViewState extends State<_UrgentListingsView> {
  Map<String, String> _categoryNameMap = {};
  String _categoryMapLang = '';
  String _sortBy = 'date_desc';
  bool _isGridView = false;
  String _categoryFilter = '';
  String _categoryDisplay = '';
  double? _minPrice;
  double? _maxPrice;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final lang = Localizations.localeOf(context).languageCode;
    if (_categoryMapLang != lang) {
      _categoryMapLang = lang;
      _loadCategoryNameMap();
    }
  }

  Future<void> _loadCategoryNameMap() async {
    try {
      final snapshot = await FirebaseFirestore.instance
          .collection('categories')
          .get();
      final map = <String, String>{};
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final rawName = (data['name'] ?? '').toString().trim();
        if (rawName.isEmpty) continue;
        final localizedName = getTranslatedText(data, 'name').trim();
        if (localizedName.isNotEmpty) {
          map[rawName] = localizedName;
        }
      }
      if (!mounted) return;
      setState(() {
        _categoryNameMap = map;
      });
    } catch (_) {}
  }

  String _translateCategoryToken(String token) {
    final t = token.trim();
    if (t.isEmpty) return t;
    return _categoryNameMap[t] ?? t;
  }

  String _translateCategoryPath(String? categoryPath, String? category) {
    final path = categoryPath?.trim() ?? '';
    if (path.isNotEmpty) {
      final translatedParts = path
          .split('>')
          .map((part) => _translateCategoryToken(part))
          .where((part) => part.isNotEmpty)
          .toList();
      if (translatedParts.isNotEmpty) {
        return translatedParts.join(' > ');
      }
    }
    final cat = category?.trim() ?? '';
    if (cat.isNotEmpty) return _translateCategoryToken(cat);
    return tr('other_category');
  }

  String _topCategory(String? categoryPath, String? category) {
    final path = categoryPath?.trim() ?? '';
    if (path.isNotEmpty) {
      return path.split(' > ').first.trim();
    }
    return (category?.trim().isNotEmpty == true)
        ? category!.trim()
        : tr('other_category');
  }

  String _leafCategory(String? categoryPath, String? category) {
    final path = categoryPath?.trim() ?? '';
    if (path.isNotEmpty) {
      return path.split(' > ').last.trim();
    }
    return (category?.trim().isNotEmpty == true)
        ? category!.trim()
        : tr('other_category');
  }

  String _formatPrice(dynamic price) {
    final raw = price?.toString() ?? '0';
    final formatted = raw
        .split('.')
        .first
        .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (match) => '.');
    return '₺$formatted';
  }

  void _showCategoryPicker() {
    final history = <String>[''];
    final displayPath = <String>[];
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          final parentId = history.last;
          return SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.62,
            child: StreamBuilder<QuerySnapshot>(
              stream: DatabaseService().getCategoriesStream(parentId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs.toList()
                  ..sort((a, b) {
                    final aData = a.data() as Map<String, dynamic>;
                    final bData = b.data() as Map<String, dynamic>;
                    return ((aData['order'] as num?) ?? 0).compareTo(
                      (bData['order'] as num?) ?? 0,
                    );
                  });
                return Column(
                  children: [
                    ListTile(
                      leading: history.length > 1
                          ? IconButton(
                              icon: const Icon(Icons.arrow_back),
                              onPressed: () => setSheetState(() {
                                history.removeLast();
                                if (displayPath.isNotEmpty) {
                                  displayPath.removeLast();
                                }
                              }),
                            )
                          : null,
                      title: Text(
                        displayPath.isEmpty
                            ? tr('select_category')
                            : displayPath.join(' > '),
                        textAlign: TextAlign.center,
                        style: LocalFonts.poppins(fontWeight: FontWeight.bold),
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(sheetContext),
                      ),
                    ),
                    ListTile(
                      leading: const Icon(Icons.all_inclusive),
                      title: Text(tr('all')),
                      onTap: () {
                        setState(() {
                          _categoryFilter = '';
                          _categoryDisplay = '';
                        });
                        Navigator.pop(sheetContext);
                      },
                    ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: docs.length,
                        itemBuilder: (context, index) {
                          final doc = docs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final name = getTranslatedText(data, 'name');
                          final rawName = (data['name'] ?? name).toString();
                          return ListTile(
                            title: Text(name),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () async {
                              final children = await DatabaseService()
                                  .getCategoriesStream(doc.id)
                                  .first;
                              if (children.docs.isEmpty) {
                                setState(() {
                                  _categoryFilter = rawName;
                                  _categoryDisplay =
                                      [...displayPath, name].join(' > ');
                                });
                                if (context.mounted) {
                                  Navigator.pop(sheetContext);
                                }
                              } else {
                                setSheetState(() {
                                  history.add(doc.id);
                                  displayPath.add(name);
                                });
                              }
                            },
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showUrgentControls() {
    final minController = TextEditingController(
      text: _minPrice?.toStringAsFixed(0) ?? '',
    );
    final maxController = TextEditingController(
      text: _maxPrice?.toStringAsFixed(0) ?? '',
    );
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) => Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            20,
            20,
            MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: Wrap(
            runSpacing: 12,
            children: [
              Text(
                tr('filter'),
                style: LocalFonts.poppins(
                  fontSize: 19,
                  fontWeight: FontWeight.bold,
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.category_outlined),
                title: Text(
                  _categoryDisplay.isEmpty
                      ? tr('select_category')
                      : _categoryDisplay,
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: _showCategoryPicker,
              ),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: minController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('min_price')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: maxController,
                      keyboardType: TextInputType.number,
                      decoration: InputDecoration(labelText: tr('max_price')),
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                initialValue: _sortBy,
                decoration: InputDecoration(labelText: tr('sort_criteria')),
                items: [
                  DropdownMenuItem(
                    value: 'date_desc',
                    child: Text(tr('newest_listings')),
                  ),
                  DropdownMenuItem(
                    value: 'expiry_asc',
                    child: Text('Süresi en az kalanlar'),
                  ),
                  DropdownMenuItem(
                    value: 'price_asc',
                    child: Text(tr('price_low_to_high')),
                  ),
                  DropdownMenuItem(
                    value: 'price_desc',
                    child: Text(tr('price_high_to_low')),
                  ),
                ],
                onChanged: (value) {
                  if (value != null) setSheetState(() => _sortBy = value);
                },
              ),
              FilledButton(
                onPressed: () {
                  setState(() {
                    _minPrice = double.tryParse(minController.text);
                    _maxPrice = double.tryParse(maxController.text);
                  });
                  Navigator.pop(sheetContext);
                },
                child: Text(tr('apply_filter')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF6F7FB),
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          tr('urgent_listings_title'),
          style: LocalFonts.poppins(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
        ),
        actions: [
          IconButton(
            tooltip: tr('filter'),
            icon: const Icon(Icons.tune_rounded),
            onPressed: _showUrgentControls,
          ),
          IconButton(
            tooltip: _isGridView ? tr('list_view') : tr('grid_view'),
            icon: Icon(
              _isGridView
                  ? Icons.view_list_rounded
                  : Icons.grid_view_rounded,
            ),
            onPressed: () => setState(() => _isGridView = !_isGridView),
          ),
        ],
      ),
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot>(
          stream: FirebaseFirestore.instance
              .collection('listings')
              .where('status', isEqualTo: 'active')
              .snapshots(),
          builder: (context, snapshot) {
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }

            final urgentDocs = snapshot.data!.docs.where((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final ts = data['urgentUntil'] as Timestamp?;
              if (data['isUrgent'] != true || ts == null) return false;
              if (!ts.toDate().isAfter(DateTime.now())) return false;
              final price = (data['price'] as num?)?.toDouble() ?? 0;
              final category =
                  '${data['categoryPath'] ?? ''} ${data['category'] ?? ''}'
                      .toLowerCase();
              return (_categoryFilter.isEmpty ||
                      category.contains(_categoryFilter.toLowerCase())) &&
                  (_minPrice == null || price >= _minPrice!) &&
                  (_maxPrice == null || price <= _maxPrice!);
            }).toList();

            if (urgentDocs.isEmpty) {
              return CustomScrollView(
                slivers: [
                  SliverFillRemaining(
                    hasScrollBody: false,
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: 86,
                              height: 86,
                              decoration: BoxDecoration(
                                color: Colors.red.withValues(alpha: 0.08),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.notifications_active,
                                color: Colors.red,
                                size: 42,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              tr('urgent_no_listings_title'),
                              style: LocalFonts.poppins(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              tr('urgent_no_listings_desc'),
                              textAlign: TextAlign.center,
                              style: LocalFonts.poppins(
                                fontSize: 13,
                                color: Colors.grey[700],
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              );
            }

            urgentDocs.sort((a, b) {
              final dataA = a.data() as Map<String, dynamic>;
              final dataB = b.data() as Map<String, dynamic>;
              if (_sortBy == 'expiry_asc') {
                return (dataA['urgentUntil'] as Timestamp).compareTo(
                  dataB['urgentUntil'] as Timestamp,
                );
              }
              if (_sortBy == 'price_asc' || _sortBy == 'price_desc') {
                final result = ((dataA['price'] as num?) ?? 0).compareTo(
                  (dataB['price'] as num?) ?? 0,
                );
                return _sortBy == 'price_desc' ? -result : result;
              }
              final tsA = dataA['createdAt'] as Timestamp?;
              final tsB = dataB['createdAt'] as Timestamp?;
              return (tsB ?? Timestamp.now()).compareTo(tsA ?? Timestamp.now());
            });

            final categories = <String, List<QueryDocumentSnapshot>>{};
            final categoryTitles = <String, String>{};
            for (final doc in urgentDocs) {
              final data = doc.data() as Map<String, dynamic>;
              final rawTopCategory = _topCategory(
                data['categoryPath'],
                data['category'],
              );
              final translatedTopCategory = _topCategory(
                _translateCategoryPath(data['categoryPath'], data['category']),
                _translateCategoryToken((data['category'] ?? '').toString()),
              );
              categories.putIfAbsent(rawTopCategory, () => []);
              categories[rawTopCategory]!.add(doc);
              categoryTitles[rawTopCategory] = translatedTopCategory;
            }

            final groupedEntries = categories.entries.toList()
              ..sort((a, b) => b.value.length.compareTo(a.value.length));

            return CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate((context, index) {
                      final entry = groupedEntries[index];
                      final categoryName =
                          categoryTitles[entry.key] ?? entry.key;
                      return _CategorySection(
                        categoryName: categoryName,
                        listings: entry.value,
                        topCategory: entry.key,
                        topCategoryResolver: _topCategory,
                        leafCategoryResolver: _leafCategory,
                        translateCategoryPath: _translateCategoryPath,
                        translateCategoryToken: _translateCategoryToken,
                        formatPrice: _formatPrice,
                        isGridView: _isGridView,
                      );
                    }, childCount: groupedEntries.length),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categoryName,
    required this.listings,
    required this.topCategory,
    required this.topCategoryResolver,
    required this.leafCategoryResolver,
    required this.translateCategoryPath,
    required this.translateCategoryToken,
    required this.formatPrice,
    required this.isGridView,
  });

  final String categoryName;
  final List<QueryDocumentSnapshot> listings;
  final String topCategory;
  final String Function(String? categoryPath, String? category)
  topCategoryResolver;
  final String Function(String? categoryPath, String? category)
  leafCategoryResolver;
  final String Function(String? categoryPath, String? category)
  translateCategoryPath;
  final String Function(String token) translateCategoryToken;
  final String Function(dynamic price) formatPrice;
  final bool isGridView;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: const BoxDecoration(
                  color: Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  categoryName,
                  style: LocalFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Colors.black87,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: Colors.red.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      size: 13,
                      color: Colors.red,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      tr(
                        'listing_count',
                      ).replaceFirst('%s', '${listings.length}'),
                      style: LocalFonts.poppins(
                        color: Colors.red[800],
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
            ],
          ),
          const SizedBox(height: 10),
          if (isGridView)
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 0.72,
              ),
              itemCount: listings.length,
              itemBuilder: (context, index) =>
                  _buildCard(context, listings[index]),
            )
          else
            SizedBox(
              height: 184,
              child: ListView.separated(
                reverse: false,
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: listings.length,
                separatorBuilder: (context, index) => const SizedBox(width: 12),
                itemBuilder: (context, index) =>
                    _buildCard(context, listings[index]),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildCard(BuildContext context, QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final images = <String>[];
    if (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty) {
      images.add(data['imageUrl'].toString());
    }
    if (data['additionalImages'] is List) {
      for (final img in data['additionalImages']) {
        if (img.toString().isNotEmpty) images.add(img.toString());
      }
    }
    final cardCategory = leafCategoryResolver(
      translateCategoryPath(data['categoryPath'], data['category']),
      translateCategoryToken((data['category'] ?? '').toString()),
    );
    final translatedPath = translateCategoryPath(
      data['categoryPath'],
      data['category'],
    );
    return _UrgentListingCard(
      data: data,
      listingId: doc.id,
      images: images,
      priceText: formatPrice(data['price']),
      cardCategory: cardCategory,
      fullCategory: translatedPath.isNotEmpty ? translatedPath : cardCategory,
    );
  }
}

class _UrgentListingCard extends StatelessWidget {
  const _UrgentListingCard({
    required this.data,
    required this.listingId,
    required this.images,
    required this.priceText,
    required this.cardCategory,
    required this.fullCategory,
  });

  final Map<String, dynamic> data;
  final String listingId;
  final List<String> images;
  final String priceText;
  final String cardCategory;
  final String fullCategory;

  String _locationText(Map<String, dynamic> data) {
    final city = data['city']?.toString().trim() ?? '';
    final district = data['district']?.toString().trim() ?? '';

    String neighborhood = '';
    final features = data['features'];
    if (features is Map) {
      final rawNeighborhood =
          features['Mahalle'] ??
          features['mahalle'] ??
          features['neighborhood'];
      neighborhood = rawNeighborhood?.toString().trim() ?? '';
    }

    final parts = <String>[
      if (city.isNotEmpty) city,
      if (district.isNotEmpty) district,
      if (neighborhood.isNotEmpty) neighborhood,
    ];
    return parts.isNotEmpty ? parts.join(' / ') : tr('no_location');
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              ListingDetailScreen(data: data, listingId: listingId),
        ),
      ),
      child: Container(
        width: 126,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 5),
            ),
          ],
          border: Border.all(color: Colors.red.withValues(alpha: 0.12)),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: Stack(
            children: [
              Positioned.fill(
                child: images.isEmpty
                    ? Container(
                        color: const Color(0xFFF2F3F7),
                        child: const Icon(
                          Icons.image_outlined,
                          color: Colors.grey,
                          size: 38,
                        ),
                      )
                    : PageView.builder(
                        itemCount: images.length,
                        itemBuilder: (context, imgIndex) {
                          return Image.network(
                            images[imgIndex],
                            fit: BoxFit.cover,
                          );
                        },
                      ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.80),
                      ],
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        priceText,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LocalFonts.poppins(
                          fontSize: 15,
                          fontWeight: FontWeight.w900,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        data['title']?.toString().trim().isNotEmpty == true
                            ? data['title'].toString().trim()
                            : tr('no_title'),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: LocalFonts.poppins(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white.withValues(alpha: 0.9),
                          height: 1.08,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Text(
                        _locationText(data),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: LocalFonts.poppins(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withValues(alpha: 0.92),
                        ),
                      ),
                      const SizedBox(height: 3),
                      _remainingTimeChip(data['urgentUntil']),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _remainingTimeChip(dynamic value) {
    final until = value is Timestamp ? value.toDate() : null;
    if (until == null) return const SizedBox();
    final remaining = until.difference(DateTime.now());
    if (remaining.isNegative) return const SizedBox();
    final hours = remaining.inHours;
    final minutes = remaining.inMinutes.remainder(60);
    final label = hours >= 24
        ? '${remaining.inDays} gün ${hours.remainder(24)} sa'
        : '$hours sa ${minutes.toString().padLeft(2, '0')} dk';
    return _miniChip(
      label: label,
      color: Colors.white,
      background: Colors.red.withValues(alpha: 0.85),
    );
  }

  Widget _miniChip({
    required String label,
    required Color color,
    required Color background,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: LocalFonts.poppins(
          color: color,
          fontSize: 9,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
