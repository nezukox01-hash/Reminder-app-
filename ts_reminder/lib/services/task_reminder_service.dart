import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

class TaskReminderService {
  TaskReminderService._();

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> init() async {
    tz.initializeTimeZones();

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
    final scheduledTime = _nextDateFrom24HourString(reminderTime);
    if (scheduledTime == null) return;

    const androidDetails = AndroidNotificationDetails(
      'task_channel',
      'Task Reminders',
      channelDescription: 'Task reminder notifications',
      importance: Importance.max,
      priority: Priority.high,
    );

    const details = NotificationDetails(android: androidDetails);

    await _notifications.cancel(taskId.hashCode);
    await _notifications.cancel(taskId.hashCode + 1);

    await _notifications.zonedSchedule(
      taskId.hashCode,
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

    if (preTime.isAfter(now)) {
      await _notifications.zonedSchedule(
        taskId.hashCode + 1,
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
    await _notifications.cancel(taskId.hashCode);
    await _notifications.cancel(taskId.hashCode + 1);
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
