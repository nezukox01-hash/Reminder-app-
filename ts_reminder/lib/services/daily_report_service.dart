import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_report_model.dart';

class DailyReportService {
  DailyReportService._();

  static const String storageKey = 'ts_daily_reports_v1';

  static Future<List<DailyReport>> getReports() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(storageKey) ?? [];

    final reports = data
        .map(DailyReport.fromStorage)
        .where((e) => e.date.isNotEmpty)
        .toList();

    reports.sort((a, b) => b.date.compareTo(a.date));
    return reports;
  }

  static Future<DailyReport?> getReportByDate(String date) async {
    final reports = await getReports();

    try {
      return reports.firstWhere((e) => e.date == date);
    } catch (_) {
      return null;
    }
  }

  static Future<void> saveReport(DailyReport report) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(storageKey) ?? [];

    final reports = data
        .map(DailyReport.fromStorage)
        .where((e) => e.date.isNotEmpty)
        .toList();

    final index = reports.indexWhere((e) => e.date == report.date);

    if (index != -1) {
      reports[index] = report;
    } else {
      reports.add(report);
    }

    reports.sort((a, b) => b.date.compareTo(a.date));

    await prefs.setStringList(
      storageKey,
      reports.map((e) => e.toStorage()).toList(),
    );
  }

  static Future<bool> hasReportForDate(String date) async {
    final report = await getReportByDate(date);
    return report != null;
  }

  static Future<void> deleteReportByDate(String date) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(storageKey) ?? [];

    final reports = data
        .map(DailyReport.fromStorage)
        .where((e) => e.date.isNotEmpty && e.date != date)
        .toList();

    await prefs.setStringList(
      storageKey,
      reports.map((e) => e.toStorage()).toList(),
    );
  }

  static Future<void> clearAllReports() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(storageKey);
  }
}
