import 'dart:convert';

class TradeType {
  const TradeType({required this.id, required this.labelKey});

  factory TradeType.fromJson(Object? value) {
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Trade type must be a JSON object.');
    }

    final id = value['id'];
    final labelKey = value['labelKey'];
    if (id is! String || labelKey is! String) {
      throw const FormatException(
        'Trade type id and labelKey must be strings.',
      );
    }

    return TradeType(id: id, labelKey: labelKey);
  }

  final String id;
  final String labelKey;
}

const String allTradeTypesId = 'all';

const _tradeTypesJson = '''
[
  {"id":"phone","labelKey":"trade_type_phone"},
  {"id":"tablet","labelKey":"trade_type_tablet"},
  {"id":"computer","labelKey":"trade_type_computer"},
  {"id":"game_console","labelKey":"trade_type_game_console"},
  {"id":"home_appliance","labelKey":"trade_type_home_appliance"},
  {"id":"television","labelKey":"trade_type_television"},
  {"id":"camera","labelKey":"trade_type_camera"},
  {"id":"all","labelKey":"trade_type_all"}
]
''';

final List<TradeType> tradeTypes = List<TradeType>.unmodifiable(
  (jsonDecode(_tradeTypesJson) as List<dynamic>).map(TradeType.fromJson),
);

bool listingMatchesTradeTypeFilter(
  Map<String, dynamic> listing,
  Set<String> selectedTypes,
) {
  if (selectedTypes.isEmpty) return true;
  if (listing['tradeEnabled'] != true) return false;
  if (selectedTypes.contains(allTradeTypesId)) return true;

  final tradePreferences = listing['tradePreferences'];
  final desiredTradeTypes = tradePreferences is Map
      ? tradePreferences['desiredTradeTypes']
      : null;
  return desiredTradeTypes is List &&
      (desiredTradeTypes.contains(allTradeTypesId) ||
          desiredTradeTypes.any(
            (type) => type is String && selectedTypes.contains(type),
          ));
}
