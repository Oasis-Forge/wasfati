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
}
