import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:fl_chart/fl_chart.dart'; // ✅ Added fl_chart import

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

  List<DailyReport> _savedReports = [];
  List<DailyReport> _displayLogs = [];

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
    setState(() {
      _isLoading = true;
    });

    await _loadLiveStats();
    await _loadReports();
    _buildDisplayLogs();

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
    int dailySessions = savedTimerDate == todayDate
        ? (prefs.getInt(dailyCompletedSessionsKey) ?? 0)
        : 0;
    int dailyStudySeconds = savedTimerDate == todayDate
        ? (prefs.getInt(dailyStudySecondsKey) ?? 0)
        : 0;

    final savedReport = await DailyReportService.getReportByDate(todayDate);

    final bool liveLooksEmpty =
        completed == 0 &&
        skipped == 0 &&
        pending == 0 &&
        dailySessions == 0 &&
        dailyStudySeconds == 0;

    if (savedReport != null && liveLooksEmpty) {
      completed = savedReport.completedTasks;
      skipped = savedReport.skippedTasks;
      pending = savedReport.pendingTasks;
      dailySessions = savedReport.focusSessions;
      dailyStudySeconds = savedReport.studyMinutes * 60;
    }

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
      _savedReports = data;
    });
  }

  void _buildDisplayLogs() {
    final List<DailyReport> logs = List<DailyReport>.from(_savedReports);

    final int todayIndex = logs.indexWhere((e) => e.date == todayDate);

    if (todayIndex != -1) {
      final existing = logs[todayIndex];

      logs[todayIndex] = existing.copyWith(
        completedTasks: completedTasks,
        skippedTasks: skippedTasks,
        pendingTasks: pendingTasks,
        focusSessions: focusSessions,
        studyMinutes: studyMinutes,
      );
    } else {
      logs.insert(
        0,
        DailyReport(
          date: todayDate,
          completedTasks: completedTasks,
          skippedTasks: skippedTasks,
          pendingTasks: pendingTasks,
          focusSessions: focusSessions,
          studyMinutes: studyMinutes,
          rating: 0,
          note: '',
        ),
      );
    }

    logs.sort((a, b) => b.date.compareTo(a.date));
    _displayLogs = logs;
  }

  Future<void> _refresh() async {
    await _loadEverything();
  }

  // ✅ Automatically calculate last 7 days study minutes from display logs
  List<double> get _weeklyChartData {
    List<double> data = List.filled(7, 0.0);
    for (int i = 0; i < 7 && i < _displayLogs.length; i++) {
      // Index 0 of _displayLogs is today, goes at index 6 (far right) of chart
      data[6 - i] = _displayLogs[i].studyMinutes.toDouble();
    }
    return data;
  }

  @override
  Widget build(BuildContext context) {
    final todayTasksDone = completedTasks + skippedTasks;
    final totalTodayTasks = completedTasks + skippedTasks + pendingTasks;
    final savedReportsCount = _savedReports.length;

    // Calculate progress for the animated ring
    final double todayProgress =
        totalTodayTasks == 0 ? 0.0 : todayTasksDone / totalTodayTasks;

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
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => Navigator.pop(context),
                            icon: const Icon(
                              Icons.arrow_back_ios_new_rounded,
                              color: Colors.white,
                            ),
                          ),
                          const Expanded(
                            child: Text(
                              'Stats & Progress',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),
                      
                      // 🔵 Premium Animated Ring
                      Center(
                        child: AnimatedProgressRing(progress: todayProgress),
                      ),
                      const SizedBox(height: 10),
                      const Center(
                        child: Text(
                          "Today's Task Completion",
                          style: TextStyle(
                            color: Colors.white70,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(height: 30),

                      // 📊 Premium Weekly Bar Chart
                      _buildWeeklyChartCard(_weeklyChartData),
                      const SizedBox(height: 20),

                      // 📝 Overview Card
                      _buildTodayOverviewCard(
                        todayTasksDone: todayTasksDone,
                        totalTodayTasks: totalTodayTasks,
                        savedReportsCount: savedReportsCount,
                      ),
                      const SizedBox(height: 20),

                      // 📋 Daily Logs
                      _buildDailyLogsCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  // ✅ Premium Glow Chart Card
  Widget _buildWeeklyChartCard(List<double> data) {
    return Container(
      padding: const EdgeInsets.all(20),
      height: 240,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF4D88F8).withOpacity(0.2), // Premium glow
            blurRadius: 20,
            spreadRadius: 2,
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
            'Weekly Study Time (Min)',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: BarChart(
              BarChartData(
                borderData: FlBorderData(show: false),
                gridData: const FlGridData(show: false),
                titlesData: const FlTitlesData(show: false), // Clean look
                barGroups: List.generate(data.length, (i) {
                  return BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i],
                        width: 14,
                        borderRadius: BorderRadius.circular(6),
                        gradient: const LinearGradient(
                          colors: [Color(0xFF4D88F8), Color(0xFF1FD38A)],
                        ),
                      ),
                    ],
                  );
                }),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayOverviewCard({
    required int todayTasksDone,
    required int totalTodayTasks,
    required int savedReportsCount,
  }) {
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

  Widget _buildDailyLogsCard() {
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
          if (_displayLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                color: Colors.white.withOpacity(0.05),
              ),
              child: const Text(
                'No daily logs yet.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            )
          else
            Column(
              children: _displayLogs.map((report) {
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
    final tasksDone = report.completedTasks + report.skippedTasks;
    final totalTasks =
        report.completedTasks + report.skippedTasks + report.pendingTasks;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.06),
        border: Border.all(
          color: report.date == todayDate
              ? Colors.white.withOpacity(0.10)
              : Colors.transparent,
          width: 1,
        ),
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
            'Tasks Done: $tasksDone/$totalTasks',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Focus Sessions: ${report.focusSessions}',
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
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

// ✅ NEW: Premium Animated Circular Progress Widget
class AnimatedProgressRing extends StatelessWidget {
  final double progress;
  const AnimatedProgressRing({super.key, required this.progress});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(seconds: 1, milliseconds: 200), // Smooth duration
      curve: Curves.easeInOutCubic, // Smooth curve
      builder: (context, value, _) {
        return Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF4D88F8).withOpacity(0.3), // Inner premium glow
                blurRadius: 30,
                spreadRadius: -10,
              )
            ],
          ),
          child: SizedBox(
            height: 180,
            width: 180,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  height: 180,
                  width: 180,
                  child: CircularProgressIndicator(
                    value: value,
                    strokeWidth: 12,
                    backgroundColor: Colors.white.withOpacity(0.08),
                    valueColor: const AlwaysStoppedAnimation(Color(0xFF4D88F8)),
                    strokeCap: StrokeCap.round, // Rounded ends
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(value * 100).toInt()}%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const Text(
                      'Completed',
                      style: TextStyle(
                        color: Colors.white54,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
