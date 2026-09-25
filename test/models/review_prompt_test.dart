import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/library.dart';
import 'package:wasfati/models/recipe.dart';
import 'package:wasfati/models/review_prompt.dart';

/// RUN-5: the rule competitors break, so every combination is checked.
void main() {
  final now = DateTime.utc(2026, 9, 25, 12);

  group('reviewPromptDue: every condition must hold', () {
    // All 8 combinations of the three yes/no conditions, never asked before:
    // only the one with all three is due.
    for (final firstRun in [false, true]) {
      for (final imported in [false, true]) {
        for (final cooked in [false, true]) {
          final expected = firstRun && imported && cooked;
          test(
            'first run over: $firstRun, saved an import: $imported, '
            'marked cooked: $cooked → ${expected ? 'ask' : 'don\'t ask'}',
            () {
              expect(
                reviewPromptDue(
                  firstRunComplete: firstRun,
                  savedImport: imported,
                  markedCooked: cooked,
                  lastAskedAt: null,
                  now: now,
                ),
                expected,
              );
            },
          );
        }
      }
    }
  });

  group('reviewPromptDue: at most once every 120 days', () {
    bool dueAfter(Duration since) => reviewPromptDue(
      firstRunComplete: true,
      savedImport: true,
      markedCooked: true,
      lastAskedAt: now.subtract(since),
      now: now,
    );

    test('never asked: due', () {
      expect(
        reviewPromptDue(
          firstRunComplete: true,
          savedImport: true,
          markedCooked: true,
          lastAskedAt: null,
          now: now,
        ),
        isTrue,
      );
    });

    test('asked moments ago, or any time within 120 days: not due', () {
      expect(dueAfter(Duration.zero), isFalse);
      expect(dueAfter(const Duration(minutes: 1)), isFalse);
      expect(dueAfter(const Duration(days: 30)), isFalse);
      expect(
        dueAfter(const Duration(days: 119, hours: 23, minutes: 59)),
        isFalse,
      );
    });

    test('exactly 120 days, or longer: due again', () {
      expect(dueAfter(const Duration(days: 120)), isTrue);
      expect(dueAfter(const Duration(days: 121)), isTrue);
      expect(dueAfter(const Duration(days: 400)), isTrue);
    });

    test('a last time in the future (the clock was moved back) is recent, '
        'never a reason to ask sooner', () {
      expect(dueAfter(const Duration(days: -1)), isFalse);
      expect(dueAfter(const Duration(days: -200)), isFalse);
    });

    test('120 days since never overrides a missing condition', () {
      for (final (firstRun, imported, cooked) in [
        (false, true, true),
        (true, false, true),
        (true, true, false),
      ]) {
        expect(
          reviewPromptDue(
            firstRunComplete: firstRun,
            savedImport: imported,
            markedCooked: cooked,
            lastAskedAt: now.subtract(const Duration(days: 365)),
            now: now,
          ),
          isFalse,
        );
      }
    });
  });

  // What counts as a saved import is `AppSettings.importSaved`, set by the
  // import preview's Save (test/widget/app_test.dart and
  // test/providers/review_prompt_state_test.dart); a recipe's source tag
  // doesn't decide it.
  group('what counts as a cooked recipe', () {
    LibraryEntry entry(SourceType source, {int cooked = 0}) => LibraryEntry(
      id: '${source.name}-$cooked',
      title: 'x',
      sourceType: source,
      cookedCount: cooked,
      createdAt: now,
    );

    test('an empty library has none', () {
      expect(hasMarkedCooked(const []), isFalse);
    });

    test('cooked once is enough; never cooked is not', () {
      expect(hasMarkedCooked([entry(SourceType.written)]), isFalse);
      expect(
        hasMarkedCooked([
          entry(SourceType.website),
          entry(SourceType.written, cooked: 1),
        ]),
        isTrue,
      );
    });
  });
}
