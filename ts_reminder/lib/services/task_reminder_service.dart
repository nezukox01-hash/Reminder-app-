import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';

class TaskReminderService {
  TaskReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();
    
    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timeZoneName));
    } catch (e) {
      // 👈 FIX 1: If the phone fails to find the timezone, forcefully use Bangladesh time instead of UTC!
      tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);
  }

  static Future<void> scheduleTaskReminder({
    required String taskId,
    required String title,
    required String body,
    required String reminderTime,
  }) async {
    
    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Reminders',
      channelDescription: 'Task reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
      // 👈 FIX 2: Explicitly attaching the icon to the channel details
      icon: '@mipmap/ic_launcher', 
    );

    const details = NotificationDetails(android: androidDetails);

    // 👈 PROOF OF LIFE: This fires instantly the moment you tap Save to prove notifications work!
    await _notifications.show(
      999999, 
      '✅ Alarm Set!',
      'Your task "$body" is locked in for $reminderTime.',
      details,
    );

    final scheduledTime = _nextDateFrom24HourString(reminderTime);
    if (scheduledTime == null) return;

    final exactId = (taskId.hashCode.abs() % 100000);
    final preId = exactId + 1;

    await _notifications.cancel(exactId);
    await _notifications.cancel(preId);

    // Schedule exact time
    await _notifications.zonedSchedule(
      exactId,
      title,
      body,
      scheduledTime,
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );

    final now = tz.TZDateTime.now(tz.local);
    final preTime = scheduledTime.subtract(const Duration(minutes: 3));

    // Schedule 3 minutes early
    if (preTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        preId,
        'Upcoming Task',
        body,
        preTime,
        details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
      );
    }
  }

  static Future<void> cancelTaskReminder(String taskId) async {
    final exactId = (taskId.hashCode.abs() % 100000);
    final preId = exactId + 1;
    await _notifications.cancel(exactId);
    await _notifications.cancel(preId);
  }

  static tz.TZDateTime? _nextDateFrom24HourString(String value) {
    try {
      final parts = value.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      final now = tz.TZDateTime.now(tz.local);

      var scheduled = tz.TZDateTime(
        tz.local,
        now.year,
        now.month,
        now.day,
        hour,
        minute,
      );

      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }

      return scheduled;
    } catch (_) {
      return null;
    }
  }
}
