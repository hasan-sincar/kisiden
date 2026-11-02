import 'package:flutter/material.dart';

import '../data/trade_types.dart';
import '../services/viewed_listings_service.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';
import '../widgets/trade_type_selector.dart';
import 'listing_detail_screen.dart';

class ViewedListingsScreen extends StatefulWidget {
  const ViewedListingsScreen({super.key});

  @override
  State<ViewedListingsScreen> createState() => _ViewedListingsScreenState();
}

class _ViewedListingsScreenState extends State<ViewedListingsScreen> {
  final Set<String> _selectedTradeTypes = <String>{};
  late final Future<List<Map<String, dynamic>>> _entriesFuture =
      ViewedListingsService.load();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(tr('recently_viewed')),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(68),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TradeTypeSelector(
              showHeading: false,
              selectedTypes: _selectedTradeTypes,
              onTypeToggled: (typeId) => setState(() {
                if (!_selectedTradeTypes.add(typeId)) {
                  _selectedTradeTypes.remove(typeId);
                }
              }),
            ),
          ),
        ),
      ),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: _entriesFuture,
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return Center(child: Text(tr('no_recently_viewed')));
          }
          final filteredEntries = entries.where((entry) {
            final data = Map<String, dynamic>.from(entry['data'] as Map);
            return listingMatchesTradeTypeFilter(data, _selectedTradeTypes);
          }).toList();
          if (filteredEntries.isEmpty) {
            return Center(child: Text(tr('no_listings_found_criteria')));
          }

          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: filteredEntries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = filteredEntries[index];
              final data = Map<String, dynamic>.from(entry['data'] as Map);
              final image = data['imageUrl']?.toString() ?? '';
              return ListTile(
                contentPadding: const EdgeInsets.all(8),
                tileColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                leading: image.isEmpty
                    ? const Icon(Icons.image_outlined)
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: Image.network(
                          image,
                          width: 64,
                          height: 64,
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
              );
            },
          );
        },
      ),
    );
  }
}
