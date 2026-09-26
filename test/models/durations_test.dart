import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/models/durations.dart';

List<int> minutes(String text) => [
  for (final d in findDurations(text)) d.inSeconds ~/ 60,
];

void main() {
  group('COOK-4: durations in a step', () {
    test('Arabic minutes and hours, as Fatafeat writes them', () {
      // The kabsa step from the competitor research.
      const step =
          'يضاف البصل ويقلى تقريبا لمدة 5 دقائق ثم تضاف صلصة الطماطم وتقلب '
          'لمدة دقيقتين ثم يترك على النار لمدة ساعة ونصف حتى ينضج اللحم ثم '
          'يترك الأرز لمدة 15 دقيقة';
      expect(minutes(step), [5, 2, 90, 15]);
    });

    test('Eastern digits, half and quarter hours', () {
      expect(minutes('اتركه ٢٠ دقيقة'), [20]);
      expect(minutes('يطهى نص ساعة'), [30]);
      expect(minutes('يترك ربع ساعة'), [15]);
      expect(minutes('يخبز ساعتين ونص'), [150]);
    });

    test('a range uses its upper end', () {
      expect(minutes('bake 10-15 min'), [15]);
      expect(minutes('من 10 الى 15 دقيقة'), [15]);
    });

    test('an hour and minutes make one timer', () {
      expect(minutes('roast for 1 hour 20 minutes'), [80]);
      expect(minutes('يشوى ساعة و20 دقيقة'), [80]);
    });

    test('English', () {
      expect(minutes('Simmer for an hour, then rest 10 mins.'), [60, 10]);
      expect(findDurations('Whisk 30 seconds'), [const Duration(seconds: 30)]);
    });

    test('no false timers', () {
      expect(findDurations('أضف 2 كوب ماء و3 حبات طماطم'), isEmpty);
      expect(findDurations('Preheat the oven to 180'), isEmpty);
      expect(findDurations('الساعة الذهبية'), isEmpty);
    });

    test('the same duration twice gives one timer', () {
      expect(minutes('اقلب 5 دقائق ثم 5 دقائق أخرى'), [5]);
    });
  });

  group('LOOK-13: where each duration sits in the text as written', () {
    List<String> phrases(String text) => [
      for (final s in findDurationSpans(text)) text.substring(s.start, s.end),
    ];

    test('the phrase itself, harakat and Eastern digits kept', () {
      expect(phrases('يترك على النار لمدة ٢٥ دَقِيقَة حتى ينضج.'), [
        '٢٥ دَقِيقَة',
      ]);
      expect(phrases('Roast for 90 minutes, then rest 10 mins.'), [
        '90 minutes',
        '10 mins',
      ]);
    });

    test('joined units are one phrase; a repeat is found twice', () {
      expect(phrases('يطهى ساعة و20 دقيقة'), ['ساعة و20 دقيقة']);
      expect(phrases('اقلب 5 دقائق ثم 5 دقائق أخرى'), ['5 دقائق', '5 دقائق']);
    });

    test('an isolated amount keeps both its isolate marks in the phrase', () {
      final lri = String.fromCharCode(0x2066);
      final pdi = String.fromCharCode(0x2069);
      final text = 'اتركه $lri${'15'}$pdi دقيقة';
      final span = findDurationSpans(text).single;
      expect(span.duration, const Duration(minutes: 15));
      expect(text.substring(span.start, span.end), '${lri}15$pdi دقيقة');
    });
  });

  test('clock text', () {
    expect(clockText(const Duration(minutes: 15)), '15:00');
    expect(clockText(const Duration(minutes: 90, seconds: 5)), '1:30:05');
    expect(clockText(const Duration(seconds: -3)), '00:00');
  });
}
