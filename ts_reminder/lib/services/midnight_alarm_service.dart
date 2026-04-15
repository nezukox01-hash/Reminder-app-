import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:flutter/widgets.dart';

import 'daily_task_reset_service.dart';

class MidnightAlarmService {
  MidnightAlarmService._();

  static const int _midnightAlarmId = 120001;

  static DateTime _nextMidnight() {
    final now = DateTime.now();
    return DateTime(now.year, now.month, now.day + 1);
  }

  @pragma('vm:entry-point')
  static Future<void> midnightAlarmCallback() async {
    WidgetsFlutterBinding.ensureInitialized();

    await DailyTaskResetService.handleDayRollover();
    await scheduleNextMidnightAlarm();
  }

  static Future<void> scheduleNextMidnightAlarm() async {
    final nextMidnight = _nextMidnight();

    await AndroidAlarmManager.oneShotAt(
      nextMidnight,
      _midnightAlarmId,
      midnightAlarmCallback,
      exact: true,
      wakeup: true,
    );
  }

  static Future<void> reschedule() async {
    await AndroidAlarmManager.cancel(_midnightAlarmId);
    await scheduleNextMidnightAlarm();
  }
}
