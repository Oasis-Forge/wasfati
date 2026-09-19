import 'dart:async';

import 'package:flutter/foundation.dart';

import '../services/cook_services.dart';
import '../services/ids.dart';

/// A running cook-mode timer (COOK-4), labelled with its recipe and step.
class CookTimer {
  const CookTimer({
    required this.id,
    required this.recipeId,
    required this.recipeTitle,
    required this.step,
    required this.total,
    required this.endsAt,
  });

  final int id;
  final String recipeId;
  final String recipeTitle;

  /// 1-based step number.
  final int step;
  final Duration total;
  final DateTime endsAt;

  Duration remaining(DateTime now) => endsAt.difference(now);
}

/// Timers outlive cook mode (COOK-4): they live here, at the app level.
/// Several can run at once. When one ends it rings in the app; in the
/// background its scheduled notification does (COOK-5).
class TimersState extends ChangeNotifier {
  TimersState(
    this._alerts, {
    Clock? clock,
    bool Function()? inForeground,
    this.autoTick = true,
  }) : _clock = clock ?? systemClock,
       _inForeground = inForeground ?? (() => true);

  final TimerAlerts _alerts;
  final Clock _clock;
  final bool Function() _inForeground;

  /// False in tests, which call [tick] themselves.
  final bool autoTick;

  final _running = <CookTimer>[];
  final _finished = <CookTimer>[];
  Timer? _ticker;
  int _nextId = 1;
  bool? _alertsAllowed;
  bool _toldAlertsOff = false;

  List<CookTimer> get running => List.unmodifiable(_running);

  /// Timers that ended while the app was open, until dismissed.
  List<CookTimer> get finished => List.unmodifiable(_finished);

  DateTime now() => _clock();

  /// True once, after notification permission was refused (COOK-5).
  bool get shouldSayAlertsOff => _alertsAllowed == false && !_toldAlertsOff;

  void saidAlertsOff() => _toldAlertsOff = true;

  /// Starts a timer; asks for notification permission the first time
  /// (RUN-3), and works either way.
  Future<CookTimer> start({
    required String recipeId,
    required String recipeTitle,
    required int step,
    required Duration duration,
    required String notificationTitle,
    required String notificationBody,
    required String channelName,
  }) async {
    _alertsAllowed ??= await _alerts.ensurePermission();
    final t = CookTimer(
      id: _nextId++,
      recipeId: recipeId,
      recipeTitle: recipeTitle,
      step: step,
      total: duration,
      endsAt: _clock().add(duration),
    );
    _running.add(t);
    if (_alertsAllowed!) {
      try {
        await _alerts.schedule(
          t.id,
          t.endsAt,
          notificationTitle,
          notificationBody,
          channelName,
        );
      } catch (_) {
        // The timer still rings in the app; only the background alert is
        // lost, and the user is told once (COOK-5).
        _alertsAllowed = false;
      }
    }
    _ensureTicker();
    notifyListeners();
    return t;
  }

  Future<void> cancel(CookTimer t) async {
    _running.removeWhere((r) => r.id == t.id);
    await _alerts.cancel(t.id);
    notifyListeners();
  }

  void dismissFinished() {
    _finished.clear();
    notifyListeners();
  }

  /// Moves ended timers to [finished]. In the app it rings and cancels the
  /// notification; in the background the notification does the alerting.
  Future<void> tick() async {
    final now = _clock();
    final ended = _running.where((t) => !t.endsAt.isAfter(now)).toList();
    if (ended.isNotEmpty) {
      _running.removeWhere(ended.contains);
      if (_inForeground()) {
        _finished.addAll(ended);
        await _alerts.ringNow();
        for (final t in ended) {
          await _alerts.cancel(t.id);
        }
      }
    }
    if (_running.isEmpty) {
      _ticker?.cancel();
      _ticker = null;
    }
    notifyListeners();
  }

  void _ensureTicker() {
    if (!autoTick || _ticker != null) return;
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) => tick());
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
