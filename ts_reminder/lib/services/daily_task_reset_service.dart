import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_report_model.dart';
import 'daily_report_service.dart';

class DailyTaskResetService {
  DailyTaskResetService._();

  static const String tasksStorageKey = 'ts_tasks_v5';

  static const String lastProcessedDateKey = 'daily_reset_last_processed_date';
  static const String logicalTaskDateKey = 'daily_reset_logical_task_date';

  static const String dailyTimerDateKey = 'daily_timer_date';
  static const String dailyCompletedSessionsKey =
      'daily_completed_focus_sessions';
  static const String dailyStudySecondsKey = 'daily_study_seconds';

  static String _dateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String todayDate() => _dateString(DateTime.now());

  static String tomorrowDate() =>
      _dateString(DateTime.now().add(const Duration(days: 1)));

  static Future<String> getLogicalTaskDate() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(logicalTaskDateKey) ?? todayDate();
  }

  static Future<void> setLogicalTaskDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(logicalTaskDateKey, date);
  }

  static Future<int> getActiveTaskCount() async {
    final prefs = await SharedPreferences.getInstance();
    final tasks = prefs.getStringList(tasksStorageKey) ?? [];
    return _countPending(tasks);
  }

  static Future<bool> hasNoActiveTasks() async {
    final count = await getActiveTaskCount();
    return count == 0;
  }

  static Future<void> clearAllTasks() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(tasksStorageKey, []);
  }

  static int _countCompleted(List<String> rawTasks) {
    int count = 0;
    for (final item in rawTasks) {
      final parts = item.split('||');
      final isDone = parts.length > 3 && parts[3] == 'true';
      if (isDone) count++;
    }
    return count;
  }

  static int _countSkipped(List<String> rawTasks) {
    int count = 0;
    for (final item in rawTasks) {
      final parts = item.split('||');
      final isSkipped = parts.length > 4 && parts[4] == 'true';
      if (isSkipped) count++;
    }
    return count;
  }

  static int _countPending(List<String> rawTasks) {
    int count = 0;
    for (final item in rawTasks) {
      final parts = item.split('||');
      final isDone = parts.length > 3 && parts[3] == 'true';
      final isSkipped = parts.length > 4 && parts[4] == 'true';
      if (!isDone && !isSkipped) count++;
    }
    return count;
  }

  static Future<({int focusSessions, int studyMinutes})> _readDailyTimerStatsForDate(
    String date,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    final savedTimerDate = prefs.getString(dailyTimerDateKey) ?? '';
    if (savedTimerDate != date) {
      return (focusSessions: 0, studyMinutes: 0);
    }

    final sessions = prefs.getInt(dailyCompletedSessionsKey) ?? 0;
    final studySeconds = prefs.getInt(dailyStudySecondsKey) ?? 0;

    return (
      focusSessions: sessions,
      studyMinutes: studySeconds ~/ 60,
    );
  }

  static Future<void> _resetDailyTimerStatsToToday() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(dailyTimerDateKey, todayDate());
    await prefs.setInt(dailyCompletedSessionsKey, 0);
    await prefs.setInt(dailyStudySecondsKey, 0);
  }

  static Future<void> _upsertReportForDate({
    required String date,
    required int completedTasks,
    required int skippedTasks,
    required int pendingTasks,
    required int focusSessions,
    required int studyMinutes,
  }) async {
    final existing = await DailyReportService.getReportByDate(date);

    final report = DailyReport(
      date: date,
      completedTasks: completedTasks,
      skippedTasks: skippedTasks,
      pendingTasks: pendingTasks,
      focusSessions: focusSessions,
      studyMinutes: studyMinutes,
      rating: existing?.rating ?? 0,
      note: existing?.note ?? '',
    );

    await DailyReportService.saveReport(report);
  }

  /// App open / resume er shomoy call korben.
  /// Date change hole previous day finalize kore old tasks clear korbe.
  static Future<void> handleDayRollover() async {
    final prefs = await SharedPreferences.getInstance();

    final today = todayDate();
    final lastProcessed = prefs.getString(lastProcessedDateKey);

    if (lastProcessed == null) {
      await prefs.setString(lastProcessedDateKey, today);
      await prefs.setString(logicalTaskDateKey, today);
      return;
    }

    if (lastProcessed == today) return;

    final rawTasks = prefs.getStringList(tasksStorageKey) ?? [];

    final completed = _countCompleted(rawTasks);
    final skipped = _countSkipped(rawTasks);
    final pending = _countPending(rawTasks);

    final timerStats = await _readDailyTimerStatsForDate(lastProcessed);

    await _upsertReportForDate(
      date: lastProcessed,
      completedTasks: completed,
      skippedTasks: skipped,
      pendingTasks: pending,
      focusSessions: timerStats.focusSessions,
      studyMinutes: timerStats.studyMinutes,
    );

    await clearAllTasks();
    await _resetDailyTimerStatsToToday();

    await prefs.setString(lastProcessedDateKey, today);
    await prefs.setString(logicalTaskDateKey, today);
  }

  /// Last task complete/skip er por popup e YES dile eta call korben.
  /// Ajker stats save hobe, current tasks clear hobe.
  /// Tarpor new task add hole logically next-day bucket e dhorbe.
  static Future<void> finalizeTodayAndClearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final today = todayDate();

    final rawTasks = prefs.getStringList(tasksStorageKey) ?? [];

    final completed = _countCompleted(rawTasks);
    final skipped = _countSkipped(rawTasks);
    final pending = _countPending(rawTasks);

    final timerStats = await _readDailyTimerStatsForDate(today);

    await _upsertReportForDate(
      date: today,
      completedTasks: completed,
      skippedTasks: skipped,
      pendingTasks: pending,
      focusSessions: timerStats.focusSessions,
      studyMinutes: timerStats.studyMinutes,
    );

    await clearAllTasks();

    await prefs.setString(lastProcessedDateKey, today);

    // Important:
    // Popup YES er por new task add hole apnar intended rule onujayi
    // seta next-day task hishebe dhora hobe.
    await prefs.setString(logicalTaskDateKey, tomorrowDate());
  }
}
