import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/recipe_import.dart' show ImportedRecipe;
import 'package:wasfati/services/ai_import.dart';

import 'app_test.dart'
    show importPhotos, mail, photoStore, pumpApp, settle, shown;

const _found = AiImportSuccess(
  ImportedRecipe(
    title: 'معمول بالتمر',
    ingredients: [
      (null, ['٣ أكواب سميد', 'كوب زبدة']),
    ],
    steps: [
      (null, ['يعجن السميد مع الزبدة']),
    ],
  ),
  model: 'haiku',
  promptVersion: '1',
  cached: false,
);

/// A page photo as the picker would hand it over.
Uint8List _page(int width, int height) =>
    img.encodePng(img.Image(width: width, height: height));

/// Scrolls the preview (a long form) until [text] is on screen.
Future<void> _scrollTo(WidgetTester tester, String text) =>
    tester.dragUntilVisible(
      find.text(text),
      find.byType(ListView).first,
      const Offset(0, -300),
    );

/// Waits, in real time, until [finder] shows: the real resize (IMP-10) runs
/// in a background isolate, which a large page can keep busy for longer
/// than one [settle].
Future<void> _waitFor(WidgetTester tester, Finder finder) async {
  for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await settle(tester);
  }
}

Future<void> _openImport(WidgetTester tester) async {
  await tester.tap(find.byTooltip('أضف وصفة'));
  await settle(tester);
  await tester.tap(find.text('استيراد من رابط'));
  await settle(tester);
}

void main() {
  testWidgets(
    'IMP-1, IMP-10: photos from the gallery show the cost line first, go '
    'out resized with no link or text, and the first becomes the photo',
    (tester) async {
      final ai = NoopAiImportClient()..nextResult = _found;
      final saved = <(String, Uint8List)>[];
      final (recipes, settings) = await pumpApp(
        tester,
        aiClient: ai,
        savePhoto: (id, bytes) async {
          saved.add((id, bytes));
          return '/photos/$id.jpg';
        },
      );
      final page1 = _page(2400, 1800);
      final page2 = _page(1200, 1600);
      importPhotos.next = [page1, page2];

      await _openImport(tester);
      expect(
        find.text('أو من صورة: صفحة من كتاب طبخ أو وصفة بخط اليد، حتى 4 صور.'),
        findsOneWidget,
      );
      await tester.tap(find.text('اختر من الصور'));
      await settle(tester);

      // IMP-3: nothing is sent until the user chooses to spend one.
      expect(importPhotos.calls, ['gallery:4']);
      expect(find.text('صورتان'), findsOneWidget);
      expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsOneWidget);
      expect(ai.requests, isEmpty);

      await tester.tap(find.text('استيراد'));
      await settle(tester);
      await _waitFor(tester, find.text('راجع واحفظ'));
      expect(find.text('راجع واحفظ'), findsOneWidget); // the preview (IMP-5)
      expect(find.text('معمول بالتمر'), findsOneWidget);

      final sent = ai.requests.single;
      expect((sent.url, sent.text), (null, null));
      expect(sent.images, hasLength(2));
      for (final jpeg in sent.images!) {
        final back = img.decodeJpg(jpeg)!; // a JPEG, not the picker's PNG
        expect(
          back.width > back.height ? back.width : back.height,
          lessThanOrEqualTo(1600),
        );
      }
      expect(saved.single.$2, same(page1)); // the first page is the photo
      expect(find.text('احذف الصورة'), findsOneWidget);
      expect(recipes.recipes, isEmpty);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      final r = recipes.recipes.single;
      expect(r.photoPath, '/photos/${r.id}.jpg');
      expect(r.sourceType, SourceType.photo);
      final full = (await tester.runAsync(() => recipes.repository.get(r.id)))!;
      expect(full.sourceUrl, isNull);
      expect(shown('3 أكواب سميد'), findsOneWidget); // parsed on the device
      expect(settings.aiImportsUsed, 1); // IMP-7: saved, so it counts
    },
  );

  testWidgets('REC-8, IMP-10: removing the photo in the preview saves the '
      'recipe with none, and its file goes', (tester) async {
    final ai = NoopAiImportClient()..nextResult = _found;
    final (recipes, _) = await pumpApp(
      tester,
      aiClient: ai,
      savePhoto: (id, _) async => '/photos/$id.jpg',
    );
    importPhotos.next = [_page(800, 600)];
    await _openImport(tester);
    await tester.tap(find.text('اختر من الصور'));
    await settle(tester);
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    await _waitFor(tester, find.text('راجع واحفظ'));

    await tester.tap(find.text('احذف الصورة'));
    await settle(tester);
    expect(find.text('احذف الصورة'), findsNothing);
    await tester.tap(find.text('حفظ'));
    await settle(tester);

    final r = recipes.recipes.single;
    expect(r.photoPath, isNull);
    expect(photoStore.deleted, ['/photos/${r.id}.jpg']);
  });

  testWidgets('IMP-1: the camera takes one page at a time, "أضف صفحة" takes '
      'the next, and cancelling sends nothing', (tester) async {
    final ai = NoopAiImportClient()..nextResult = _found;
    final (_, settings) = await pumpApp(tester, aiClient: ai);
    importPhotos.next = [_page(600, 800)];
    await _openImport(tester);

    await tester.tap(find.text('التقط صورة'));
    await settle(tester);
    expect(find.text('صورة واحدة'), findsOneWidget);
    await tester.tap(find.text('أضف صفحة'));
    await settle(tester);
    expect(find.text('صورتان'), findsOneWidget);
    expect(importPhotos.calls, ['camera', 'camera']);

    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    expect(ai.requests, isEmpty);
    expect(settings.aiImportsUsed, 0);
    expect(find.text('التقط صورة'), findsOneWidget); // back to the start
  });

  testWidgets('a cancelled pick changes nothing', (tester) async {
    final ai = NoopAiImportClient();
    await pumpApp(tester, aiClient: ai);
    await _openImport(tester);
    await tester.tap(find.text('اختر من الصور')); // picker returns nothing
    await settle(tester);
    expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsNothing);
    expect(ai.requests, isEmpty);
  });

  testWidgets('SRV-7: too many or too large photos get their own message', (
    tester,
  ) async {
    final ai = NoopAiImportClient()
      ..nextResult = const AiImportError(AiImportErrorKind.tooLarge);
    await pumpApp(tester, aiClient: ai);
    importPhotos.next = [_page(300, 400)];
    await _openImport(tester);
    await tester.tap(find.text('اختر من الصور'));
    await settle(tester);
    await tester.tap(find.text('استيراد'));
    await settle(tester);
    await _waitFor(
      tester,
      find.text('الصور أكبر من أن تُرسل. جرّب صورًا أقل.'),
    );
    expect(
      find.text('الصور أكبر من أن تُرسل. جرّب صورًا أقل.'),
      findsOneWidget,
    );
  });

  testWidgets(
    'IMP-12: an unreadable post offers a screenshot too, which goes through '
    'photo import and still saves with the post\'s link',
    (tester) async {
      final ai = NoopAiImportClient()
        ..nextResult = const AiImportError(AiImportErrorKind.privatePost);
      final (recipes, settings) = await pumpApp(tester, aiClient: ai);
      await _openImport(tester);
      await tester.enterText(
        find.byType(TextField),
        'https://www.instagram.com/p/abc/?igsh=x',
      );
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(
        find.text('هذا الحساب أو المنشور خاص، فلا يمكن قراءة محتواه.'),
        findsOneWidget,
      );

      ai.nextResult = _found;
      importPhotos.next = [_page(1080, 2400)];
      await tester.tap(find.text('أو صورة للشاشة'));
      await settle(tester);
      expect(importPhotos.calls, ['gallery:4']);
      // The cost line and one choice, before anything is sent (IMP-3).
      expect(find.text('صورة واحدة'), findsOneWidget);
      expect(find.textContaining('سيُستخدم استيراد ذكي واحد'), findsOneWidget);
      expect(find.text('استيراد'), findsOneWidget);
      expect(ai.requests, hasLength(1)); // only the link attempt so far

      await tester.tap(find.text('استيراد'));
      await settle(tester);
      await _waitFor(tester, find.text('راجع واحفظ'));
      expect(ai.requests, hasLength(2));
      final shot = ai.requests.last;
      expect((shot.url, shot.text), (null, null));
      expect(shot.images, hasLength(1));
      expect(find.text('راجع واحفظ'), findsOneWidget);

      await tester.tap(find.text('حفظ'));
      await settle(tester);
      final r = recipes.recipes.single;
      final full = (await tester.runAsync(() => recipes.repository.get(r.id)))!;
      expect(full.sourceUrl, 'https://instagram.com/p/abc'); // IMP-9, IMP-12
      expect(r.sourceType, SourceType.social);
      expect(settings.aiImportsUsed, 1); // only the screenshot, when saved
    },
  );

  group('IMP-8, Decision 19: "أبلغ عن خطأ" in the preview', () {
    testWidgets('a link import: a draft to the support address holding just '
        'the link and the note', (tester) async {
      await pumpApp(tester);
      await _openImport(tester);
      await tester.enterText(find.byType(TextField), 'https://site.com/kabsa');
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      expect(find.text('راجع واحفظ'), findsOneWidget);

      await _scrollTo(tester, 'أبلغ عن خطأ');
      await tester.tap(find.text('أبلغ عن خطأ'));
      await settle(tester);
      expect(
        find.text(
          'يُفتح بريدك برسالة فيها رابط المصدر وملاحظتك فقط، وأنت من يرسلها.',
        ),
        findsOneWidget,
      );
      expect(mail.drafts, isEmpty); // nothing until Send
      await tester.enterText(
        find.widgetWithText(TextField, 'ما الخطأ؟ (اختياري)'),
        'الدجاج صار ١ كيلو',
      );
      await tester.tap(find.text('إرسال'));
      await settle(tester);

      expect(mail.drafts.single, (
        to: 'oasisforge.support@gmail.com',
        subject: 'وصفتي: خطأ في وصفة مستوردة',
        body: 'https://site.com/kabsa\n\nالدجاج صار ١ كيلو',
      ));
      // Still in the preview, nothing saved.
      expect(find.text('راجع واحفظ'), findsOneWidget);
    });

    testWidgets('a photo import has no link: the draft holds just the note', (
      tester,
    ) async {
      final ai = NoopAiImportClient()..nextResult = _found;
      await pumpApp(
        tester,
        aiClient: ai,
        savePhoto: (id, _) async => '/photos/$id.jpg',
      );
      importPhotos.next = [_page(400, 600)];
      await _openImport(tester);
      await tester.tap(find.text('اختر من الصور'));
      await settle(tester);
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      await _waitFor(tester, find.text('راجع واحفظ'));

      await _scrollTo(tester, 'أبلغ عن خطأ');
      await tester.tap(find.text('أبلغ عن خطأ'));
      await settle(tester);
      expect(
        find.text('يُفتح بريدك برسالة فيها ملاحظتك فقط، وأنت من يرسلها.'),
        findsOneWidget,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'ما الخطأ؟ (اختياري)'),
        'نقصت خطوة الخبز',
      );
      await tester.tap(find.text('إرسال'));
      await settle(tester);

      expect(mail.drafts.single, (
        to: 'oasisforge.support@gmail.com',
        subject: 'وصفتي: خطأ في وصفة مستوردة',
        body: 'نقصت خطوة الخبز',
      ));
    });

    testWidgets('cancelling opens nothing; with no mail app, the address is '
        'shown instead', (tester) async {
      await pumpApp(tester);
      await _openImport(tester);
      await tester.enterText(find.byType(TextField), 'https://site.com/kabsa');
      await tester.tap(find.text('استيراد'));
      await settle(tester);
      await _scrollTo(tester, 'أبلغ عن خطأ');

      await tester.tap(find.text('أبلغ عن خطأ'));
      await settle(tester);
      await tester.tap(find.text('إلغاء'));
      await settle(tester);
      expect(mail.drafts, isEmpty);

      mail.opens = false;
      await tester.tap(find.text('أبلغ عن خطأ'));
      await settle(tester);
      await tester.tap(find.text('إرسال'));
      await settle(tester);
      expect(mail.drafts.single.body, 'https://site.com/kabsa');
      expect(
        find.text(
          'لا يوجد تطبيق بريد على هذا الجهاز. راسلنا على '
          'oasisforge.support@gmail.com',
        ),
        findsOneWidget,
      );
    });

    testWidgets('a recipe edited outside an import has no report action', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.tap(find.text('أضف وصفة'));
      await settle(tester);
      await tester.tap(find.text('أضفها بنفسك'));
      await settle(tester);
      await tester.drag(find.byType(ListView).first, const Offset(0, -2000));
      await settle(tester);
      expect(find.text('أبلغ عن خطأ'), findsNothing);
    });
  });
}
