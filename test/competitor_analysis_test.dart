import 'package:appim/models/competitor_analysis.dart';
import 'package:appim/services/competitor_analysis_service.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CompetitorAnalysisEngine', () {
    test('calculates market stats, badge and sales estimate', () {
      const input = CompetitorAnalysisInput(
        categoryPath: 'Elektronik > Telefon',
        title: 'iPhone 13 128 GB Mavi',
        price: 18700,
        descriptionLength: 260,
        imageCount: 6,
        brand: 'Apple',
        model: 'iPhone 13',
      );

      const candidates = [
        ComparableListing(
          id: '1',
          title: 'Apple iPhone 13 128 GB Mavi',
          price: 16500,
          categoryPath: 'Elektronik > Telefon',
          brand: 'Apple',
          model: 'iPhone 13',
        ),
        ComparableListing(
          id: '2',
          title: 'iPhone 13 128 GB Temiz',
          price: 17900,
          categoryPath: 'Elektronik > Telefon',
          brand: 'Apple',
          model: 'iPhone 13',
        ),
        ComparableListing(
          id: '3',
          title: 'Apple iPhone 13 Kutulu',
          price: 18900,
          categoryPath: 'Elektronik > Telefon',
          brand: 'Apple',
          model: 'iPhone 13',
        ),
        ComparableListing(
          id: '4',
          title: 'iPhone 13 128 GB',
          price: 19900,
          categoryPath: 'Elektronik > Telefon',
          brand: 'Apple',
          model: 'iPhone 13',
        ),
        ComparableListing(
          id: '5',
          title: 'iPhone 13 Mavi 128',
          price: 21900,
          categoryPath: 'Elektronik > Telefon',
          brand: 'Apple',
          model: 'iPhone 13',
        ),
      ];

      final result = CompetitorAnalysisEngine.evaluate(input, candidates);

      expect(result.similarCount, 5);
      expect(result.averagePrice, 19020);
      expect(result.minPrice, 16500);
      expect(result.maxPrice, 21900);
      expect(result.medianPrice, 18900);
      expect(result.badge, CompetitorPriceBadge.marketPrice);
      expect(result.hasEnoughMarketData, isTrue);
      expect(result.saleProbability, greaterThanOrEqualTo(55));
    });

    test('marks insufficient data when fewer than five listings exist', () {
      const input = CompetitorAnalysisInput(
        categoryPath: 'Vasita > Otomobil',
        title: 'Renault Clio 2020',
        price: 825000,
        descriptionLength: 120,
        imageCount: 3,
        brand: 'Renault',
        model: 'Clio',
      );

      const candidates = [
        ComparableListing(
          id: '1',
          title: 'Renault Clio 2020 Joy',
          price: 790000,
          categoryPath: 'Vasita > Otomobil',
          brand: 'Renault',
          model: 'Clio',
        ),
        ComparableListing(
          id: '2',
          title: 'Clio 2020 Temiz',
          price: 810000,
          categoryPath: 'Vasita > Otomobil',
          brand: 'Renault',
          model: 'Clio',
        ),
      ];

      final result = CompetitorAnalysisEngine.evaluate(input, candidates);

      expect(result.hasEnoughMarketData, isFalse);
      expect(result.badge, CompetitorPriceBadge.insufficientData);
      expect(result.marketInsight, contains('yeterli piyasa verisi'));
    });
  });

  group('CompetitorAnalysisService', () {
    test(
      'fetches only active listings from the same category and brand/model',
      () async {
        final firestore = FakeFirebaseFirestore();
        final service = CompetitorAnalysisService(firestore: firestore);

        await firestore.collection('listings').doc('a').set({
          'status': 'active',
          'categoryPath': 'Elektronik > Telefon',
          'title': 'Apple iPhone 13 128 GB',
          'price': 18000,
          'features': {'Marka': 'Apple', 'Model': 'iPhone 13'},
        });
        await firestore.collection('listings').doc('b').set({
          'status': 'active',
          'categoryPath': 'Elektronik > Telefon',
          'title': 'Apple iPhone 13 256 GB',
          'price': 20500,
          'features': {'Marka': 'Apple', 'Model': 'iPhone 13'},
        });
        await firestore.collection('listings').doc('c').set({
          'status': 'pending',
          'categoryPath': 'Elektronik > Telefon',
          'title': 'Apple iPhone 13 128 GB',
          'price': 17000,
          'features': {'Marka': 'Apple', 'Model': 'iPhone 13'},
        });
        await firestore.collection('listings').doc('d').set({
          'status': 'active',
          'categoryPath': 'Elektronik > Telefon',
          'title': 'Samsung S23',
          'price': 25000,
          'features': {'Marka': 'Samsung', 'Model': 'S23'},
        });

        const input = CompetitorAnalysisInput(
          categoryPath: 'Elektronik > Telefon',
          title: 'iPhone 13 128 GB',
          price: 18500,
          descriptionLength: 180,
          imageCount: 4,
          brand: 'Apple',
          model: 'iPhone 13',
        );

        final results = await service.fetchComparableListings(input);

        expect(results, hasLength(2));
        expect(results.every((item) => item.brand == 'Apple'), isTrue);
        expect(results.every((item) => item.model == 'iPhone 13'), isTrue);
      },
    );
  });
}
