import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smoking_areas/ui/location_disclosure.dart';

void main() {
  late SharedPreferences prefs;
  late BuildContext ctx;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(MaterialApp(
        home: Builder(builder: (context) {
          ctx = context;
          return const Scaffold();
        }),
      ));

  testWidgets('explains background use before asking; declining asks nothing',
      (tester) async {
    await pump(tester);
    bool? result;
    confirmLocationUse(ctx, prefs: prefs).then((v) => result = v);
    await tester.pumpAndSettle();
    expect(find.textContaining('in the background'), findsOneWidget);
    expect(find.textContaining('never sent'), findsOneWidget);
    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();
    expect(result, isFalse);

    // Shown again next time, because it was not accepted.
    confirmLocationUse(ctx, prefs: prefs).then((v) => result = v);
    await tester.pumpAndSettle();
    expect(find.text('Use of your location'), findsOneWidget);
  });

  testWidgets('accepted once, not shown again', (tester) async {
    await pump(tester);
    bool? result;
    confirmLocationUse(ctx, prefs: prefs).then((v) => result = v);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Continue'));
    await tester.pumpAndSettle();
    expect(result, isTrue);

    result = null;
    confirmLocationUse(ctx, prefs: prefs).then((v) => result = v);
    await tester.pumpAndSettle();
    expect(find.text('Use of your location'), findsNothing);
    expect(result, isTrue);
  });
}
