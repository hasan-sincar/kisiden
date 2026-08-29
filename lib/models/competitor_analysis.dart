import 'dart:math';

enum CompetitorPriceBadge {
  greatPrice,
  marketPrice,
  aboveMarket,
  expensive,
  insufficientData,
}

class CompetitorAnalysisInput {
  const CompetitorAnalysisInput({
    required this.categoryPath,
    required this.title,
    required this.price,
    required this.descriptionLength,
    required this.imageCount,
    this.brand,
    this.model,
    this.excludeListingId,
  });

  final String categoryPath;
  final String title;
  final double price;
  final int descriptionLength;
  final int imageCount;
  final String? brand;
  final String? model;
  final String? excludeListingId;

  bool get hasPrice => price > 0;
  bool get hasCategory => categoryPath.trim().isNotEmpty;

  String get normalizedBrand => _normalize(brand ?? '');
  String get normalizedModel => _normalize(model ?? '');
  String get normalizedTitle => _normalize(title);

  String get querySignature =>
      '${_normalize(categoryPath)}|$normalizedBrand|$normalizedModel|${excludeListingId ?? ''}';
}

class ComparableListing {
  const ComparableListing({
    required this.id,
    required this.title,
    required this.price,
    required this.categoryPath,
    this.brand,
    this.model,
  });

  final String id;
  final String title;
  final double price;
  final String categoryPath;
  final String? brand;
  final String? model;

  String get normalizedBrand => _normalize(brand ?? '');
  String get normalizedModel => _normalize(model ?? '');
  String get normalizedTitle => _normalize(title);
}

class CompetitorAnalysisResult {
  const CompetitorAnalysisResult({
    required this.similarCount,
    required this.averagePrice,
    required this.minPrice,
    required this.maxPrice,
    required this.medianPrice,
    required this.priceDeltaPercent,
    required this.badge,
    required this.suggestions,
    required this.saleProbability,
    required this.saleDurationLabel,
    required this.hasEnoughMarketData,
    required this.marketInsight,
  });

  final int similarCount;
  final double averagePrice;
  final double minPrice;
  final double maxPrice;
  final double medianPrice;
  final double priceDeltaPercent;
  final CompetitorPriceBadge badge;
  final List<String> suggestions;
  final int saleProbability;
  final String saleDurationLabel;
  final bool hasEnoughMarketData;
  final String marketInsight;
}

class CompetitorAnalysisEngine {
  static CompetitorAnalysisResult evaluate(
    CompetitorAnalysisInput input,
    List<ComparableListing> candidates,
  ) {
    final filtered = _filterCandidates(input, candidates);
    final prices = filtered.map((listing) => listing.price).toList()..sort();
    final similarCount = prices.length;
    final hasEnoughMarketData = similarCount >= 5;

    final averagePrice = similarCount == 0
        ? 0.0
        : prices.reduce((sum, price) => sum + price) / similarCount;
    final minPrice = similarCount == 0 ? 0.0 : prices.first;
    final maxPrice = similarCount == 0 ? 0.0 : prices.last;
    final medianPrice = _median(prices);
    final priceDeltaPercent = averagePrice <= 0
        ? 0.0
        : ((input.price - averagePrice) / averagePrice) * 100;

    final badge = _badgeFor(priceDeltaPercent, hasEnoughMarketData);
    final suggestions = _buildSuggestions(
      priceDeltaPercent: priceDeltaPercent,
      hasEnoughMarketData: hasEnoughMarketData,
      brand: input.brand,
      model: input.model,
    );
    final saleProbability = _estimateSaleProbability(
      input: input,
      similarCount: similarCount,
      averagePrice: averagePrice,
      hasEnoughMarketData: hasEnoughMarketData,
    );
    final saleDurationLabel = _estimateDuration(
      probability: saleProbability,
      similarCount: similarCount,
    );

    final marketInsight = hasEnoughMarketData
        ? _marketInsight(priceDeltaPercent)
        : 'Bu urun icin yeterli piyasa verisi bulunamadi.';

    return CompetitorAnalysisResult(
      similarCount: similarCount,
      averagePrice: averagePrice,
      minPrice: minPrice,
      maxPrice: maxPrice,
      medianPrice: medianPrice,
      priceDeltaPercent: priceDeltaPercent,
      badge: badge,
      suggestions: suggestions,
      saleProbability: saleProbability,
      saleDurationLabel: saleDurationLabel,
      hasEnoughMarketData: hasEnoughMarketData,
      marketInsight: marketInsight,
    );
  }

  static List<ComparableListing> _filterCandidates(
    CompetitorAnalysisInput input,
    List<ComparableListing> candidates,
  ) {
    final results = <ComparableListing>[];
    for (final candidate in candidates) {
      if (candidate.id == input.excludeListingId || candidate.price <= 0) {
        continue;
      }

      final titleSimilarity = _titleSimilarity(
        input.normalizedTitle,
        candidate.normalizedTitle,
      );

      final brandMatches =
          input.normalizedBrand.isEmpty ||
          input.normalizedBrand == candidate.normalizedBrand;
      final modelMatches =
          input.normalizedModel.isEmpty ||
          input.normalizedModel == candidate.normalizedModel;

      final isComparable =
          (input.normalizedBrand.isNotEmpty || input.normalizedModel.isNotEmpty)
          ? brandMatches && modelMatches && titleSimilarity >= 0.08
          : titleSimilarity >= 0.22;

      if (isComparable) {
        results.add(candidate);
      }
    }
    return results;
  }

  static double _median(List<double> sortedPrices) {
    if (sortedPrices.isEmpty) return 0.0;
    final middle = sortedPrices.length ~/ 2;
    if (sortedPrices.length.isOdd) {
      return sortedPrices[middle];
    }
    return (sortedPrices[middle - 1] + sortedPrices[middle]) / 2;
  }

  static CompetitorPriceBadge _badgeFor(
    double deltaPercent,
    bool hasEnoughMarketData,
  ) {
    if (!hasEnoughMarketData) return CompetitorPriceBadge.insufficientData;
    if (deltaPercent <= -10) return CompetitorPriceBadge.greatPrice;
    if (deltaPercent >= 25) return CompetitorPriceBadge.expensive;
    if (deltaPercent > 10) return CompetitorPriceBadge.aboveMarket;
    return CompetitorPriceBadge.marketPrice;
  }

  static List<String> _buildSuggestions({
    required double priceDeltaPercent,
    required bool hasEnoughMarketData,
    required String? brand,
    required String? model,
  }) {
    final suggestions = <String>[];

    if (!hasEnoughMarketData) {
      suggestions.add(
        'Daha dogru sonuc icin kategori, marka ve model bilgilerini netlestir.',
      );
    }

    if (priceDeltaPercent > 10) {
      suggestions.add(
        'Fiyatini biraz dusurursen daha fazla goruntulenebilirsin.',
      );
      suggestions.add(
        'Ortalama fiyat seviyesindeki ilanlar daha hizli satiliyor.',
      );
    } else if (priceDeltaPercent < -10) {
      suggestions.add(
        'Rekabetci fiyat seviyen ilana daha hizli talep getirebilir.',
      );
      suggestions.add(
        'Fiyatin guclu; aciklamani zenginlestirerek donusumu artirabilirsin.',
      );
    } else {
      suggestions.add(
        'Piyasa ortalamasina yakin fiyatlar genellikle daha dengeli performans gosterir.',
      );
      suggestions.add(
        'Benzer ilanlarin fiyatlarini inceleyerek konumunu koruyabilirsin.',
      );
    }

    if ((brand ?? '').trim().isEmpty || (model ?? '').trim().isEmpty) {
      suggestions.add(
        'Marka ve model bilgilerini tam girmek, analizin isabetini artirir.',
      );
    } else {
      suggestions.add('Benzer ilanlarin fiyatlarini inceleyebilirsin.');
    }

    return suggestions.take(3).toList();
  }

  static int _estimateSaleProbability({
    required CompetitorAnalysisInput input,
    required int similarCount,
    required double averagePrice,
    required bool hasEnoughMarketData,
  }) {
    final priceFactor = averagePrice <= 0
        ? 0.55
        : _clampDouble(
            1 - (((input.price - averagePrice) / averagePrice) * 0.9),
            0.15,
            1.0,
          );
    final marketFactor = _clampDouble(similarCount / 20, 0.15, 1.0);
    final descriptionFactor = _clampDouble(
      input.descriptionLength / 350,
      0.2,
      1.0,
    );
    final imageFactor = _clampDouble(input.imageCount / 8, 0.2, 1.0);
    final confidenceFactor = hasEnoughMarketData ? 1.0 : 0.82;

    final rawScore =
        (priceFactor * 42) +
        (marketFactor * 18) +
        (descriptionFactor * 20) +
        (imageFactor * 20);

    return (rawScore * confidenceFactor).round().clamp(18, 98).toInt();
  }

  static String _estimateDuration({
    required int probability,
    required int similarCount,
  }) {
    if (probability >= 85 && similarCount >= 5) return '3-7 gun';
    if (probability >= 70) return '1-2 hafta';
    if (probability >= 55) return '2-4 hafta';
    return '4+ hafta';
  }

  static String _marketInsight(double deltaPercent) {
    if (deltaPercent <= -10) {
      return 'Senin fiyatin piyasa ortalamasinin %{value} altinda.';
    }
    if (deltaPercent >= 0) {
      return 'Senin fiyatin piyasa ortalamasinin %{value} uzerinde.';
    }
    return 'Senin fiyatin piyasa ortalamasinin %{value} altinda.';
  }

  static double _titleSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final aTokens = a.split(' ').where((token) => token.isNotEmpty).toSet();
    final bTokens = b.split(' ').where((token) => token.isNotEmpty).toSet();
    if (aTokens.isEmpty || bTokens.isEmpty) return 0.0;

    final intersection = aTokens.intersection(bTokens).length.toDouble();
    final union = aTokens.union(bTokens).length.toDouble();
    if (union == 0) return 0.0;

    final jaccard = intersection / union;
    final containsBoost = a.contains(b) || b.contains(a) ? 0.12 : 0.0;
    return _clampDouble(jaccard + containsBoost, 0.0, 1.0);
  }
}

String _normalize(String value) {
  const replacements = {
    'ç': 'c',
    'ğ': 'g',
    'ı': 'i',
    'i': 'i',
    'ö': 'o',
    'ş': 's',
    'ü': 'u',
  };

  var normalized = value.trim().toLowerCase();
  replacements.forEach((key, replacement) {
    normalized = normalized.replaceAll(key, replacement);
  });
  normalized = normalized.replaceAll(RegExp(r'[^a-z0-9 ]'), ' ');
  normalized = normalized.replaceAll(RegExp(r'\s+'), ' ');
  return normalized.trim();
}

double _clampDouble(double value, double minValue, double maxValue) {
  return max(minValue, min(maxValue, value));
}
