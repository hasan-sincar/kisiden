import 'package:flutter/material.dart';

import '../services/viewed_listings_service.dart';
import '../utils/local_fonts.dart';
import '../utils/translations.dart';
import 'listing_detail_screen.dart';

class ViewedListingsScreen extends StatelessWidget {
  const ViewedListingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(tr('recently_viewed'))),
      body: FutureBuilder<List<Map<String, dynamic>>>(
        future: ViewedListingsService.load(),
        builder: (context, snapshot) {
          final entries = snapshot.data ?? [];
          if (entries.isEmpty) {
            return Center(child: Text(tr('no_recently_viewed')));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: entries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final entry = entries[index];
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
