import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:appim/screens/responsive_layout.dart';

void main() {
  testWidgets('ResponsiveLayout renders correct breakpoint child', (
    WidgetTester tester,
  ) async {
    Future<void> pumpFor(Size size) async {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(size: size),
            child: Scaffold(
              body: ResponsiveLayout(
                child: Builder(
                  builder: (context) {
                    if (ResponsiveLayout.isMobile(context)) {
                      return const Text('mobile');
                    }
                    if (ResponsiveLayout.isTablet(context)) {
                      return const Text('tablet');
                    }
                    return const Text('desktop');
                  },
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
    }

    await pumpFor(const Size(500, 900));
    expect(find.text('mobile'), findsOneWidget);
    expect(find.text('tablet'), findsNothing);

    await pumpFor(const Size(800, 900));
    expect(find.text('tablet'), findsOneWidget);
    expect(find.text('desktop'), findsNothing);

    await pumpFor(const Size(1280, 900));
    expect(find.text('desktop'), findsOneWidget);
  });
}
