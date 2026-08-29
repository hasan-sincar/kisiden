import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/competitor_analysis.dart';
import '../services/competitor_analysis_service.dart';
import '../utils/local_fonts.dart';

class CompetitorAnalysisCard extends StatefulWidget {
  const CompetitorAnalysisCard({super.key, required this.input, this.service});

  final CompetitorAnalysisInput input;
  final CompetitorAnalysisService? service;

  @override
  State<CompetitorAnalysisCard> createState() => _CompetitorAnalysisCardState();
}

class _CompetitorAnalysisCardState extends State<CompetitorAnalysisCard> {
  late final CompetitorAnalysisService _service;
  final NumberFormat _currencyFormatter = NumberFormat.currency(
    locale: 'tr_TR',
    symbol: '₺',
    decimalDigits: 0,
  );

  Timer? _debounce;
  String? _lastQuerySignature;
  List<ComparableListing> _candidates = const [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? CompetitorAnalysisService();
    _scheduleRefresh(force: true);
  }

  @override
  void didUpdateWidget(covariant CompetitorAnalysisCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.input.querySignature != widget.input.querySignature) {
      _scheduleRefresh(force: true);
      return;
    }
    if (oldWidget.input.title != widget.input.title ||
        oldWidget.input.price != widget.input.price ||
        oldWidget.input.descriptionLength != widget.input.descriptionLength ||
        oldWidget.input.imageCount != widget.input.imageCount) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _scheduleRefresh({bool force = false}) {
    _debounce?.cancel();
    if (!widget.input.hasCategory) {
      if (mounted) {
        setState(() {
          _candidates = const [];
          _isLoading = false;
          _lastQuerySignature = null;
        });
      }
      return;
    }

    if (!force && _lastQuerySignature == widget.input.querySignature) {
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 350), () async {
      if (!mounted) return;
      setState(() {
        _isLoading = true;
      });

      final candidates = await _service.fetchComparableListings(widget.input);
      if (!mounted) return;
      setState(() {
        _candidates = candidates;
        _lastQuerySignature = widget.input.querySignature;
        _isLoading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.input.hasPrice) {
      return const SizedBox.shrink();
    }

    if (!widget.input.hasCategory) {
      return _buildPlaceholderCard(
        message:
            'Kategori secildiginde rakip ilan analizi otomatik başlayacak.',
      );
    }

    final result = CompetitorAnalysisEngine.evaluate(widget.input, _candidates);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAFF),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFD6E6FF)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x110D47A1),
            blurRadius: 20,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE3F0FF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.analytics_rounded,
                  color: Color(0xFF0D47A1),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Rakip İlan Analizi',
                      style: LocalFonts.poppins(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFF102A43),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _isLoading
                          ? 'Piyasa verileri guncelleniyor...'
                          : 'Bu urunden ${result.similarCount} benzer ilan bulundu.',
                      style: LocalFonts.poppins(
                        fontSize: 12,
                        color: const Color(0xFF52606D),
                      ),
                    ),
                  ],
                ),
              ),
              _buildBadge(result),
            ],
          ),
          if (!result.hasEnoughMarketData) ...[
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF7E8),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFFE0A3)),
              ),
              child: Text(
                'Bu ürün için yeterli piyasa verisi bulunamadı.',
                style: LocalFonts.poppins(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFF8D5A00),
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 360;
              return Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _buildMetricTile(
                    label: 'Ortalama fiyat',
                    value: _currencyFormatter.format(result.averagePrice),
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                  ),
                  _buildMetricTile(
                    label: 'Piyasa fiyat',
                    value: _currencyFormatter.format(result.medianPrice),
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                  ),
                  _buildMetricTile(
                    label: 'En dusuk fiyat',
                    value: _currencyFormatter.format(result.minPrice),
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                  ),
                  _buildMetricTile(
                    label: 'En yuksek fiyat',
                    value: _currencyFormatter.format(result.maxPrice),
                    width: compact
                        ? constraints.maxWidth
                        : (constraints.maxWidth - 10) / 2,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFE4ECF7)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _buildInsightText(result),
                  style: LocalFonts.poppins(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF243B53),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Tahmini Satış İhtimali: %${result.saleProbability}',
                  style: LocalFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF102A43),
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: result.saleProbability / 100,
                    minHeight: 10,
                    backgroundColor: const Color(0xFFD9E2EC),
                    color: _probabilityColor(result.saleProbability),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Tahmini Satis Suresi: ${result.saleDurationLabel}',
                        style: LocalFonts.poppins(
                          fontSize: 12,
                          color: const Color(0xFF52606D),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _probabilityColor(
                          result.saleProbability,
                        ).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _saleMomentumLabel(result.saleProbability),
                        style: LocalFonts.poppins(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: _probabilityColor(result.saleProbability),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Akıllı öneriler',
            style: LocalFonts.poppins(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: const Color(0xFF102A43),
            ),
          ),
          const SizedBox(height: 8),
          ...result.suggestions.map(_buildSuggestion),
        ],
      ),
    );
  }

  Widget _buildPlaceholderCard({required String message}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE4ECF7)),
      ),
      child: Row(
        children: [
          const Icon(Icons.insights_rounded, color: Color(0xFF486581)),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: LocalFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF52606D),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String label,
    required String value,
    required double width,
  }) {
    return SizedBox(
      width: width,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE4ECF7)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: LocalFonts.poppins(
                fontSize: 11,
                color: const Color(0xFF7B8794),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              value,
              style: LocalFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFF102A43),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSuggestion(String suggestion) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(
              Icons.auto_awesome_rounded,
              size: 16,
              color: Color(0xFF0D47A1),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              suggestion,
              style: LocalFonts.poppins(
                fontSize: 12,
                color: const Color(0xFF334E68),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBadge(CompetitorAnalysisResult result) {
    final visual = switch (result.badge) {
      CompetitorPriceBadge.greatPrice => (
        'Harika Fiyat',
        const Color(0xFF137333),
        const Color(0xFFE6F4EA),
      ),
      CompetitorPriceBadge.marketPrice => (
        'Piyasa Fiyati',
        const Color(0xFF0D47A1),
        const Color(0xFFE8F0FE),
      ),
      CompetitorPriceBadge.aboveMarket => (
        'Piyasanin Uzerinde',
        const Color(0xFFB26A00),
        const Color(0xFFFFF4D6),
      ),
      CompetitorPriceBadge.expensive => (
        'Oldukca Pahali',
        const Color(0xFFB42318),
        const Color(0xFFFEE4E2),
      ),
      CompetitorPriceBadge.insufficientData => (
        'Veri Sınırlı',
        const Color(0xFF7B8794),
        const Color(0xFFF1F5F9),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: visual.$3,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        visual.$1,
        style: LocalFonts.poppins(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: visual.$2,
        ),
      ),
    );
  }

  String _buildInsightText(CompetitorAnalysisResult result) {
    if (!result.hasEnoughMarketData) {
      return result.marketInsight;
    }
    final delta = result.priceDeltaPercent.abs().round();
    return result.marketInsight.replaceFirst('{value}', '$delta');
  }

  Color _probabilityColor(int probability) {
    if (probability >= 85) return const Color(0xFF137333);
    if (probability >= 70) return const Color(0xFF0D47A1);
    if (probability >= 55) return const Color(0xFFB26A00);
    return const Color(0xFFB42318);
  }

  String _saleMomentumLabel(int probability) {
    if (probability >= 85) return 'Cok Guclu';
    if (probability >= 70) return 'Guclu';
    if (probability >= 55) return 'Dengeli';
    return 'Gelişmeli';
  }
}
