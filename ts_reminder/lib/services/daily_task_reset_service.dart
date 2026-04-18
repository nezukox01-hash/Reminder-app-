import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_report_model.dart';
import '../models/task_item.dart'; 
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
    final rawTasks = prefs.getStringList(tasksStorageKey) ?? [];
    final allTasks = _readTasksFromPrefs(rawTasks);
    final todayTasks = _tasksForDate(allTasks, todayDate());
    return _pendingFromTasks(todayTasks);
  }

  static Future<bool> hasNoActiveTasks() async {
    final count = await getActiveTaskCount();
    return count == 0;
  }

  static List<TaskItem> _readTasksFromPrefs(List<String> rawTasks) {
    return rawTasks.map(TaskItem.fromStorage).toList();
  }

  static List<TaskItem> _tasksForDate(List<TaskItem> tasks, String date) {
    return tasks.where((t) {
      final taskDate = t.taskDate.isEmpty ? date : t.taskDate;
      return taskDate == date;
    }).toList();
  }

  static int _completedFromTasks(List<TaskItem> tasks) {
    return tasks.where((t) => t.isDone).length;
  }

  static int _skippedFromTasks(List<TaskItem> tasks) {
    return tasks.where((t) => t.isSkipped).length;
  }

  static int _pendingFromTasks(List<TaskItem> tasks) {
    return tasks.where((t) => !t.isDone && !t.isSkipped).length;
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
    final allTasks = _readTasksFromPrefs(rawTasks);
    
    // ✅ BUG FIXED: আগের দিনের টাস্কগুলোকে একদম নিখুঁতভাবে ফিল্টার করা হয়েছে
    final previousDayTasks = allTasks.where((t) {
        final taskDate = t.taskDate.isEmpty ? lastProcessed : t.taskDate;
        return taskDate == lastProcessed;
    }).toList();
    
    final completed = _completedFromTasks(previousDayTasks);
    final skipped = _skippedFromTasks(previousDayTasks);
    final pending = _pendingFromTasks(previousDayTasks);

    final timerStats = await _readDailyTimerStatsForDate(lastProcessed);

    await _upsertReportForDate(
      date: lastProcessed,
      completedTasks: completed,
      skippedTasks: skipped,
      pendingTasks: pending,
      focusSessions: timerStats.focusSessions,
      studyMinutes: timerStats.studyMinutes,
    );

    // ✅ BUG FIXED: শুধুমাত্র আগের দিনের টাস্কগুলো লিস্ট থেকে ক্লিয়ার হবে, আজকেরগুলো থেকে যাবে
    final remainingTasks = allTasks.where((t) { 
      final taskDate = t.taskDate.isEmpty ? lastProcessed : t.taskDate; 
      return taskDate != lastProcessed; 
    }).toList(); 
    
    await prefs.setStringList(
      tasksStorageKey, 
      remainingTasks.map((e) => e.toStorage()).toList(), 
    );

    await _resetDailyTimerStatsToToday();

    await prefs.setString(lastProcessedDateKey, today);
    await prefs.setString(logicalTaskDateKey, today);
  }

  /// Last task complete/skip er por popup e YES dile eta call korben.
  static Future<void> finalizeTodayAndClearTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final today = todayDate();

    final rawTasks = prefs.getStringList(tasksStorageKey) ?? [];
    final allTasks = _readTasksFromPrefs(rawTasks);
    
    // ✅ BUG FIXED
    final todayTasks = allTasks.where((t) {
        final taskDate = t.taskDate.isEmpty ? today : t.taskDate;
        return taskDate == today;
    }).toList();
    
    final completed = _completedFromTasks(todayTasks);
    final skipped = _skippedFromTasks(todayTasks);
    final pending = _pendingFromTasks(todayTasks);

    final timerStats = await _readDailyTimerStatsForDate(today);

    await _upsertReportForDate(
      date: today,
      completedTasks: completed,
      skippedTasks: skipped,
      pendingTasks: pending,
      focusSessions: timerStats.focusSessions,
      studyMinutes: timerStats.studyMinutes,
    );

    // ✅ BUG FIXED
    final remainingTasks = allTasks.where((t) { 
      final taskDate = t.taskDate.isEmpty ? today : t.taskDate; 
      return taskDate != today; 
    }).toList(); 
    
    await prefs.setStringList(
      tasksStorageKey, 
      remainingTasks.map((e) => e.toStorage()).toList(), 
    );

    await prefs.setString(lastProcessedDateKey, today);
    await prefs.setString(logicalTaskDateKey, tomorrowDate());
  }
}
