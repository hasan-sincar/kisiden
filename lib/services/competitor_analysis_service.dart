import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/competitor_analysis.dart';

class CompetitorAnalysisService {
  CompetitorAnalysisService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _firestore;

  Future<List<ComparableListing>> fetchComparableListings(
    CompetitorAnalysisInput input,
  ) async {
    if (!input.hasCategory) return const [];

    Query<Map<String, dynamic>> query = _firestore
        .collection('listings')
        .where('status', isEqualTo: 'active')
        .where('categoryPath', isEqualTo: input.categoryPath)
        .limit(60);

    if (input.normalizedBrand.isNotEmpty) {
      query = query.where('features.Marka', isEqualTo: input.brand?.trim());
    }

    if (input.normalizedModel.isNotEmpty) {
      query = query.where('features.Model', isEqualTo: input.model?.trim());
    }

    final snapshot = await query.get();
    return snapshot.docs.map(_mapComparableListing).toList();
  }

  ComparableListing _mapComparableListing(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    final rawFeatures = data['features'];
    final features = rawFeatures is Map<String, dynamic>
        ? rawFeatures
        : <String, dynamic>{};

    return ComparableListing(
      id: doc.id,
      title: (data['title'] ?? '').toString(),
      price: (data['price'] as num?)?.toDouble() ?? 0,
      categoryPath: (data['categoryPath'] ?? '').toString(),
      brand: _featureValue(features, const ['Marka', 'marka', 'brand']),
      model: _featureValue(features, const ['Model', 'model']),
    );
  }

  String? _featureValue(Map<String, dynamic> features, List<String> keys) {
    for (final key in keys) {
      final value = features[key]?.toString().trim();
      if (value != null && value.isNotEmpty) {
        return value;
      }
    }
    return null;
  }
}
