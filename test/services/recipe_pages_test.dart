// The share-image renderer (SHARE-3, SHARE-4): dart:ui drawing, so it needs
// a real (non-fake-timer) async zone — tester.runAsync — like the DB tests
// elsewhere (test/widget/ramadan_test.dart).
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/quantity/convert.dart';
import 'package:wasfati/models/quantity/format.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_share.dart';
import 'package:wasfati/models/settings.dart' show AppStyle;
import 'package:wasfati/services/recipe_pages.dart';
import 'package:wasfati/theme/colors.dart' show wasfatiColorScheme;

import '../helpers.dart';

const _notScaledMark = 'لم يُعدَّل';
String _unscaledLineText(String line, String mark) => '$line ($mark)';

/// A tiny, valid 1×1 PNG (should-fix, adversarial review: neither existing
/// renderer test ever exercises a real photo file).
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+A8AAQUBAScY'
  '42YAAAAASUVORK5CYII=',
);

Future<String> _writeFile(Directory dir, String name, List<int> bytes) async {
  final path = '${dir.path}${Platform.pathSeparator}$name';
  await File(path).writeAsBytes(bytes);
  return path;
}

/// A page's pixels, decoded back from its PNG (for the alignment check
/// below).
Future<({int width, Uint8List rgba})> _decodePixels(String path) async {
  final bytes = await File(path).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  final data = await frame.image.toByteData(format: ui.ImageByteFormat.rawRgba);
  return (width: frame.image.width, rgba: data!.buffer.asUint8List());
}

List<int> _pixel(({int width, Uint8List rgba}) png, int x, int y) {
  final i = (y * png.width + x) * 4;
  return [png.rgba[i], png.rgba[i + 1], png.rgba[i + 2], png.rgba[i + 3]];
}

bool _differs(List<int> a, List<int> b) =>
    List.generate(4, (i) => (a[i] - b[i]).abs()).any((d) => d > 10);

/// An opaque [Color]'s bytes, in the same `[r, g, b, a]` 0-255 shape
/// [_pixel] decodes from a PNG (`Color`'s own `.r`/`.g`/`.b`/`.a` are
/// normalized 0.0-1.0 doubles).
List<int> _rgba(Color c) =>
    [c.r, c.g, c.b, c.a].map((v) => (v * 255).round()).toList();

/// The left- and rightmost x where row [y] isn't the page's own background
/// (sampled at a known-blank corner), or null if the row is blank.
(int, int)? _inkRange(({int width, Uint8List rgba}) png, int y) {
  final bg = _pixel(png, 4, 4);
  int? minX, maxX;
  for (var x = 0; x < png.width; x++) {
    if (_differs(_pixel(png, x, y), bg)) {
      minX ??= x;
      maxX = x;
    }
  }
  return minX == null ? null : (minX, maxX!);
}

void main() {
  testWidgets('renders the kabsa recipe to 1,080×1,350 PNG pages (SHARE-3)', (
    tester,
  ) async {
    late Directory dir;
    List<String>? paths;

    await tester.runAsync(() async {
      final (repo, _, _) = await testRepo();
      dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
      final storage = FakeShareStorage(dir);

      paths = await renderSharePages(
        kabsa(repo),
        factor: Rational.one,
        view: UnitView.asWritten,
        digits: DigitStyle.western,
        uiDirection: TextDirection.rtl,
        style: AppStyle.ink,
        ingredientsHeading: 'المقادير',
        stepsHeading: 'الطريقة',
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: (n) => '$n حصص',
        prepTimeLabel: (m) => 'التحضير $m دقيقة',
        cookTimeLabel: (m) => 'الطبخ $m دقيقة',
        brand: 'وصفاتي',
        storage: storage,
      );

      // A short recipe (SHARE-3): well within the 6-page limit.
      expect(paths, isNotNull);
      expect(paths, isNotEmpty);
      expect(paths!.length, lessThanOrEqualTo(6));

      for (final path in paths!) {
        expect(File(path).existsSync(), isTrue);
        final bytes = await File(path).readAsBytes();
        final codec = await ui.instantiateImageCodec(bytes);
        final frame = await codec.getNextFrame();
        expect(frame.image.width, 1080);
        expect(frame.image.height, 1350);
      }

      await clearShareCache(storage); // SHARE-4
    });

    expect(dir.existsSync(), isFalse); // the whole folder is gone
  });

  testWidgets('a recipe with no photo still renders (SHARE-3)', (tester) async {
    await tester.runAsync(() async {
      final (repo, _, _) = await testRepo();
      final dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
      addTearDown(() {
        if (dir.existsSync()) dir.deleteSync(recursive: true);
      });
      final r = kabsa(repo);
      expect(r.photoPath, isNull);

      final paths = await renderSharePages(
        r,
        factor: Rational.one,
        view: UnitView.asWritten,
        digits: DigitStyle.western,
        uiDirection: TextDirection.rtl,
        style: AppStyle.ink,
        ingredientsHeading: 'المقادير',
        stepsHeading: 'الطريقة',
        notScaledMark: _notScaledMark,
        unscaledLineText: _unscaledLineText,
        servingsLabel: (n) => '$n حصص',
        prepTimeLabel: (m) => 'التحضير $m دقيقة',
        cookTimeLabel: (m) => 'الطبخ $m دقيقة',
        brand: 'وصفاتي',
        storage: FakeShareStorage(dir),
      );
      expect(paths, isNotNull);
    });
  });

  group('a real photo (should-fix, adversarial review)', () {
    testWidgets('a valid photo file renders without error', (tester) async {
      await tester.runAsync(() async {
        final (repo, _, _) = await testRepo();
        final dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
        final photoPath = await _writeFile(dir, 'photo.png', _tinyPngBytes);
        final r = kabsa(repo).copyWith(photoPath: photoPath);

        final paths = await renderSharePages(
          r,
          factor: Rational.one,
          view: UnitView.asWritten,
          digits: DigitStyle.western,
          uiDirection: TextDirection.rtl,
          style: AppStyle.ink,
          ingredientsHeading: 'المقادير',
          stepsHeading: 'الطريقة',
          notScaledMark: _notScaledMark,
          unscaledLineText: _unscaledLineText,
          servingsLabel: (n) => '$n حصص',
          prepTimeLabel: (m) => 'التحضير $m دقيقة',
          cookTimeLabel: (m) => 'الطبخ $m دقيقة',
          brand: 'وصفاتي',
          storage: FakeShareStorage(dir),
        );
        expect(paths, isNotNull);
      });
    });

    testWidgets('a missing photo file (BAK-9) renders without it instead of '
        'crashing (must-fix, adversarial review)', (tester) async {
      await tester.runAsync(() async {
        final (repo, _, _) = await testRepo();
        final dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
        final r = kabsa(
          repo,
        ).copyWith(photoPath: '${dir.path}${Platform.pathSeparator}gone.jpg');

        final paths = await renderSharePages(
          r,
          factor: Rational.one,
          view: UnitView.asWritten,
          digits: DigitStyle.western,
          uiDirection: TextDirection.rtl,
          style: AppStyle.ink,
          ingredientsHeading: 'المقادير',
          stepsHeading: 'الطريقة',
          notScaledMark: _notScaledMark,
          unscaledLineText: _unscaledLineText,
          servingsLabel: (n) => '$n حصص',
          prepTimeLabel: (m) => 'التحضير $m دقيقة',
          cookTimeLabel: (m) => 'الطبخ $m دقيقة',
          brand: 'وصفاتي',
          storage: FakeShareStorage(dir),
        );
        expect(paths, isNotNull); // never throws
      });
    });

    testWidgets('a corrupt photo file renders without it instead of crashing '
        '(must-fix, adversarial review)', (tester) async {
      await tester.runAsync(() async {
        final (repo, _, _) = await testRepo();
        final dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });
        final photoPath = await _writeFile(dir, 'bad.jpg', [1, 2, 3, 4, 5]);
        final r = kabsa(repo).copyWith(photoPath: photoPath);

        final paths = await renderSharePages(
          r,
          factor: Rational.one,
          view: UnitView.asWritten,
          digits: DigitStyle.western,
          uiDirection: TextDirection.rtl,
          style: AppStyle.ink,
          ingredientsHeading: 'المقادير',
          stepsHeading: 'الطريقة',
          notScaledMark: _notScaledMark,
          unscaledLineText: _unscaledLineText,
          servingsLabel: (n) => '$n حصص',
          prepTimeLabel: (m) => 'التحضير $m دقيقة',
          cookTimeLabel: (m) => 'الطبخ $m دقيقة',
          brand: 'وصفاتي',
          storage: FakeShareStorage(dir),
        );
        expect(paths, isNotNull); // never throws
      });
    });
  });

  group('SHARE-4: clearShareCache also clears share_plus leftovers '
      '(should-fix, adversarial review)', () {
    testWidgets('a leftover dir from a past share is deleted at startup', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final dir = await Directory.systemTemp.createTemp('wasfati_pages_test');
        final leftover = await Directory.systemTemp.createTemp(
          'wasfati_share_plus_test',
        );
        await File('${leftover.path}${Platform.pathSeparator}recipe-1.png')
            .writeAsBytes(_tinyPngBytes);
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
          if (leftover.existsSync()) leftover.deleteSync(recursive: true);
        });

        await clearShareCache(FakeShareStorage(dir, leftovers: [leftover]));

        expect(leftover.existsSync(), isFalse);
      });
    });
  });

  group(
    'shareBlockDirection (LANG-5, QTY-5, must-fix, adversarial review)',
    () {
      test("the facts line follows the app's language, not its own digits", () {
        final block = ShareBlock.facts('Serves ٦ · Prep ١٥ min');
        expect(
          shareBlockDirection(block, TextDirection.ltr),
          TextDirection.ltr,
        );
        expect(
          shareBlockDirection(block, TextDirection.rtl),
          TextDirection.rtl,
        );
      });

      test('a step reads by its own words, not the app-numbered prefix', () {
        final block = ShareBlock.step(
          '١. Heat the oven.',
          directionSource: 'Heat the oven.',
        );
        expect(
          shareBlockDirection(block, TextDirection.rtl),
          TextDirection.ltr,
        );
      });

      test(
        'an ingredient reads by the original line, not the formatted one',
        () {
          final block = ShareBlock.ingredient(
            '1 كوب أرز',
            directionSource: '1 cup rice',
          );
          expect(
            shareBlockDirection(block, TextDirection.rtl),
            TextDirection.ltr,
          );
        },
      );

      test('a title or heading reads by its own script', () {
        expect(
          shareBlockDirection(ShareBlock.title('كبسة'), TextDirection.ltr),
          TextDirection.rtl,
        );
        expect(
          shareBlockDirection(ShareBlock.heading('Method'), TextDirection.rtl),
          TextDirection.ltr,
        );
      });
    },
  );

  group('SHARE-3/LANG-5 alignment (must-fix, adversarial review): every block '
      "aligns to the app's own reading edge", () {
    testWidgets('an RTL app right-aligns content; an LTR app left-aligns it', (
      tester,
    ) async {
      await tester.runAsync(() async {
        final now = DateTime.utc(2026);
        final dir = await Directory.systemTemp.createTemp('wasfati_align_test');
        addTearDown(() {
          if (dir.existsSync()) dir.deleteSync(recursive: true);
        });

        // A Latin title: it reads left to right wherever it's shown
        // (LANG-5), so this isolates the ALIGNMENT bug (which edge the
        // block hugs) from direction (which way its own text reads).
        final recipe = Recipe(
          id: 'r1',
          title: 'Kabsa',
          createdAt: now,
          updatedAt: now,
        );

        Future<String> renderFirstPage(TextDirection uiDirection) async {
          final paths = await renderSharePages(
            recipe,
            factor: Rational.one,
            view: UnitView.asWritten,
            digits: DigitStyle.western,
            uiDirection: uiDirection,
            style: AppStyle.ink,
            ingredientsHeading: 'المقادير',
            stepsHeading: 'الطريقة',
            notScaledMark: _notScaledMark,
            unscaledLineText: _unscaledLineText,
            servingsLabel: (n) => '$n حصص',
            prepTimeLabel: (m) => 'التحضير $m دقيقة',
            cookTimeLabel: (m) => 'الطبخ $m دقيقة',
            brand: 'Wasfati',
            storage: FakeShareStorage(dir),
          );
          return paths!.first;
        }

        // The title's line starts at y = shareMargin (48) and is 44px,
        // so its ink sits well within the first ~70px.
        const titleRow = 65;

        final rtlPng = await _decodePixels(
          await renderFirstPage(TextDirection.rtl),
        );
        final rtlInk = _inkRange(rtlPng, titleRow);
        expect(rtlInk, isNotNull, reason: 'no ink found on the title row');
        // Right-aligned: ink should reach close to the right margin
        // (1080 - 48 = 1032), not sit flush against the left one.
        expect(rtlInk!.$2, greaterThan(900));

        final ltrPng = await _decodePixels(
          await renderFirstPage(TextDirection.ltr),
        );
        final ltrInk = _inkRange(ltrPng, titleRow);
        expect(ltrInk, isNotNull, reason: 'no ink found on the title row');
        // Left-aligned: ink should start close to the left margin (48),
        // not sit flush against the right one.
        expect(ltrInk!.$1, lessThan(150));

        // The two must actually differ: the RTL run's ink shouldn't
        // start where the LTR run's does.
        expect(rtlInk.$1, greaterThan(ltrInk.$1 + 200));
      });
    });
  });

  group('LOOK-1/SHARE-3: the page takes the chosen look\'s palette', () {
    testWidgets(
      'a page\'s background reads the surface token, and Saffron and Ink '
      'renders actually differ (Decision 23: the two accents share every '
      'neutral — page, card, sunk, ink — and differ only in accent colour, '
      'so the background is no longer a way to tell them apart)',
      (tester) async {
        await tester.runAsync(() async {
          final (repo, _, _) = await testRepo();
          final dir = await Directory.systemTemp.createTemp(
            'wasfati_pages_style_test',
          );
          addTearDown(() {
            if (dir.existsSync()) dir.deleteSync(recursive: true);
          });

          Future<({int width, Uint8List rgba})> renderFor(
            AppStyle style,
          ) async {
            final paths = await renderSharePages(
              kabsa(repo),
              factor: Rational.one,
              view: UnitView.asWritten,
              digits: DigitStyle.western,
              uiDirection: TextDirection.rtl,
              style: style,
              ingredientsHeading: 'المقادير',
              stepsHeading: 'الطريقة',
              notScaledMark: _notScaledMark,
              unscaledLineText: _unscaledLineText,
              servingsLabel: (n) => '$n حصص',
              prepTimeLabel: (m) => 'التحضير $m دقيقة',
              cookTimeLabel: (m) => 'الطبخ $m دقيقة',
              brand: 'وصفاتي',
              storage: FakeShareStorage(dir),
            );
            expect(paths, isNotNull);
            return _decodePixels(paths!.first);
          }

          final saffronPng = await renderFor(AppStyle.saffron);
          final inkPng = await renderFor(AppStyle.ink);

          final saffron = wasfatiColorScheme(
            AppStyle.saffron,
            Brightness.light,
          );
          final ink = wasfatiColorScheme(AppStyle.ink, Brightness.light);
          // Decision 23: the neutrals are shared now — only the accent
          // (primary) differs between the two.
          expect(saffron.surface, ink.surface);
          expect(saffron.primary, isNot(ink.primary));

          // A corner well clear of any text or the photo band: the page's
          // own background fill, read from the (now shared) surface token
          // rather than a fixed seed.
          expect(_pixel(saffronPng, 4, 4), _rgba(saffron.surface));
          expect(_pixel(inkPng, 4, 4), _rgba(ink.surface));

          // The two renders still differ somewhere (the accent-coloured
          // amounts, at least), proving the chosen look actually reaches
          // the page rather than being ignored.
          expect(saffronPng.rgba, isNot(equals(inkPng.rgba)));

          // Not just "differs somewhere" — the *chosen* accent actually
          // reaches the page, not a swapped one: `_drawFooter` fills the
          // whole footer band in `colors.primary`, so a pixel at its
          // vertical centre (clear of the brand/counter text at either
          // edge, LANG-5) pins the exact colour.
          final footerY = shareImageHeight - shareFooterHeight / 2;
          final footerX = shareImageWidth / 2;
          expect(
            _pixel(saffronPng, footerX.round(), footerY.round()),
            _rgba(saffron.primary),
          );
          expect(
            _pixel(inkPng, footerX.round(), footerY.round()),
            _rgba(ink.primary),
          );
        });
      },
    );
  });
}
