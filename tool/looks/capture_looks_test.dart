// LOOK-1–LOOK-9: a render harness, not a test suite. There is no emulator
// available, so this pumps the real app four times — حبر/light,
// حبر/dark, زعفران/light, زعفران/dark — and writes PNGs of the library,
// a recipe page, cook mode and Settings for a human to judge by eye.
//
// Deliberately NOT under test/: `flutter test` (CI, `/verify`) only globs
// test/, so this never runs there. Run it by hand:
//   flutter test tool/looks/capture_looks_test.dart
//
// Reuses test/widget/app_test.dart's `pumpApp` (fakes, seeded library) and
// `settle` exactly as every other widget test does — nothing here talks to
// a real device service.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader, rootBundle;
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

import 'package:wasfati/models/settings.dart' show AppStyle, ThemePref;

import '../../test/widget/app_test.dart' show pumpApp, settle;

/// Outside the repo, so nothing written here is ever committed by accident.
const _outDir =
    r'C:\Users\hussa\AppData\Local\Temp\claude\C--Users-hussa-OneDrive-Desktop-Claude-Codes-App-Project-wasfati\634bca8c-6018-41f9-866e-9c8ca1a9580c\scratchpad\looks';

/// Matches pubspec.yaml's `fonts:` entry for IBMPlexSansArabic (all four
/// bundled weights), so Arabic renders as real glyphs instead of tofu boxes
/// — `flutter test`'s default test font has no Arabic coverage.
const _fontAssets = [
  'assets/fonts/IBMPlexSansArabic-Regular.ttf',
  'assets/fonts/IBMPlexSansArabic-Medium.ttf',
  'assets/fonts/IBMPlexSansArabic-SemiBold.ttf',
  'assets/fonts/IBMPlexSansArabic-Bold.ttf',
];

const _pngSignature = [137, 80, 78, 71, 13, 10, 26, 10];

const _screens = ['library', 'recipe', 'cook', 'settings'];

const _combos = <(AppStyle, ThemePref, String, String)>[
  (AppStyle.ink, ThemePref.light, 'ink', 'light'),
  (AppStyle.ink, ThemePref.dark, 'ink', 'dark'),
  (AppStyle.saffron, ThemePref.light, 'saffron', 'light'),
  (AppStyle.saffron, ThemePref.dark, 'saffron', 'dark'),
];

/// Every screen captured this run, keyed `<style>-<brightness>-<screen>`,
/// so the final guard test can compare across combos without re-pumping.
final _captured = <String, Uint8List>{};

Future<void> _loadFonts() async {
  final loader = FontLoader('IBMPlexSansArabic');
  for (final asset in _fontAssets) {
    loader.addFont(rootBundle.load(asset));
  }
  await loader.load();
}

/// Captures the current screen and writes it to [_outDir]/[name].png.
///
/// `captureImage` (flutter_test) walks up from any element to the nearest
/// `RenderObject.isRepaintBoundary` ancestor — `RenderView` itself always is
/// one — so starting from the app's own `MaterialApp` element already
/// reaches a full-screen boundary with no extra `RepaintBoundary` widget
/// needed (same mechanism `matchesGoldenFile` uses).
///
/// Both `toImage`/`toByteData` (dart:ui, real Skia work) and
/// `File.writeAsBytes` (real disk I/O) need the real event loop, not the
/// `FakeAsync` zone `testWidgets` runs its body in — a first attempt at this
/// harness left the file write outside `runAsync`, which hung forever
/// (an empty file it did create, since opening the handle is the one
/// synchronous part, but the write's completion never arrived) rather than
/// failing loudly. Every real-async step lives in one `runAsync` call so
/// none of them can be missed like that again.
Future<void> _captureAndSave(WidgetTester tester, String name) async {
  Uint8List? bytes;
  await tester.runAsync(() async {
    final image = await captureImage(
      tester.element(find.byType(MaterialApp).first),
    );
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    bytes = byteData!.buffer.asUint8List();
    final file = File(p.join(_outDir, '$name.png'));
    await file.writeAsBytes(bytes!, flush: true);
  });
  final result = bytes!;
  expect(
    result.length,
    greaterThan(1000),
    reason: '$name.png is too small to be a real screenshot',
  );
  expect(
    result.sublist(0, 8),
    equals(_pngSignature),
    reason: '$name.png does not start with the PNG signature',
  );
  _captured[name] = result;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    Directory(_outDir).createSync(recursive: true);
    await _loadFonts();
  });

  for (final (style, theme, styleName, brightnessName) in _combos) {
    testWidgets('capture $styleName/$brightnessName', (tester) async {
      // withRecipe: true seeds the kabsa() fixture (helpers.dart): a
      // photo-less thumbnail, grouped Arabic ingredients with parsed
      // amounts (AmountLine's emphasis), and two Arabic steps — exactly
      // what this harness needs, already used by every other widget test.
      final (_, settings) = await pumpApp(tester, withRecipe: true);

      await tester.runAsync(
        () => settings.update(
          settings.settings.copyWith(style: style, theme: theme),
        ),
      );

      // 390×844 logical (dp) at 3x device pixels, the surface asked for —
      // same pattern as pumpApp's own 1080×2400 @3 (a phone).
      tester.view.physicalSize = const Size(1170, 2532);
      tester.view.devicePixelRatio = 3;
      addTearDown(tester.view.reset);
      await settle(tester);

      // 1. The library (home).
      await _captureAndSave(tester, '$styleName-$brightnessName-library');

      // 2. A recipe page, scrolled to its ingredients.
      await tester.tap(find.text('كبسة لحم'));
      await settle(tester);
      await tester.ensureVisible(find.text('المكونات'));
      await settle(tester);
      await _captureAndSave(tester, '$styleName-$brightnessName-recipe');

      // 3. Cook mode.
      await tester.ensureVisible(find.text('ابدأ الطبخ'));
      await settle(tester);
      await tester.tap(find.text('ابدأ الطبخ'));
      await settle(tester);
      await _captureAndSave(tester, '$styleName-$brightnessName-cook');

      // Back out to the library, then into Settings. Not
      // tester.binding.handlePopRoute() (the rest of app_test.dart's own
      // system-Back idiom): that member is `visibleForTesting` scoped to
      // files under test/, and this harness deliberately lives outside it
      // (so `flutter test`/CI never picks it up) — calling it from here
      // would fail `flutter analyze`. Tapping the real back buttons is
      // exactly what a user does anyway.
      await tester.tap(find.byTooltip('إغلاق وضع الطبخ')); // cook mode's close
      await settle(tester);
      await tester.tap(find.byType(BackButton)); // the recipe page's back
      await settle(tester);

      // 4. Settings.
      await tester.tap(find.byTooltip('الإعدادات'));
      await settle(tester);
      await _captureAndSave(tester, '$styleName-$brightnessName-settings');
    });
  }

  test('ink/light and saffron/light differ per screen (style guard)', () {
    for (final screen in _screens) {
      final ink = _captured['ink-light-$screen'];
      final saffron = _captured['saffron-light-$screen'];
      expect(ink, isNotNull, reason: 'missing ink-light-$screen capture');
      expect(
        saffron,
        isNotNull,
        reason: 'missing saffron-light-$screen capture',
      );
      expect(
        listEquals(ink, saffron),
        isFalse,
        reason:
            '$screen renders identically in حبر/Ink and زعفران/Saffron — '
            'the style might not be applied',
      );
    }
  });
}
