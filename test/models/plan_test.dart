import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/plan.dart';
import 'package:wasfati/models/quantity/rational.dart';
import 'package:wasfati/models/settings.dart';

PlanEntry _entry({
  String? recipeId = 'r1',
  String? note,
  int? servings,
  Rational? multiplier,
}) {
  final now = DateTime.utc(2026, 9, 20);
  return PlanEntry(
    id: 'p1',
    date: DateTime(2026, 9, 20),
    slot: MealSlot.lunch,
    recipeId: recipeId,
    note: note,
    servings: servings,
    multiplier: multiplier,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('PLAN-2: an entry is a recipe or a note', () {
    test('one of the two, never both and never neither', () {
      expect(_entry().validate(), isNull);
      expect(_entry(recipeId: null, note: 'مطعم').validate(), isNull);
      expect(_entry(note: 'مطعم').validate(), isNotNull);
      expect(_entry(recipeId: null).validate(), isNotNull);
    });

    test('a note is 1–60 characters and carries no amount', () {
      expect(_entry(recipeId: null, note: 'م' * 60).validate(), isNull);
      expect(_entry(recipeId: null, note: 'م' * 61).validate(), isNotNull);
      expect(_entry(recipeId: null, note: '   ').validate(), isNotNull);
      expect(
        _entry(recipeId: null, note: 'مطعم', servings: 4).validate(),
        isNotNull,
      );
    });

    test('servings are 1–100, or one of the multipliers, not both', () {
      expect(_entry(servings: 1).validate(), isNull);
      expect(_entry(servings: 100).validate(), isNull);
      expect(_entry(servings: 0).validate(), isNotNull);
      expect(_entry(servings: 101).validate(), isNotNull);
      expect(_entry(multiplier: Rational.half).validate(), isNull);
      expect(_entry(multiplier: Rational(3)).validate(), isNull);
      expect(_entry(multiplier: Rational(5)).validate(), isNotNull);
      expect(
        _entry(servings: 4, multiplier: Rational.one).validate(),
        isNotNull,
      );
    });

    test('a row comes back as it went in', () {
      final e = _entry(servings: 6);
      final back = PlanEntry.fromMap(e.toMap());
      expect(
        (back.id, back.slot, back.servings, back.recipeId),
        (e.id, MealSlot.lunch, 6, 'r1'),
      );
      expect(dateKey(back.date), '2026-09-20');
      final note = PlanEntry.fromMap(
        _entry(recipeId: null, note: 'مطعم', multiplier: null).toMap(),
      );
      expect((note.isNote, note.note), (true, 'مطعم'));
    });
  });

  group('PLAN-1: which day a week starts on', () {
    int auto(String? region, {bool arabic = true}) =>
        firstWeekday(WeekStart.auto, region: region, arabic: arabic);

    test('a chosen day wins over the region', () {
      expect(
        firstWeekday(WeekStart.monday, region: 'EG', arabic: true),
        DateTime.monday,
      );
      expect(
        firstWeekday(WeekStart.saturday, region: 'US', arabic: false),
        DateTime.saturday,
      );
    });

    test('"by region" follows CLDR: Egypt Saturday, Saudi Sunday, UK '
        'Monday', () {
      expect(auto('EG'), DateTime.saturday);
      expect(auto('kw'), DateTime.saturday); // case doesn't matter
      expect(auto('AE'), DateTime.saturday);
      expect(auto('SA'), DateTime.sunday);
      expect(auto('US', arabic: false), DateTime.sunday);
      expect(auto('GB', arabic: false), DateTime.monday);
      expect(auto('DE', arabic: false), DateTime.monday);
    });

    test('with no region, Saturday in Arabic and Sunday in English', () {
      expect(auto(null), DateTime.saturday);
      expect(auto(null, arabic: false), DateTime.sunday);
    });

    test('a week holds its start day and the 6 days after it', () {
      final wednesday = DateTime(2026, 9, 23);
      expect(dateKey(weekStartFor(wednesday, DateTime.saturday)), '2026-09-19');
      expect(dateKey(weekStartFor(wednesday, DateTime.sunday)), '2026-09-20');
      expect(dateKey(weekStartFor(wednesday, DateTime.monday)), '2026-09-21');
      // A Saturday is already the start of its own Saturday week.
      final saturday = DateTime(2026, 9, 19);
      expect(dateKey(weekStartFor(saturday, DateTime.saturday)), '2026-09-19');
      final days = weekDays(weekStartFor(wednesday, DateTime.saturday));
      expect(days.length, 7);
      expect(dateKey(days.last), '2026-09-25');
      expect(dateKey(days[4]), '2026-09-23'); // the day we asked about
    });

    test('a planned day keeps its date whatever the time on it (DATE-1)', () {
      expect(dateKey(dateOnly(DateTime(2026, 9, 20, 23, 30))), '2026-09-20');
      expect(dateFromKey('2026-09-20'), DateTime(2026, 9, 20));
      expect(dateKey(DateTime(2026, 1, 5)), '2026-01-05'); // padded
    });
  });
}
