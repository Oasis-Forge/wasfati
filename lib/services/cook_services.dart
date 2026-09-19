import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:wakelock_plus/wakelock_plus.dart';

/// Keeps the screen on while cook mode is open (COOK-3). Uses the window
/// flag, so no wake-lock permission.
abstract interface class ScreenAwake {
  Future<void> keepOn(bool on);
}

class NoopScreenAwake implements ScreenAwake {
  const NoopScreenAwake();
  @override
  Future<void> keepOn(bool on) async {}
}

class DeviceScreenAwake implements ScreenAwake {
  const DeviceScreenAwake();
  @override
  Future<void> keepOn(bool on) => WakelockPlus.toggle(enable: on);
}

/// Timer alerts (COOK-5): a sound and vibration in the app, and a
/// notification scheduled for when the app is in the background.
abstract interface class TimerAlerts {
  /// Asks for notification permission the first time; true if allowed.
  Future<bool> ensurePermission();

  /// [channelName] names the Android notification channel, in the app's
  /// current language.
  Future<void> schedule(
    int id,
    DateTime at,
    String title,
    String body,
    String channelName,
  );
  Future<void> cancel(int id);

  /// Rings and vibrates now, in the app.
  Future<void> ringNow();
}

class NoopTimerAlerts implements TimerAlerts {
  NoopTimerAlerts({this.allowed = true});
  bool allowed;
  final scheduled = <int, DateTime>{};
  int rings = 0;
  int asked = 0;

  @override
  Future<bool> ensurePermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<void> schedule(
    int id,
    DateTime at,
    String title,
    String body,
    String channelName,
  ) async => scheduled[id] = at;

  @override
  Future<void> cancel(int id) async => scheduled.remove(id);

  @override
  Future<void> ringNow() async => rings++;
}

/// The real alerts; built only in `main.dart`.
class DeviceTimerAlerts implements TimerAlerts {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool? _allowed;

  Future<void> init() => _plugin.initialize(
    settings: const InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    ),
  );

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  @override
  Future<bool> ensurePermission() async =>
      _allowed ??= await _android?.requestNotificationsPermission() ?? false;

  @override
  Future<void> schedule(
    int id,
    DateTime at,
    String title,
    String body,
    String channelName,
  ) => _plugin.zonedSchedule(
    id: id,
    scheduledDate: tz.TZDateTime.from(at.toUtc(), tz.UTC),
    title: title,
    body: body,
    notificationDetails: NotificationDetails(
      android: AndroidNotificationDetails(
        'cook_timers',
        channelName,
        importance: Importance.high,
        priority: Priority.high,
      ),
    ),
    // Inexact: no exact-alarm permission (COOK-5).
    androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
  );

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> ringNow() async {
    await SystemSound.play(SystemSoundType.alert);
    await HapticFeedback.vibrate();
  }
}
