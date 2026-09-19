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

  test('clock text', () {
    expect(clockText(const Duration(minutes: 15)), '15:00');
    expect(clockText(const Duration(minutes: 90, seconds: 5)), '1:30:05');
    expect(clockText(const Duration(seconds: -3)), '00:00');
  });
}
