import 'package:flutter/material.dart';
import 'package:appim/widgets/defect_marker_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('defect marker photo mapping', () {
    test('reordering photos keeps markers attached to their photo', () {
      const markers = [
        DefectMarker(
          imageIndex: 0,
          x: 0.2,
          y: 0.3,
          description: 'Cover defect',
        ),
        DefectMarker(
          imageIndex: 2,
          x: 0.4,
          y: 0.5,
          description: 'Third photo defect',
        ),
      ];

      final reordered = reorderDefectMarkerImage(markers, 0, 2);

      expect(reordered.map((marker) => marker.imageIndex), [2, 1]);
    });

    test(
      'deleting a photo removes its markers and shifts following photos',
      () {
        const markers = [
          DefectMarker(
            imageIndex: 0,
            x: 0.2,
            y: 0.3,
            description: 'Cover defect',
          ),
          DefectMarker(
            imageIndex: 1,
            x: 0.4,
            y: 0.5,
            description: 'Deleted photo defect',
          ),
          DefectMarker(
            imageIndex: 2,
            x: 0.6,
            y: 0.7,
            description: 'Last photo defect',
          ),
        ];

        final remaining = removeDefectMarkerImage(markers, 1);

        expect(remaining.map((marker) => marker.imageIndex), [0, 1]);
        expect(remaining.last.description, 'Last photo defect');
      },
    );

    test('serializes and parses marker coordinates and description', () {
      const marker = DefectMarker(
        imageIndex: 1,
        x: 0.25,
        y: 0.75,
        description: 'Small scratch',
      );

      final parsed = DefectMarker.fromMap(marker.toMap());

      expect(parsed.imageIndex, marker.imageIndex);
      expect(parsed.x, marker.x);
      expect(parsed.y, marker.y);
      expect(parsed.description, marker.description);
    });
  });

  testWidgets(
    'saving a marker closes its dialog without disposing its field early',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => showDialog<String>(
                  context: context,
                  builder: (_) =>
                      const DefectDescriptionDialog(initialValue: ''),
                ),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), 'Small scratch');
      await tester.tap(find.byType(FilledButton));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('marker editor returns saved photo markers', (tester) async {
    const initialMarkers = [
      DefectMarker(imageIndex: 0, x: 0.5, y: 0.5, description: 'Small scratch'),
    ];
    List<DefectMarker>? returnedMarkers;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                returnedMarkers = await Navigator.push<List<DefectMarker>>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DefectMarkerEditorScreen(
                      images: const [],
                      initialMarkers: initialMarkers,
                    ),
                  ),
                );
              },
              child: const Text('Open editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open editor'));
    await tester.pumpAndSettle();
    final appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.backgroundColor, Colors.black);
    expect(appBar.foregroundColor, Colors.white);
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(TextButton),
      ),
    );
    await tester.pumpAndSettle();

    expect(returnedMarkers, initialMarkers);
  });

  test('cover fit maps visible image coordinates into the photo viewport', () {
    final position = defectMarkerDisplayPosition(
      viewportSize: const Size(200, 200),
      imageSize: const Size(400, 200),
      fit: BoxFit.cover,
      x: 0.75,
      y: 0.5,
    );
    final croppedPosition = defectMarkerDisplayPosition(
      viewportSize: const Size(200, 200),
      imageSize: const Size(400, 200),
      fit: BoxFit.cover,
      x: 0.1,
      y: 0.5,
    );

    expect(position, const Offset(200, 100));
    expect(croppedPosition, isNull);
  });

  test('contain fit keeps edge markers visible without cropping', () {
    final position = defectMarkerDisplayPosition(
      viewportSize: const Size(200, 200),
      imageSize: const Size(400, 200),
      fit: BoxFit.contain,
      x: 0.1,
      y: 0.5,
    );

    expect(position, const Offset(20, 100));
  });
}
