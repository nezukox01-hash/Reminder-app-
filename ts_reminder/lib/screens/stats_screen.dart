import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_report_model.dart';
import '../services/daily_report_service.dart';
import '../utils/colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  static const String tasksStorageKey = 'ts_tasks_v5';
  static const String dailyTimerDateKey = 'daily_timer_date';
  static const String dailyCompletedSessionsKey =
      'daily_completed_focus_sessions';
  static const String dailyStudySecondsKey = 'daily_study_seconds';

  List<DailyReport> reports = [];

  int completedTasks = 0;
  int skippedTasks = 0;
  int pendingTasks = 0;
  int focusSessions = 0;
  int studyMinutes = 0;

  bool _isLoading = true;

  String get todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadEverything();
  }

  Future<void> _loadEverything() async {
    await Future.wait([
      _loadLiveStats(),
      _loadReports(),
    ]);

    if (!mounted) return;

    setState(() {
      _isLoading = false;
    });
  }

  Future<void> _loadLiveStats() async {
    final prefs = await SharedPreferences.getInstance();

    final taskData = prefs.getStringList(tasksStorageKey) ?? [];

    int completed = 0;
    int skipped = 0;
    int pending = 0;

    for (final item in taskData) {
      final parts = item.split('||');

      final isDone = parts.length > 3 && parts[3] == 'true';
      final isSkipped = parts.length > 4 && parts[4] == 'true';

      if (isDone) {
        completed++;
      } else if (isSkipped) {
        skipped++;
      } else {
        pending++;
      }
    }

    final savedTimerDate = prefs.getString(dailyTimerDateKey) ?? '';
    final int dailySessions = savedTimerDate == todayDate
        ? (prefs.getInt(dailyCompletedSessionsKey) ?? 0)
        : 0;
    final int dailyStudySeconds = savedTimerDate == todayDate
        ? (prefs.getInt(dailyStudySecondsKey) ?? 0)
        : 0;

    if (!mounted) return;

    setState(() {
      completedTasks = completed;
      skippedTasks = skipped;
      pendingTasks = pending;
      focusSessions = dailySessions;
      studyMinutes = dailyStudySeconds ~/ 60;
    });
  }

  Future<void> _loadReports() async {
    final data = await DailyReportService.getReports();

    if (!mounted) return;

    setState(() {
      reports = data;
    });
  }

  Future<void> _refresh() async {
    setState(() {
      _isLoading = true;
    });

    await _loadEverything();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: Colors.white),
                )
              : RefreshIndicator(
                  onRefresh: _refresh,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                    children: [
                      const Text(
                        'Stats',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _buildTodayOverviewCard(),
                      const SizedBox(height: 20),
                      _buildSavedLogsCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard() {
    final todayTasksDone = completedTasks + skippedTasks;
    final totalTodayTasks = completedTasks + skippedTasks + pendingTasks;
    final savedReportsCount = reports.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Overview',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          _overviewRow(
            Icons.swap_horiz_rounded,
            'Focus Sessions',
            '$focusSessions',
          ),
          const SizedBox(height: 16),
          _overviewRow(
            Icons.timer_outlined,
            'Total Study Time',
            '${studyMinutes}m',
          ),
          const SizedBox(height: 16),
          _overviewRow(
            Icons.check_circle_rounded,
            'Today Tasks Done',
            '$todayTasksDone/$totalTodayTasks',
          ),
          const SizedBox(height: 16),
          _overviewRow(
            Icons.history_rounded,
            'Saved Reports',
            '$savedReportsCount',
          ),
        ],
      ),
    );
  }

  Widget _overviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF42B7FF), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }

  Widget _buildSavedLogsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
        border: Border.all(
          color: Colors.white.withOpacity(0.08),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Daily Logs',
            style: TextStyle(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 18),
          if (reports.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Text(
                'No saved daily reports yet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            )
          else
            Column(
              children: reports.map((report) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _dailyLogItem(report),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _dailyLogItem(DailyReport report) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            _formatDatePretty(report.date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Study Time: ${report.studyMinutes}m',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Tasks Done: ${report.completedTasks}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Text(
                'Rating: ',
                style: TextStyle(
                  color: Color(0xFFFFB84D),
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
              ...List.generate(5, (index) {
                return Icon(
                  Icons.star_rounded,
                  size: 18,
                  color: index < report.rating
                      ? const Color(0xFFFFB84D)
                      : Colors.white24,
                );
              }),
            ],
          ),
          if (report.note.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              report.note,
              style: const TextStyle(
                color: Colors.white70,
                fontSize: 15,
                height: 1.4,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDatePretty(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;

    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;

    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    final monthName =
        (month >= 1 && month <= 12) ? months[month - 1] : parts[1];

    return '$monthName $day, $year';
  }
}
