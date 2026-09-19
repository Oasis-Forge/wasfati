import 'package:flutter_test/flutter_test.dart';
import 'package:wasfati/providers/timers_state.dart';
import 'package:wasfati/services/cook_services.dart';

import '../helpers.dart';

void main() {
  late FakeClock clock;
  late NoopTimerAlerts alerts;
  var foreground = true;

  TimersState make() => TimersState(
    alerts,
    clock: clock.call,
    inForeground: () => foreground,
    autoTick: false,
  );

  Future<CookTimer> start(TimersState t, int minutes, {int step = 1}) =>
      t.start(
        recipeId: 'r',
        recipeTitle: 'كبسة',
        step: step,
        duration: Duration(minutes: minutes),
        notificationTitle: 'كبسة',
        notificationBody: 'انتهى المؤقت',
        channelName: 'مؤقتات الطبخ',
      );

  setUp(() {
    clock = FakeClock();
    alerts = NoopTimerAlerts();
    foreground = true;
  });

  test(
    'asks once, schedules a notification, runs several (COOK-4, 5)',
    () async {
      final t = make();
      await start(t, 15);
      await start(t, 5, step: 2);
      expect(alerts.asked, 1);
      expect(alerts.scheduled.length, 2);
      expect(t.running.length, 2);
      clock.advance(const Duration(minutes: 4));
      expect(t.running.last.remaining(clock()), const Duration(minutes: 1));
    },
  );

  test('ending in the app rings and cancels the notification', () async {
    final t = make();
    await start(t, 5);
    clock.advance(const Duration(minutes: 5));
    await t.tick();
    expect(t.running, isEmpty);
    expect(t.finished.single.step, 1);
    expect(alerts.rings, 1);
    expect(alerts.scheduled, isEmpty);
    t.dismissFinished();
    expect(t.finished, isEmpty);
  });

  test('ending in the background leaves it to the notification', () async {
    final t = make();
    await start(t, 5);
    foreground = false;
    clock.advance(const Duration(minutes: 6));
    await t.tick();
    expect(t.running, isEmpty);
    expect(alerts.rings, 0);
    expect(alerts.scheduled.length, 1); // still due to show
  });

  test('refused notifications: the timer works, and says so once', () async {
    alerts.allowed = false;
    final t = make();
    await start(t, 5);
    expect(alerts.scheduled, isEmpty);
    expect(t.running.length, 1);
    expect(t.shouldSayAlertsOff, isTrue);
    t.saidAlertsOff();
    expect(t.shouldSayAlertsOff, isFalse);
  });

  test('cancel stops the timer and its notification', () async {
    final t = make();
    final timer = await start(t, 5);
    await t.cancel(timer);
    expect(t.running, isEmpty);
    expect(alerts.scheduled, isEmpty);
  });

  test(
    'a scheduling failure keeps the timer and says alerts are off',
    () async {
      final t = TimersState(
        _FailingAlerts(),
        clock: clock.call,
        autoTick: false,
      );
      await start(t, 5);
      expect(t.running.length, 1);
      expect(t.shouldSayAlertsOff, isTrue);
    },
  );
}

class _FailingAlerts extends NoopTimerAlerts {
  @override
  Future<void> schedule(
    int id,
    DateTime at,
    String title,
    String body,
    String channelName,
  ) => Future.error(StateError('no receiver'));
}
