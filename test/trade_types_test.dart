import 'package:appim/data/trade_types.dart';
import 'package:appim/widgets/trade_type_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Trade type filtering', () {
    test('provides unique stable type IDs', () {
      final ids = tradeTypes.map((type) => type.id).toList();

      expect(
        ids,
        containsAll([
          'phone',
          'tablet',
          'computer',
          'game_console',
          'home_appliance',
          'television',
          'camera',
          'vehicle',
          'motorcycle_bicycle',
          'clothing_accessories',
          'furniture_home',
          'sports_outdoor',
          'musical_instruments',
          'books_education',
          'toys_baby',
          'tools_hardware',
          'collectibles_hobby',
          'personal_care',
          'office_equipment',
          allTradeTypesId,
        ]),
      );
      expect(ids.toSet(), hasLength(ids.length));
    });

    test('keeps all listings when no trade type is selected', () {
      expect(
        listingMatchesTradeTypeFilter({'tradeEnabled': false}, <String>{}),
        isTrue,
      );
    });

    test('resolves desired trade type labels for search result cards', () {
      expect(
        listingDesiredTradeTypeLabels({
          'tradeEnabled': true,
          'tradePreferences': {
            'desiredTradeTypes': ['phone', 'tablet', 'unknown'],
          },
        }, (key) => key),
        ['trade_type_phone', 'trade_type_tablet'],
      );
      expect(
        listingDesiredTradeTypeLabels({'tradeEnabled': false}, (key) => key),
        isEmpty,
      );
    });

    test('requires an active trade preference when searching listings', () {
      expect(
        listingMatchesTradeTypeFilter(
          {
            'tradeEnabled': true,
            'tradePreferences': {
              'desiredTradeTypes': ['phone', 'tablet'],
            },
          },
          <String>{},
          requireDesiredTradeTypes: true,
        ),
        isTrue,
      );
      expect(
        listingMatchesTradeTypeFilter(
          {'tradeEnabled': true, 'tradePreferences': <String, dynamic>{}},
          <String>{},
          requireDesiredTradeTypes: true,
        ),
        isFalse,
      );
      expect(
        listingMatchesTradeTypeFilter(
          {
            'tradeEnabled': true,
            'tradePreferences': {
              'desiredTradeTypes': ['  '],
            },
          },
          <String>{},
          requireDesiredTradeTypes: true,
        ),
        isFalse,
      );
      expect(
        listingMatchesTradeTypeFilter(
          {
            'tradeEnabled': false,
            'tradePreferences': {
              'desiredTradeTypes': ['phone'],
            },
          },
          <String>{},
          requireDesiredTradeTypes: true,
        ),
        isFalse,
      );
    });

    test('matches only trade-enabled listings accepting a selected type', () {
      final listing = {
        'tradeEnabled': true,
        'tradePreferences': {
          'desiredTradeTypes': ['phone', 'tablet'],
        },
      };

      expect(listingMatchesTradeTypeFilter(listing, {'phone'}), isTrue);
      expect(listingMatchesTradeTypeFilter(listing, {'computer'}), isFalse);
      expect(
        listingMatchesTradeTypeFilter(
          {...listing, 'tradeEnabled': false},
          {'phone'},
        ),
        isFalse,
      );
    });

    test('does not match legacy listings without desired trade types', () {
      expect(
        listingMatchesTradeTypeFilter(
          {'tradeEnabled': true, 'tradePreferences': <String, dynamic>{}},
          {'phone'},
        ),
        isFalse,
      );
    });

    test('an all-types listing matches every selected trade type', () {
      final listing = {
        'tradeEnabled': true,
        'tradePreferences': {
          'desiredTradeTypes': [allTradeTypesId],
        },
      };

      expect(listingMatchesTradeTypeFilter(listing, {'phone'}), isTrue);
      expect(listingMatchesTradeTypeFilter(listing, {'computer'}), isTrue);
      expect(listingMatchesTradeTypeFilter(listing, {'tablet'}), isTrue);
    });

    test('all-types search matches any enabled listing', () {
      expect(
        listingMatchesTradeTypeFilter(
          {
            'tradeEnabled': true,
            'tradePreferences': {
              'desiredTradeTypes': ['phone'],
            },
          },
          {allTradeTypesId},
        ),
        isTrue,
      );
      expect(
        listingMatchesTradeTypeFilter(
          {'tradeEnabled': false},
          {allTradeTypesId},
        ),
        isFalse,
      );
    });
  });

  testWidgets('opens the two-column category dialog without layout errors', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TradeTypeSelector(
            selectedTypes: <String>{},
            onTypeToggled: (_) {},
          ),
        ),
      ),
    );

    await tester.tap(find.byType(OutlinedButton));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(Checkbox), findsNWidgets(tradeTypes.length));
  });
}
