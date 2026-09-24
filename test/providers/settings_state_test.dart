import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/settings_state.dart';

import '../helpers.dart';

// Every clock value below is a plain (non-UTC) DateTime, so `.toLocal()`
// inside SettingsState is a no-op wherever this test runs — it stands in
// directly for "local wall-clock time" (same trick as backup_test.dart's
// backupFileName tests), keeping the calendar-month math deterministic in
// any timezone.

void main() {
  group('SettingsState: the AI import quota (IMP-7, Decision 4)', () {
    test('starts with the full free quota, resetting at next month\'s '
        'local midnight', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 24, 8);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();

      expect(state.aiImportsUsed, 0);
      expect(state.aiImportsLeft(), 10);
      expect(state.aiImportsResetAt, DateTime(2026, 10, 1));
    });

    test('a save records one used; fetching a result never spends it — a '
        'cancelled or failed preview costs nothing (IMP-4, IMP-7)', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 24, 8);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();

      // Nothing about receiving an AI result touches the quota — only
      // the save path (recordAiImportSaved) does, and nothing here calls
      // it yet, standing in for a preview the user closed without saving.
      expect(state.aiImportsLeft(), 10);
      expect(state.aiImportsLeft(), 10); // looking again still costs nothing

      await state.recordAiImportSaved();
      expect(state.aiImportsUsed, 1);
      expect(state.aiImportsLeft(), 9);
    });

    test('using all 10 leaves 0, never negative', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 1);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();
      for (var i = 0; i < 12; i++) {
        await state.recordAiImportSaved();
      }
      expect(state.aiImportsUsed, 12);
      expect(state.aiImportsLeft(), 0);
    });

    test('the month rolls over at local midnight on the 1st, with no save '
        'needed to see it reset', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 30, 23, 59);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();
      for (var i = 0; i < 10; i++) {
        await state.recordAiImportSaved();
      }
      expect(state.aiImportsLeft(), 0); // September fully used

      clock.now = DateTime(2026, 10, 1); // one minute later: local midnight
      expect(state.aiImportsUsed, 0); // read live, no write needed
      expect(state.aiImportsLeft(), 10);

      // ...and it stays reset all through October, not just at the instant.
      clock.now = DateTime(2026, 10, 15);
      expect(state.aiImportsLeft(), 10);
    });

    test('a save exactly at the boundary starts the new month\'s count at '
        '1, not the old month\'s 11th', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 30, 20);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();
      for (var i = 0; i < 9; i++) {
        await state.recordAiImportSaved();
      }
      expect(state.aiImportsLeft(), 1); // September: 1 left

      clock.now = DateTime(2026, 10, 1); // local midnight: the boundary
      await state.recordAiImportSaved();

      expect(state.aiImportsUsed, 1); // fresh month, not September's 10th
      expect(state.aiImportsLeft(), 9);
    });

    test('a stale month is never written just by reading — only '
        'recordAiImportSaved writes', () async {
      final db = await memoryDb();
      final clock = FakeClock()..now = DateTime(2026, 8, 15);
      final writer = SettingsState(db, clock: clock.call);
      await writer.load();
      await writer.recordAiImportSaved();
      expect(writer.aiImportsUsed, 1);

      clock.now = DateTime(2026, 9, 24);
      final reader = SettingsState(db, clock: clock.call);
      await reader.load();
      expect(reader.aiImportsUsed, 0); // August's 1 doesn't leak into Sept
      expect(reader.aiImportsLeft(), 10);
    });

    test('Premium\'s higher cap (PAY-7) can be passed without changing '
        'what is stored', () async {
      final clock = FakeClock()..now = DateTime(2026, 9, 1);
      final state = SettingsState(await memoryDb(), clock: clock.call);
      await state.load();
      for (var i = 0; i < 10; i++) {
        await state.recordAiImportSaved();
      }
      expect(state.aiImportsLeft(), 0); // free tier's 10 used up
      expect(state.aiImportsLeft(quota: 100), 90); // same 10 saves, Premium
    });
  });
}
