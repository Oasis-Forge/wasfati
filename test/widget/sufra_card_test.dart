// LOOK-6: SufraCard had no test at all — nothing pinned the light-shadow/
// dark-hairline swap (`Decor.liftShadow`/`Decor.cardHairline`) that is the
// whole point of the widget.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/theme/app_theme.dart';
import 'package:wasfati/theme/decor.dart';
import 'package:wasfati/widgets/sufra_card.dart';

void main() {
  Widget pump(Brightness brightness) => MaterialApp(
    theme: wasfatiTheme(AppStyle.saffron, brightness),
    home: const Scaffold(body: SufraCard(child: Text('محتوى'))),
  );

  Finder cardBox() => find.descendant(
    of: find.byType(SufraCard),
    matching: find.byType(Container),
  );

  testWidgets('light paints Decor.liftShadow with no border', (tester) async {
    await tester.pumpWidget(pump(Brightness.light));
    final context = tester.element(find.byType(SufraCard));
    final decor = Decor.of(context);
    final box = tester.widget<Container>(cardBox());
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.boxShadow, decor.liftShadow);
    expect(decoration.boxShadow, isNotEmpty);
    expect(decoration.border, isNull);
  });

  testWidgets(
    'dark paints no shadow, with a Decor.cardHairline border instead',
    (tester) async {
      await tester.pumpWidget(pump(Brightness.dark));
      final context = tester.element(find.byType(SufraCard));
      final decor = Decor.of(context);
      expect(decor.cardHairline, isNotNull);
      final box = tester.widget<Container>(cardBox());
      final decoration = box.decoration! as BoxDecoration;
      expect(decoration.boxShadow, isEmpty);
      expect(decoration.border, Border.all(color: decor.cardHairline!));
    },
  );

  testWidgets('a side replaces the dark hairline, in either theme (RUN-3)', (
    tester,
  ) async {
    const side = BorderSide(color: Color(0xFF123456), width: 2);
    for (final brightness in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: wasfatiTheme(AppStyle.saffron, brightness),
          home: const Scaffold(
            body: SufraCard(side: side, child: Text('محتوى')),
          ),
        ),
      );
      final decoration =
          tester.widget<Container>(cardBox()).decoration! as BoxDecoration;
      expect(decoration.border, const Border.fromBorderSide(side));
    }
  });

  testWidgets(
    'a card without onTap still gives a child InkWell an ink layer above '
    "its fill, so a grocery row's long press shows (GRO-4)",
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: wasfatiTheme(AppStyle.saffron, Brightness.light),
          home: Scaffold(
            body: SufraCard(
              child: InkWell(onLongPress: () {}, child: const Text('بصل')),
            ),
          ),
        ),
      );
      // The InkWell's Material is the card's own transparent layer, drawn
      // inside the card's fill, not the Scaffold's under it.
      final ink = Material.of(tester.element(find.text('بصل')));
      final inner = find.descendant(
        of: find.byType(SufraCard),
        matching: find.byType(Material),
      );
      expect(inner, findsOneWidget);
      expect(tester.widget<Material>(inner).type, MaterialType.transparency);
      expect(
        ink,
        same(
          Material.of(
            tester.element(
              find.descendant(of: inner, matching: find.byType(InkWell)),
            ),
          ),
        ),
      );
      final cardContext = tester.element(find.byType(SufraCard));
      expect(ink, isNot(same(Material.of(cardContext))));
    },
  );
}
