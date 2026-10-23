import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:astawash/main.dart';

void main() {
  testWidgets('app renders splash screen with branding', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(
      const ProviderScope(child: MyApp(initialLocation: '/splash')),
    );

    expect(find.text('Astawash'), findsOneWidget);
    expect(find.text('Keep track. Grow together.'), findsOneWidget);
  });

  testWidgets('app supports English and Amharic with bundled Ethiopic font', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: MyApp()));

    final app = tester.widget<MaterialApp>(find.byType(MaterialApp));
    final languageCodes = app.supportedLocales
        .map((locale) => locale.languageCode)
        .toSet();

    expect(languageCodes, containsAll(['en', 'am']));
    expect(app.theme?.textTheme.bodyMedium?.fontFamily, 'NotoSansEthiopic');
    expect(
      (await rootBundle.load(
        'assets/fonts/NotoSansEthiopic.ttf',
      )).lengthInBytes,
      greaterThan(0),
    );
  });
}
