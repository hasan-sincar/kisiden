class ChatRiskAnalysis {
  final int score;
  final String level;
  final List<String> signals;

  const ChatRiskAnalysis({
    required this.score,
    required this.level,
    required this.signals,
  });

  bool get isRisky => score >= 40;
  bool get isHighRisk => score >= 70;
}

class ChatRiskDetector {
  static final RegExp _paymentKeywordRegex = RegExp(
    r'\b(iban|havale|eft)\b',
    caseSensitive: false,
  );

  static final RegExp _ibanRegex = RegExp(
    r'\bTR\d{2}\s?(?:\d{4}\s?){5}\d{2}\b',
    caseSensitive: false,
  );

  static final RegExp _urlRegex = RegExp(
    r'((https?:\/\/)|(www\.))[^\s]+',
    caseSensitive: false,
  );

  static final RegExp _shortenerRegex = RegExp(
    r'\b(bit\.ly|tinyurl\.com|t\.co|shorturl\.at|cutt\.ly)\b',
    caseSensitive: false,
  );

  static final RegExp _depositRegex = RegExp(
    r'\b(kapora|on\s*odeme|ön\s*ödeme|once\s*havale|önce\s*havale|eft\s*(at|gonder)|havale\s*(at|gonder)|parayi\s*(gonder|at))\b',
    caseSensitive: false,
  );

  static final RegExp _offPlatformRegex = RegExp(
    r'\b(whatsapp|telegram|instagram|dm|baska\s*uygulama|uygulama\s*disi|uygulama\s*disi)\b',
    caseSensitive: false,
  );

  static final RegExp _urgencyRegex = RegExp(
    r'\b(hemen\s*gonder|acil\s*odeme|son\s*dakika|firsat\s*kacmasin|fırsat\s*kaçmasın)\b',
    caseSensitive: false,
  );

  static ChatRiskAnalysis analyze(String text) {
    final msg = text.trim();
    if (msg.isEmpty) {
      return const ChatRiskAnalysis(
        score: 0,
        level: 'none',
        signals: <String>[],
      );
    }

    var score = 0;
    final signals = <String>[];

    final paymentKeywordMatches = _paymentKeywordRegex
        .allMatches(msg)
        .map((m) => (m.group(0) ?? '').toLowerCase())
        .where((v) => v.isNotEmpty)
        .toSet();

    if (paymentKeywordMatches.length >= 2) {
      score += 45;
      signals.add('IBAN/havale/EFT kombinasyonu tespit edildi.');
    } else if (paymentKeywordMatches.length == 1) {
      score += 20;
      signals.add('Ödeme anahtar kelimesi tespit edildi.');
    }

    if (_ibanRegex.hasMatch(msg)) {
      score += 45;
      signals.add('IBAN bilgisi tespit edildi.');
    }

    if (_urlRegex.hasMatch(msg)) {
      score += 25;
      signals.add('Mesajda dis baglanti var.');
    }

    if (_shortenerRegex.hasMatch(msg)) {
      score += 20;
      signals.add('Kisa link kullanimi tespit edildi.');
    }

    if (_depositRegex.hasMatch(msg)) {
      score += 35;
      signals.add('Kapora/on odeme istegi iceren ifade bulundu.');
    }

    if (_offPlatformRegex.hasMatch(msg)) {
      score += 20;
      signals.add('Uygulama disina yonlendirme ifadesi bulundu.');
    }

    if (_urgencyRegex.hasMatch(msg)) {
      score += 10;
      signals.add('Acil odeme baskisi olusturan ifade bulundu.');
    }

    if (score > 100) {
      score = 100;
    }

    final level = score >= 70
        ? 'high'
        : (score >= 40 ? 'medium' : (score > 0 ? 'low' : 'none'));

    return ChatRiskAnalysis(score: score, level: level, signals: signals);
  }
}
