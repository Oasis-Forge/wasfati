// Settings as Sufra draws it (Decision 23): the Pro card (PAY-5, PAY-10),
// grouped rows whose choices open a sheet and apply at once (LOOK-1,
// LANG-1, PLAN-1, SCALE-5), the digits inline (QTY-5), the Ramadan switch
// and its shift (RAM-1, RAM-2), and the rows beside them — restore
// purchases (PAY-1), the privacy policy, contact and the version.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/ramadan.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/screens/settings_screen.dart';
import 'package:wasfati/services/backup_files.dart';
import 'package:wasfati/services/mail.dart' show supportEmail;
import 'package:wasfati/services/store.dart';
import 'package:wasfati/widgets/segmented_pill.dart';

import 'app_test.dart' show links, mail, pumpApp, settle, sharer, store;

/// Today (the fake clock's 19 September 2026) is Ramadan's fifth day.
const _ramadanDay5 = RamadanMonth(1448, 2026, 9, 15, 30);

Future<void> _openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('الإعدادات'));
  await settle(tester);
}

/// Scrolls Settings until [finder] is on screen.
Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(finder);
  await settle(tester);
}

/// A save dialog the user hasn't answered yet: Save stays busy until the
/// test calls [answer].
class _PendingBackupFiles extends NoopBackupFiles {
  final _answer = Completer<bool>();

  void answer() => _answer.complete(false);

  @override
  Future<bool> saveBytes(String name, List<int> bytes, String mimeType) =>
      _answer.future;
}

/// The row whose label is [label]: its value is on the same card row.
Finder _row(String label) =>
    find.ancestor(of: find.text(label), matching: find.byType(InkWell)).first;

void main() {
  group('each choice row opens its sheet, the current option ticked, and '
      'applies the choice at once', () {
    for (final (label, current, choice, check) in [
      (
        'المظهر',
        'حسب الجهاز',
        'داكن',
        (AppSettings s) => s.theme == ThemePref.dark,
      ),
      (
        'الوحدات',
        'مترية (غرام، مل)',
        'أكواب وملاعق',
        (AppSettings s) => s.units == UnitSystem.kitchen,
      ),
      (
        'بداية الأسبوع',
        'حسب المنطقة',
        'السبت',
        (AppSettings s) => s.weekStart == WeekStart.saturday,
      ),
      ('الطراز', 'زعفران', 'حبر', (AppSettings s) => s.style == AppStyle.ink),
    ]) {
      testWidgets('$label → $choice', (tester) async {
        final (_, settings) = await pumpApp(tester);
        await _openSettings(tester);
        await _scrollTo(tester, find.text(label));
        // The row shows its current value.
        expect(
          find.descendant(of: _row(label), matching: find.text(current)),
          findsOneWidget,
        );

        await tester.tap(find.text(label));
        await settle(tester);
        final sheet = find.byType(BottomSheet);
        expect(sheet, findsOneWidget);
        // The sheet's heading, and the current option ticked (only it).
        expect(
          find.descendant(of: sheet, matching: find.text(label)),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.widgetWithText(ListTile, current),
            matching: find.byIcon(Icons.check),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(of: sheet, matching: find.byIcon(Icons.check)),
          findsOneWidget,
        );

        await tester.tap(
          find.descendant(of: sheet, matching: find.text(choice)),
        );
        await settle(tester);
        expect(find.byType(BottomSheet), findsNothing);
        expect(check(settings.settings), isTrue);
        // The row now says so.
        expect(
          find.descendant(of: _row(label), matching: find.text(choice)),
          findsOneWidget,
        );
      });
    }

    testWidgets('المظهر → داكن turns the app dark at once (LANG-1)', (
      tester,
    ) async {
      await pumpApp(tester);
      await _openSettings(tester);
      expect(
        Theme.of(tester.element(find.text('المظهر'))).brightness,
        Brightness.light,
      );
      await tester.tap(find.text('المظهر'));
      await settle(tester);
      await tester.tap(find.text('داكن'));
      await settle(tester);
      expect(
        Theme.of(tester.element(find.text('المظهر'))).brightness,
        Brightness.dark,
      );
    });

    testWidgets('the Look sheet shows each accent as a swatch in its own '
        'colour (LOOK-1)', (tester) async {
      await pumpApp(tester);
      await _openSettings(tester);
      await tester.tap(find.text('الطراز'));
      await settle(tester);
      Color swatch(String name) {
        final dot = find.descendant(
          of: find.widgetWithText(ListTile, name),
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).shape == BoxShape.circle,
          ),
        );
        return (tester.widget<Container>(dot).decoration! as BoxDecoration)
            .color!;
      }

      expect(swatch('زعفران'), const Color(0xFFC2410C));
      expect(swatch('حبر'), const Color(0xFF0F766E));
    });
  });

  testWidgets('the digits are an inline 123 | ١٢٣ pill, not a sheet, and '
      'apply at once (QTY-5)', (tester) async {
    final (_, settings) = await pumpApp(tester);
    await _openSettings(tester);
    final pill = find.byType(SegmentedPill<DigitStyle>);
    expect(pill, findsOneWidget);
    expect(
      find.descendant(
        of: find
            .ancestor(of: find.text('الأرقام'), matching: find.byType(Row))
            .first,
        matching: pill,
      ),
      findsOneWidget,
    );
    // The Pro card's number is in the digits the user reads.
    expect(find.textContaining('100'), findsOneWidget);

    await tester.tap(find.descendant(of: pill, matching: find.text('١٢٣')));
    await settle(tester);
    expect(find.byType(BottomSheet), findsNothing);
    expect(settings.settings.digits, DigitStyle.arabic);
    expect(find.textContaining('١٠٠'), findsOneWidget);
    expect(find.textContaining('100'), findsNothing);
  });

  testWidgets('this year\'s start and its one-day shift show and work with '
      'the Ramadan mode off, and stay when it is turned off (RAM-1, RAM-2, '
      'RAM-3)', (tester) async {
    final (_, settings) = await pumpApp(
      tester,
      withRecipe: true,
      ramadanMonths: [_ramadanDay5],
    );
    await _openSettings(tester);
    await _scrollTo(tester, find.byTooltip('يوم أبكر'));
    expect(settings.settings.ramadanMode, isFalse);
    final start = find.textContaining('بداية رمضان');
    expect(start, findsOneWidget);
    final before = tester.widget<Text>(start).data;
    expect(find.byTooltip('يوم لاحق'), findsOneWidget);

    // Mode off: the shift still moves the start (it feeds RAM-3's card).
    await tester.tap(find.byTooltip('يوم أبكر'));
    await settle(tester);
    expect(tester.widget<Text>(start).data, isNot(before));
    expect(settings.settings.ramadanShift, -1);
    final shifted = tester.widget<Text>(start).data;

    // On, then off again: the shift and its control stay.
    for (final on in [true, false]) {
      await tester.ensureVisible(find.text('وضع رمضان'));
      await settle(tester);
      await tester.tap(find.text('وضع رمضان'));
      await settle(tester);
      expect(settings.settings.ramadanMode, on);
      expect(find.byTooltip('يوم أبكر'), findsOneWidget);
      expect(tester.widget<Text>(start).data, shifted);
      expect(settings.settings.ramadanShift, -1);
    }

    // And it can be undone with the mode off.
    await tester.ensureVisible(find.byTooltip('يوم لاحق'));
    await settle(tester);
    await tester.tap(find.byTooltip('يوم لاحق'));
    await settle(tester);
    expect(settings.settings.ramadanShift, 0);
    expect(tester.widget<Text>(start).data, before);
  });

  group('the Pro card (PAY-5, PAY-10)', () {
    testWidgets('says what Pro and Premium give, with no price, badge or '
        'countdown, and opens the purchase screen', (tester) async {
      await pumpApp(
        tester,
        storeOverride: NoopPurchaseStore(
          offers: const [StoreOffer(product: Product.pro, price: 'AED 14.99')],
        ),
      );
      await _openSettings(tester);
      expect(find.text('برو وبريميوم'), findsOneWidget);
      expect(
        find.text('أزل الإعلانات، أو ارفع الاستيراد الذكي إلى 100 شهريًا.'),
        findsOneWidget,
      );
      expect(find.textContaining('AED'), findsNothing);

      await tester.tap(find.text('برو وبريميوم'));
      await settle(tester);
      expect(find.byTooltip('إغلاق'), findsOneWidget); // the purchase screen
      expect(find.text('برو'), findsOneWidget);
    });

    for (final (owned, line) in [
      ({Product.pro}, 'لديك برو: بلا إعلانات.'),
      (
        {Product.premium},
        'لديك بريميوم: بلا إعلانات، و100 استيراد ذكي شهريًا.',
      ),
      (
        {Product.pro, Product.premium},
        'لديك برو وبريميوم: بلا إعلانات، و100 استيراد ذكي شهريًا.',
      ),
    ]) {
      testWidgets('says which is owned: ${owned.map((p) => p.name)}', (
        tester,
      ) async {
        await pumpApp(tester, storeOverride: NoopPurchaseStore(owned: owned));
        await _openSettings(tester);
        expect(find.text(line), findsOneWidget);
        expect(find.textContaining('أزل الإعلانات'), findsNothing);
      });
    }
  });

  testWidgets('restore purchases from Settings asks the store and says what '
      'it found (PAY-1)', (tester) async {
    await pumpApp(tester);
    await _openSettings(tester);
    await _scrollTo(tester, find.text('استعادة عمليات الشراء'));
    await tester.tap(find.text('استعادة عمليات الشراء'));
    await settle(tester);
    expect(
      find.text('لا عمليات شراء لوصفاتي على حساب Google هذا.'),
      findsOneWidget,
    );

    store.ownedNow = {Product.pro};
    await tester.tap(find.text('استعادة عمليات الشراء'));
    await settle(tester);
    expect(find.text('استُعيدت عمليات الشراء.'), findsOneWidget);
    expect(find.text('برو'), findsOneWidget); // the Subscription row's plan
  });

  testWidgets('about: the privacy policy opens in the browser, contact is a '
      'mail draft to the one support address, and the version shows', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSettings(tester);
    await _scrollTo(tester, find.text('الإصدار'));
    expect(
      find.descendant(of: _row('الإصدار'), matching: find.text('test')),
      findsOneWidget,
    );
    expect(find.text(supportEmail), findsOneWidget);

    await tester.tap(find.text('سياسة الخصوصية'));
    await settle(tester);
    expect(links.opened, [Uri.parse(privacyPolicyUrl)]);

    await tester.tap(find.text('راسلنا'));
    await settle(tester);
    expect(mail.drafts.single.to, 'oasisforge.support@gmail.com');
    expect(mail.drafts.single.body, isEmpty); // nothing sent behind the user

    // No mail app: the address to write to instead.
    mail.opens = false;
    await tester.tap(find.text('راسلنا'));
    await settle(tester);
    expect(find.textContaining(supportEmail), findsNWidgets(2));
  });

  testWidgets('pushed from elsewhere it has a way back; as a tab its title '
      'stands alone (LOOK-7)', (tester) async {
    await pumpApp(tester);
    await _openSettings(tester);
    expect(
      find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(BackButton),
      ),
      findsNothing,
    );
    expect(tester.getTopLeft(find.text('الإعدادات').first).dy, lessThan(100));
  });

  testWidgets('every row\'s value and chevron hug the row\'s end, so the '
      'chevrons line up down the screen (08-settings.png)', (tester) async {
    await pumpApp(tester);
    await _openSettings(tester);
    final xs = <String, double>{};
    for (final label in [
      'الطراز', // a value with a swatch
      'المظهر',
      'اللغة',
      'الوحدات',
      'بداية الأسبوع',
      'احفظ نسخة احتياطية', // no value
      'الاشتراك',
      'سياسة الخصوصية',
    ]) {
      await _scrollTo(tester, find.text(label));
      final chevron = find.descendant(
        of: _row(label),
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(chevron, findsOneWidget, reason: label);
      xs[label] = tester.getRect(chevron).left;
      if (label == 'المظهر') {
        // Right to left: the value sits just before the chevron (a 4dp
        // gap), not partway across the row.
        final value = tester.getRect(
          find.descendant(of: _row(label), matching: find.text('حسب الجهاز')),
        );
        expect(value.left, closeTo(tester.getRect(chevron).right + 4, 1));
      }
    }
    expect(xs.values.toSet(), hasLength(1), reason: '$xs');
  });

  testWidgets('the digits pill is an inline mini pill: a 28dp track in a 48dp '
      'tap target, and its row keeps the 60dp of its neighbours', (
    tester,
  ) async {
    await pumpApp(tester);
    await _openSettings(tester);
    final pill = find.byType(SegmentedPill<DigitStyle>);
    expect(tester.getSize(pill).height, 48);
    expect(tester.getSize(pill).width, lessThan(128));
    final track = find.descendant(
      of: pill,
      matching: find.byWidgetPredicate(
        (w) => w is Container && w.constraints?.maxHeight == 28,
      ),
    );
    expect(track, findsOneWidget);
    Size rowSize(Finder of) => tester.getSize(
      find
          .ancestor(
            of: of,
            matching: find.byWidgetPredicate(
              (w) => w is ConstrainedBox && w.constraints.minHeight == 60,
            ),
          )
          .first,
    );
    expect(rowSize(pill).height, rowSize(find.text('اللغة')).height);
    // Each option's tap target is the full 48dp.
    final option = find.ancestor(
      of: find.text('١٢٣'),
      matching: find.byType(InkWell),
    );
    expect(tester.getSize(option.first).height, 48);
    expect(tester.getSize(option.first).width, greaterThanOrEqualTo(48));
  });

  testWidgets('while a backup runs, its rows look and read as disabled, keep '
      'their chevrons, and do nothing; a progress line shows (BAK-6)', (
    tester,
  ) async {
    final files = _PendingBackupFiles();
    await pumpApp(tester, withRecipe: true, backupFilesOverride: files);
    await _openSettings(tester);
    await _scrollTo(tester, find.text('احفظ نسخة احتياطية'));
    const labels = [
      'احفظ نسخة احتياطية',
      'مشاركة النسخة',
      'استعادة',
      'تصدير كنص',
    ];
    final handle = tester.ensureSemantics();
    for (final label in labels) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isButton: true, isEnabled: true),
      );
    }
    expect(find.byType(LinearProgressIndicator), findsNothing);
    final enabledColour = tester
        .widget<Text>(find.text('مشاركة النسخة'))
        .style
        ?.color;

    await tester.tap(find.text('احفظ نسخة احتياطية'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    final disabled = Theme.of(tester.element(find.text('مشاركة النسخة')))
        .disabledColor;
    for (final label in labels) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isButton: true, isEnabled: false),
        reason: label,
      );
      expect(tester.widget<Text>(find.text(label)).style?.color, disabled);
      expect(
        find.descendant(
          of: _row(label),
          matching: find.byIcon(Icons.chevron_right),
        ),
        findsOneWidget,
        reason: label,
      );
    }
    expect(disabled, isNot(enabledColour));
    final shared = sharer.texts.length;
    await tester.tap(find.text('مشاركة النسخة'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(sharer.texts.length, shared);
    expect(find.byType(BottomSheet), findsNothing);

    // The dialog answered: everything is back.
    files.answer();
    await settle(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    for (final label in labels) {
      expect(
        tester.getSemantics(find.text(label)),
        isSemantics(isButton: true, isEnabled: true),
      );
      expect(tester.widget<Text>(find.text(label)).style?.color, enabledColour);
    }
    handle.dispose();
  });

  testWidgets('screens with no app bar still name their route for TalkBack: '
      'the purchase screen, and the walkthrough replayed from Settings', (
    tester,
  ) async {
    await pumpApp(tester);
    final handle = tester.ensureSemantics();
    await _openSettings(tester);
    await tester.tap(find.text('برو وبريميوم'));
    await settle(tester);
    expect(find.byTooltip('إغلاق'), findsOneWidget);
    expect(
      tester.getSemantics(find.text('برو وبريميوم')),
      isSemantics(isHeader: true, namesRoute: true),
    );
    await tester.tap(find.byTooltip('إغلاق'));
    await settle(tester);

    await _scrollTo(tester, find.text('اعرض الجولة التعريفية مجددًا'));
    await tester.tap(find.text('اعرض الجولة التعريفية مجددًا'));
    await settle(tester);
    expect(
      tester.getSemantics(find.text('احفظ الوصفات من أي منشور')),
      isSemantics(isHeader: true, namesRoute: true),
    );
    handle.dispose();
  });
}
