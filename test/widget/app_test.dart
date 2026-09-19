import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/app.dart';
import 'package:wasfati/providers/recipes_state.dart';

import '../helpers.dart';

Future<void> pumpApp(
  WidgetTester tester,
  Locale locale, {
  double textScale = 1,
  bool withRecipe = false,
}) async {
  late RecipesState state;
  await tester.runAsync(() async {
    final (repo, _, _) = await testRepo();
    state = RecipesState(repo);
    if (withRecipe) await state.save(kabsa(repo));
    await state.load();
  });
  tester.view.physicalSize = const Size(1080, 2400); // a phone (LANG-6)
  tester.view.devicePixelRatio = 3;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
      child: WasfatiApp(recipes: state, locale: locale),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Arabic: right to left, Arabic text (LANG-5, RUN-1)', (
    tester,
  ) async {
    await pumpApp(tester, const Locale('ar'));
    expect(find.text('وصفاتي'), findsOneWidget);
    expect(find.text('لا توجد وصفات بعد'), findsOneWidget);
    expect(find.text('أضف وصفة'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('وصفاتي')));
    expect(dir, TextDirection.rtl);
  });

  testWidgets('English: left to right', (tester) async {
    await pumpApp(tester, const Locale('en'));
    expect(find.text('Wasfati'), findsOneWidget);
    expect(find.text('No recipes yet'), findsOneWidget);
    final dir = Directionality.of(tester.element(find.text('Wasfati')));
    expect(dir, TextDirection.ltr);
  });

  testWidgets('Arabic plural for the count (LANG-2)', (tester) async {
    await pumpApp(tester, const Locale('ar'), withRecipe: true);
    expect(find.text('وصفة واحدة'), findsOneWidget);
  });

  for (final lang in ['ar', 'en']) {
    testWidgets('$lang at 1.3× text size doesn\'t overflow (LANG-6)', (
      tester,
    ) async {
      await pumpApp(tester, Locale(lang), textScale: 1.3);
      expect(tester.takeException(), isNull);
    });
  }
}
