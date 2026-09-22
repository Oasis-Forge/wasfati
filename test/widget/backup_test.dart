// Backup screens (BAK-1–BAK-10), over a fake BackupFiles and a NoopSharer.
// Rule IDs are cited in each test's name.
import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/db/db_helper.dart';
import 'package:wasfati/models/settings.dart';
import 'package:wasfati/services/backup_files.dart';
import 'package:wasfati/services/sharer.dart';

import '../helpers.dart' show kabsa, testBackupFixture;
import 'app_test.dart' show backupFiles, clock, pumpApp, settle, sharer, shown;

/// A [BackupFiles] that fails every call, as if the platform's own dialog
/// couldn't complete the hand-off (must-fix, platform review): distinct
/// from [backupFiles]'s usual "the user cancelled" (null/false).
class _ThrowingBackupFiles implements BackupFiles {
  @override
  Future<bool> saveBytes(String name, List<int> bytes, String mimeType) async {
    throw const BackupFilesError();
  }

  @override
  Future<List<int>?> openFile() async {
    throw const BackupFilesError();
  }
}

/// A [Sharer] that fails, as the share sheet itself might (must-fix,
/// platform review: sharing had no error path at all).
class _ThrowingSharer implements Sharer {
  @override
  Future<void> shareText(String text, {String? subject}) async {
    throw Exception('boom');
  }

  @override
  Future<void> shareFiles(List<String> paths, {String? text}) async {
    throw Exception('boom');
  }
}

/// A minimal, hand-built backup.json, zipped, for the tests that need a
/// specific shape rather than one from a real [testBackupFixture].
List<int> _zipOf(Map<String, Object?> json) {
  final archive = Archive()
    ..addFile(ArchiveFile.string('backup.json', jsonEncode(json)));
  return ZipEncoder().encodeBytes(archive);
}

/// Scrolls the Settings screen's list until [finder] is on screen, then
/// nudges it fully into the viewport (not just built within the list's
/// cache extent) so a tap lands on it. Its backup section sits below
/// several other sections, so most of these tests need this before tapping
/// one of its rows.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  final scrollable = find.byType(Scrollable).first;
  for (var i = 0; i < 30 && finder.evaluate().isEmpty; i++) {
    await tester.drag(scrollable, const Offset(0, -300));
    await tester.pump();
  }
  await tester.ensureVisible(finder);
  await settle(tester);
}

Future<void> openSettings(WidgetTester tester) async {
  await tester.tap(find.byTooltip('الإعدادات'));
  await settle(tester);
}

/// Keeps calling [settle] until [finder] shows up, up to [max] times: a
/// restore's own chain of awaits (reloading every state, BAK-8's
/// lastBackupAt, the automatic-backups list) can outlast one [settle] pass.
Future<void> waitFor(WidgetTester tester, Finder finder, {int max = 6}) async {
  for (var i = 0; i < max && finder.evaluate().isEmpty; i++) {
    await settle(tester);
  }
}

void main() {
  testWidgets('BAK-1, BAK-6, BAK-8: save a backup hands the fake a .zip and '
      'sets lastBackupAt', (tester) async {
    final (_, settings) = await pumpApp(tester, withRecipe: true);
    await openSettings(tester);
    await scrollTo(tester, find.text('احفظ نسخة احتياطية'));
    expect(settings.settings.lastBackupAt, isNull);

    await tester.tap(find.text('احفظ نسخة احتياطية'));
    await settle(tester);

    expect(backupFiles.saved, hasLength(1));
    expect(backupFiles.saved.single.name, endsWith('.zip'));
    expect(backupFiles.saved.single.mimeType, 'application/zip');
    expect(settings.settings.lastBackupAt, isNotNull);
    expect(find.text('تم حفظ النسخة الاحتياطية'), findsOneWidget);
  });

  testWidgets(
    'BAK-7: restore → the counts sheet → دمج merges, and the library shows '
    'the restored recipe',
    (tester) async {
      await pumpApp(tester);
      late List<int> bytes;
      await tester.runAsync(() async {
        final fixture = await testBackupFixture();
        await fixture.recipes.save(kabsa(fixture.recipes, title: 'من النسخة'));
        bytes = await fixture.backup.createBackup();
        await fixture.dispose();
      });

      backupFiles.nextOpen = bytes;
      await openSettings(tester);
      await scrollTo(tester, find.text('استعادة'));
      await tester.tap(find.text('استعادة'));
      await settle(tester);

      // BAK-7: what the file holds, before anything is touched.
      expect(find.text('محتوى الملف'), findsOneWidget);
      expect(find.textContaining('وصفة'), findsWidgets);

      await tester.tap(find.text('دمج'));
      await waitFor(tester, find.text('اكتملت الاستعادة'));

      // BAK-3: the result names what was added.
      expect(find.text('اكتملت الاستعادة'), findsOneWidget);
      expect(find.textContaining('أُضيف'), findsOneWidget);
      await tester.tap(find.text('تم'));
      await settle(tester);

      await tester.binding.handlePopRoute(); // back to the library
      await settle(tester);
      expect(shown('من النسخة'), findsOneWidget);
    },
  );

  testWidgets('BAK-7: استبدال asks a second time before touching anything', (
    tester,
  ) async {
    await pumpApp(tester, withRecipe: true);
    late List<int> bytes;
    await tester.runAsync(() async {
      final fixture = await testBackupFixture();
      await fixture.recipes.save(kabsa(fixture.recipes, title: 'من النسخة'));
      bytes = await fixture.backup.createBackup();
      await fixture.dispose();
    });

    backupFiles.nextOpen = bytes;
    await openSettings(tester);
    await scrollTo(tester, find.text('استعادة'));
    await tester.tap(find.text('استعادة'));
    await settle(tester);

    await tester.tap(find.text('استبدال')); // 1st: in the counts sheet
    await settle(tester);
    expect(find.text('استبدال كل البيانات؟'), findsOneWidget); // 2nd: confirm

    await tester.tap(find.text('إلغاء'));
    await settle(tester);
    expect(find.text('اكتملت الاستعادة'), findsNothing); // nothing happened

    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(shown('كبسة لحم'), findsOneWidget); // the original, untouched
    expect(shown('من النسخة'), findsNothing);
  });

  testWidgets(
    'BAK-4: a file that is not a Wasfati backup shows the message and '
    'changes nothing',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      backupFiles.nextOpen = utf8.encode('just some plain text, not a zip');

      await openSettings(tester);
      await scrollTo(tester, find.text('استعادة'));
      await tester.tap(find.text('استعادة'));
      await settle(tester);

      expect(find.text('هذا ليس ملف نسخة احتياطية من وصفاتي.'), findsOneWidget);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget); // untouched
    },
  );

  testWidgets(
    'BAK-8: the reminder card shows with 10 recipes and no backup; "لاحقًا" '
    'hides it',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await tester.runAsync(() async {
        final repo = recipes.repository;
        for (var i = 0; i < 10; i++) {
          await recipes.save(kabsa(repo, title: 'وصفة $i'));
        }
      });
      await settle(tester);

      expect(find.text('لم تحفظ نسخة احتياطية بعد'), findsOneWidget);

      await tester.tap(find.text('لاحقًا'));
      await settle(tester);
      expect(find.text('لم تحفظ نسخة احتياطية بعد'), findsNothing);
    },
  );

  testWidgets(
    'BAK-10: export as text for one cookbook reaches the fake with the '
    "recipe's title",
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await tester.runAsync(() async {
        final repo = recipes.repository;
        final bookId = await recipes.saveCookbook('حلويات');
        await recipes.save(kabsa(repo).copyWith(cookbookIds: [bookId!]));
        await recipes.save(kabsa(repo, title: 'خارج الكتاب'));
      });
      await settle(tester);

      await openSettings(tester);
      await scrollTo(tester, find.text('تصدير كنص'));
      await tester.tap(find.text('تصدير كنص'));
      await settle(tester);
      await tester.tap(find.text('حلويات'));
      await settle(tester);

      expect(backupFiles.saved, hasLength(1));
      expect(backupFiles.saved.single.name, endsWith('.txt'));
      final text = utf8.decode(backupFiles.saved.single.bytes);
      expect(text, contains('كبسة لحم'));
      expect(text, isNot(contains('خارج الكتاب')));
      expect(find.text('تم حفظ ملف التصدير'), findsOneWidget);
    },
  );

  testWidgets(
    'BAK-9: a recipe whose photo file is missing shows no image error, on '
    'the recipe page and in the library grid',
    (tester) async {
      final (recipes, _) = await pumpApp(tester);
      await tester.runAsync(() async {
        final repo = recipes.repository;
        await recipes.save(
          kabsa(repo).copyWith(photoPath: '/no/such/file-ever.jpg'),
        );
      });
      await settle(tester);

      // The library grid.
      await tester.tap(find.byTooltip('عرض شبكي'));
      await settle(tester);
      expect(find.byType(GridView), findsOneWidget);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(tester.takeException(), isNull);

      // The recipe page.
      await tester.tap(shown('كبسة لحم'));
      await settle(tester);
      expect(find.byIcon(Icons.broken_image), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets(
      '${lang.name} at 1.3× text size: the Settings backup section has no '
      'overflow (LANG-6)',
      (tester) async {
        await pumpApp(tester, language: lang, textScale: 1.3, withRecipe: true);
        await tester.tap(
          find.byTooltip(lang == LanguagePref.ar ? 'الإعدادات' : 'Settings'),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);

        // Scrolling to the backup reminder switch (the section's last row
        // but one) renders every row above it, the backup section included.
        await scrollTo(
          tester,
          find.text(
            lang == LanguagePref.ar
                ? 'التذكير بالنسخ الاحتياطي'
                : 'Backup reminder',
          ),
        );
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final lang in [LanguagePref.ar, LanguagePref.en]) {
    testWidgets(
      '${lang.name} at 1.3× text size: the backup reminder card does not '
      'overflow (must-fix, platform review)',
      (tester) async {
        final (recipes, settingsState) = await pumpApp(
          tester,
          language: lang,
          textScale: 1.3,
        );
        await tester.runAsync(() async {
          final repo = recipes.repository;
          for (var i = 0; i < 10; i++) {
            await recipes.save(kabsa(repo, title: 'وصفة $i'));
          }
          // tester.runAsync: a real (non-fake-timer) DB write, called
          // outside any widget event handler, needs to escape the
          // fake-async zone or it never resolves (same reason
          // ramadan_test.dart wraps its own direct settings.update calls).
          await settingsState.update(
            settingsState.settings.copyWith(
              lastBackupAt: clock.now.subtract(const Duration(days: 45)),
            ),
          );
        });
        await settle(tester);

        // A plain end-aligned Row overflowed here (13px in Arabic, 51px in
        // English) because the card's two buttons plus their gap no longer
        // fit a 360dp-equivalent phone at 1.3×.
        expect(tester.takeException(), isNull);
        expect(
          find.text(
            lang == LanguagePref.ar
                ? 'آخر نسخة احتياطية قبل 45 يومًا'
                : 'Last backup was 45 days ago',
          ),
          findsOneWidget,
        );
      },
    );
  }

  testWidgets(
    'BAK-7: Replace needs two separate confirmations, the second styled '
    'destructive, before anything is touched (must-fix, platform review)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      late List<int> bytes;
      await tester.runAsync(() async {
        final fixture = await testBackupFixture();
        await fixture.recipes.save(kabsa(fixture.recipes, title: 'من النسخة'));
        bytes = await fixture.backup.createBackup();
        await fixture.dispose();
      });

      Future<void> openReplaceFlow() async {
        backupFiles.nextOpen = bytes;
        await openSettings(tester);
        await scrollTo(tester, find.text('استعادة'));
        await tester.tap(find.text('استعادة'));
        await settle(tester);
        await tester.tap(find.text('استبدال')); // the counts sheet's choice
        await settle(tester);
      }

      // Cancelling the FIRST dialog (what will be lost) changes nothing.
      await openReplaceFlow();
      expect(find.text('استبدال كل البيانات؟'), findsOneWidget);
      await tester.tap(find.text('إلغاء'));
      await settle(tester);
      expect(find.text('هل أنت متأكد؟'), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget);

      // Confirming the first, then cancelling the SECOND (are you sure?)
      // also changes nothing.
      await openReplaceFlow();
      await tester.tap(find.text('استبدال')); // dialog 1's own button
      await settle(tester);
      expect(find.text('هل أنت متأكد؟'), findsOneWidget); // dialog 2
      await tester.tap(find.text('إلغاء'));
      await settle(tester);
      expect(find.text('اكتملت الاستعادة'), findsNothing);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget);
      expect(shown('من النسخة'), findsNothing);

      // Confirming both actually replaces.
      await openReplaceFlow();
      await tester.tap(find.text('استبدال'));
      await settle(tester);
      await tester.tap(find.text('استبدال')); // dialog 2's destructive button
      await waitFor(tester, find.text('اكتملت الاستعادة'));
      expect(find.text('اكتملت الاستعادة'), findsOneWidget);
      await tester.tap(find.text('تم'));
      await settle(tester);
      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(shown('من النسخة'), findsOneWidget);
      expect(shown('كبسة لحم'), findsNothing);
    },
  );

  testWidgets(
    'BAK-6, BAK-8: sharing hands the sharer a .zip and counts as a backup; '
    'restoring never does (should-fix, platform review)',
    (tester) async {
      final (_, settingsState) = await pumpApp(tester, withRecipe: true);
      expect(settingsState.settings.lastBackupAt, isNull);

      await openSettings(tester);
      await scrollTo(tester, find.text('مشاركة النسخة'));
      await tester.tap(find.text('مشاركة النسخة'));
      await settle(tester);

      expect(sharer.filePaths, hasLength(1));
      expect(sharer.filePaths.single.single, endsWith('.zip'));
      expect(settingsState.settings.lastBackupAt, isNotNull);
      final afterShare = settingsState.settings.lastBackupAt;

      clock.advance(const Duration(days: 2));
      late List<int> bytes;
      await tester.runAsync(() async {
        final fixture = await testBackupFixture();
        await fixture.recipes.save(kabsa(fixture.recipes, title: 'من النسخة'));
        bytes = await fixture.backup.createBackup();
        await fixture.dispose();
      });
      backupFiles.nextOpen = bytes;
      await scrollTo(tester, find.text('استعادة'));
      await tester.tap(find.text('استعادة'));
      await settle(tester);
      await tester.tap(find.text('دمج'));
      await waitFor(tester, find.text('اكتملت الاستعادة'));
      await tester.tap(find.text('تم'));
      await settle(tester);

      // An automatic backup never leaves the phone (BAK-9), so restoring
      // must not move lastBackupAt the way Save and Share do.
      expect(settingsState.settings.lastBackupAt, afterShare);
    },
  );

  testWidgets(
    'BAK-7: a file the system picker itself fails to hand back says so '
    '(must-fix, platform review)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        backupFilesOverride: _ThrowingBackupFiles(),
      );
      await openSettings(tester);
      await scrollTo(tester, find.text('استعادة'));
      await tester.tap(find.text('استعادة'));
      await settle(tester);
      expect(find.text('تعذّر فتح هذا الملف.'), findsOneWidget);
    },
  );

  testWidgets('BAK-6: a save that fails says so (must-fix, platform review)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      withRecipe: true,
      backupFilesOverride: _ThrowingBackupFiles(),
    );
    await openSettings(tester);
    await scrollTo(tester, find.text('احفظ نسخة احتياطية'));
    await tester.tap(find.text('احفظ نسخة احتياطية'));
    await settle(tester);
    expect(find.text('تعذّر حفظ النسخة الاحتياطية.'), findsOneWidget);
  });

  testWidgets(
    'BAK-8: a failed save from the reminder card re-enables its buttons '
    '(must-fix, platform review)',
    (tester) async {
      final (recipes, _) = await pumpApp(
        tester,
        backupFilesOverride: _ThrowingBackupFiles(),
      );
      await tester.runAsync(() async {
        final repo = recipes.repository;
        for (var i = 0; i < 10; i++) {
          await recipes.save(kabsa(repo, title: 'وصفة $i'));
        }
      });
      await settle(tester);
      expect(find.text('لم تحفظ نسخة احتياطية بعد'), findsOneWidget);

      await tester.tap(find.text('احفظ الآن'));
      await settle(tester);
      expect(find.text('تعذّر حفظ النسخة الاحتياطية.'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'احفظ الآن'),
      );
      expect(button.onPressed, isNotNull); // not stuck disabled
    },
  );

  testWidgets(
    'BAK-6: a share that fails to complete says so (must-fix, platform '
    'review)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        sharerOverride: _ThrowingSharer(),
      );
      await openSettings(tester);
      await scrollTo(tester, find.text('مشاركة النسخة'));
      await tester.tap(find.text('مشاركة النسخة'));
      await settle(tester);
      expect(find.text('تعذّر مشاركة النسخة الاحتياطية.'), findsOneWidget);
    },
  );

  testWidgets(
    'BAK-10: an export that fails to save says so (must-fix, platform '
    'review)',
    (tester) async {
      await pumpApp(
        tester,
        withRecipe: true,
        backupFilesOverride: _ThrowingBackupFiles(),
      );
      await openSettings(tester);
      await scrollTo(tester, find.text('تصدير كنص'));
      await tester.tap(find.text('تصدير كنص'));
      await settle(tester);
      await tester.tap(find.text('كل الوصفات'));
      await settle(tester);
      expect(find.text('تعذّر حفظ ملف التصدير.'), findsOneWidget);
    },
  );

  testWidgets('BAK-10: export includes ingredients and steps, and leaves out a '
      'trashed recipe (ORG-7, test-coverage gap)', (tester) async {
    final (recipes, _) = await pumpApp(tester);
    late String trashedId;
    await tester.runAsync(() async {
      final repo = recipes.repository;
      await recipes.save(kabsa(repo));
      final trashed = await recipes.save(kabsa(repo, title: 'في السلة'));
      trashedId = trashed!.id;
      // tester.runAsync: a real (non-fake-timer) DB write, called outside
      // any widget event handler, needs to escape the fake-async zone or
      // it never resolves.
      await recipes.delete(trashedId);
    });
    await settle(tester);

    await openSettings(tester);
    await scrollTo(tester, find.text('تصدير كنص'));
    await tester.tap(find.text('تصدير كنص'));
    await settle(tester);
    await tester.tap(find.text('كل الوصفات'));
    await settle(tester);

    final text = utf8.decode(backupFiles.saved.single.bytes);
    expect(text, contains('المقادير')); // ingredients heading
    expect(text, contains('الطريقة')); // steps heading
    expect(text, contains('يحمر اللحم في الزبدة')); // an actual step line
    expect(text, isNot(contains('في السلة'))); // trashed, never exported
  });

  testWidgets(
    'BAK-7: restoring from the automatic-backups list works from the same '
    'screen (test-coverage gap)',
    (tester) async {
      await pumpApp(tester, withRecipe: true);
      late List<int> bytes;
      await tester.runAsync(() async {
        final fixture = await testBackupFixture();
        await fixture.recipes.save(kabsa(fixture.recipes, title: 'سطحية'));
        bytes = await fixture.backup.createBackup();
        await fixture.dispose();
      });
      backupFiles.nextOpen = bytes;
      await openSettings(tester);
      await scrollTo(tester, find.text('استعادة'));
      await tester.tap(find.text('استعادة'));
      await settle(tester);
      await tester.tap(find.text('دمج'));
      await waitFor(tester, find.text('اكتملت الاستعادة'));
      await tester.tap(find.text('تم'));
      await settle(tester);

      // That restore made an automatic backup of what was here just before
      // it (BAK-2): the original 'كبسة لحم' alone. Restoring from it goes
      // through the same preview-and-confirm flow as a picked file
      // (_handleRestore); Replace, so the result is unambiguous even
      // though the fixture's recipe happens to share an id with the
      // app's own (both start a fresh CountingIds at 'id-1').
      await scrollTo(tester, find.text('النسخ التلقائية'));
      await tester.tap(find.widgetWithText(TextButton, 'استعادة'));
      await settle(tester);
      await tester.tap(find.text('استبدال')); // the counts sheet's choice
      await settle(tester);
      await tester.tap(find.text('استبدال')); // dialog 1
      await settle(tester);
      await tester.tap(find.text('استبدال')); // dialog 2 (destructive)
      await waitFor(tester, find.text('اكتملت الاستعادة'));
      expect(find.text('اكتملت الاستعادة'), findsOneWidget);
      await tester.tap(find.text('تم'));
      await settle(tester);

      await tester.binding.handlePopRoute();
      await settle(tester);
      expect(shown('كبسة لحم'), findsOneWidget); // back to the pre-merge state
      expect(shown('سطحية'), findsNothing);
    },
  );

  testWidgets('BAK-4: a newer-schema file says so and changes nothing '
      '(test-coverage gap)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    backupFiles.nextOpen = _zipOf({
      'app': 'wasfati',
      'appVersion': '9.9.9',
      'schemaVersion': DBHelper.version + 1,
      'createdAt': DateTime.utc(2026, 1, 1).toIso8601String(),
      'tables': const {},
      'meta': const {'settings': null, 'install_id': null},
    });

    await openSettings(tester);
    await scrollTo(tester, find.text('استعادة'));
    await tester.tap(find.text('استعادة'));
    await settle(tester);

    expect(
      find.text(
        'هذه النسخة الاحتياطية من إصدار أحدث من التطبيق. حدّث التطبيق أولًا.',
      ),
      findsOneWidget,
    );
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(shown('كبسة لحم'), findsOneWidget);
  });

  testWidgets('BAK-7: a structurally damaged file says so and changes nothing '
      '(must-fix, several reviews)', (tester) async {
    await pumpApp(tester, withRecipe: true);
    backupFiles.nextOpen = _zipOf({
      'app': 'wasfati',
      'appVersion': '0.1.0',
      'schemaVersion': DBHelper.version,
      'createdAt': 'not-a-date',
      'tables': const {},
      'meta': const {'settings': null, 'install_id': null},
    });

    await openSettings(tester);
    await scrollTo(tester, find.text('استعادة'));
    await tester.tap(find.text('استعادة'));
    await settle(tester);

    expect(find.text('هذا الملف تالف.'), findsOneWidget);
    await tester.binding.handlePopRoute();
    await settle(tester);
    expect(shown('كبسة لحم'), findsOneWidget);
  });
}
