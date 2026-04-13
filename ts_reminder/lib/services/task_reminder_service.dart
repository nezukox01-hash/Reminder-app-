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
      // Fallback
    }

    // 👈 FIX 1: Removed '@mipmap/'. Android just wants the file name!
    const android = AndroidInitializationSettings('ic_launcher');
    const settings = InitializationSettings(android: android);

    await _notifications.initialize(settings);

    final androidImplementation = _notifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
        
    if (androidImplementation != null) {
      await androidImplementation.requestNotificationsPermission();
      await androidImplementation.requestExactAlarmsPermission();
    }
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

    // 👈 FIX 2: Shrink the ID to guarantee it fits perfectly into Android's 32-bit limit
    final exactId = (taskId.hashCode.abs() % 100000);
    final preId = exactId + 1;

    await _notifications.cancel(exactId);
    await _notifications.cancel(preId);

    // Schedule the EXACT time notification
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

    // Schedule the 3-MINUTE EARLY notification (Only if there is enough time!)
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
