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
  {"id":"vehicle","labelKey":"trade_type_vehicle"},
  {"id":"motorcycle_bicycle","labelKey":"trade_type_motorcycle_bicycle"},
  {"id":"clothing_accessories","labelKey":"trade_type_clothing_accessories"},
  {"id":"furniture_home","labelKey":"trade_type_furniture_home"},
  {"id":"sports_outdoor","labelKey":"trade_type_sports_outdoor"},
  {"id":"musical_instruments","labelKey":"trade_type_musical_instruments"},
  {"id":"books_education","labelKey":"trade_type_books_education"},
  {"id":"toys_baby","labelKey":"trade_type_toys_baby"},
  {"id":"tools_hardware","labelKey":"trade_type_tools_hardware"},
  {"id":"collectibles_hobby","labelKey":"trade_type_collectibles_hobby"},
  {"id":"personal_care","labelKey":"trade_type_personal_care"},
  {"id":"office_equipment","labelKey":"trade_type_office_equipment"},
  {"id":"all","labelKey":"trade_type_all"}
]
''';

final List<TradeType> tradeTypes = List<TradeType>.unmodifiable(
  (jsonDecode(_tradeTypesJson) as List<dynamic>).map(TradeType.fromJson),
);

List<String> listingDesiredTradeTypeLabels(
  Map<String, dynamic> listing,
  String Function(String) translate,
) {
  if (listing['tradeEnabled'] != true) return const [];

  final tradePreferences = listing['tradePreferences'];
  final desiredTradeTypes = tradePreferences is Map
      ? tradePreferences['desiredTradeTypes']
      : null;
  if (desiredTradeTypes is! List) return const [];

  final labels = <String>[];
  for (final desiredType in desiredTradeTypes.whereType<String>()) {
    for (final tradeType in tradeTypes) {
      if (tradeType.id == desiredType) {
        labels.add(translate(tradeType.labelKey));
        break;
      }
    }
  }
  return labels;
}

bool listingMatchesTradeTypeFilter(
  Map<String, dynamic> listing,
  Set<String> selectedTypes, {
  bool requireDesiredTradeTypes = false,
}
) {
  final tradePreferences = listing['tradePreferences'];
  final desiredTradeTypes = tradePreferences is Map
      ? tradePreferences['desiredTradeTypes']
      : null;
  final hasDesiredTradeTypes =
      desiredTradeTypes is List &&
      desiredTradeTypes.any(
        (type) => type is String && type.trim().isNotEmpty,
      );

  if (requireDesiredTradeTypes &&
      (listing['tradeEnabled'] != true || !hasDesiredTradeTypes)) {
    return false;
  }
  if (selectedTypes.isEmpty) return true;
  if (listing['tradeEnabled'] != true) return false;
  if (selectedTypes.contains(allTradeTypesId)) return true;

  return desiredTradeTypes is List &&
      (desiredTradeTypes.contains(allTradeTypesId) ||
          desiredTradeTypes.any(
            (type) => type is String && selectedTypes.contains(type),
          ));
}
