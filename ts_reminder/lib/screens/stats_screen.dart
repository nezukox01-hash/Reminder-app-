import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
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

  List<DailyReport> _savedReports = [];
  List<DailyReport> _displayLogs = [];

  int completedTasks = 0;
  int skippedTasks = 0;
  int pendingTasks = 0;
  int focusSessions = 0;
  int studyMinutes = 0;

  bool _isLoading = true;

  final Map<String, GlobalKey> _logKeys = {};

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
    setState(() => _isLoading = true);
    await _loadLiveStats();
    await _loadReports();
    _buildDisplayLogs();
    if (!mounted) return;
    setState(() => _isLoading = false);
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
    int dailySessions = savedTimerDate == todayDate ? (prefs.getInt(dailyCompletedSessionsKey) ?? 0) : 0;
    int dailyStudySeconds = savedTimerDate == todayDate ? (prefs.getInt(dailyStudySecondsKey) ?? 0) : 0;

    final savedReport = await DailyReportService.getReportByDate(todayDate);

    final bool liveLooksEmpty = completed == 0 && skipped == 0 && pending == 0 && dailySessions == 0 && dailyStudySeconds == 0;

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
      logs[todayIndex] = logs[todayIndex].copyWith(
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

  Future<void> _shareLogAsImage(GlobalKey key, String date) async {
    try {
      RenderRepaintBoundary boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/TS_Report_$date.png').create();
      await imagePath.writeAsBytes(pngBytes);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Here is my TS Reminder Daily Report for ${_formatDatePretty(date)}! 🔥',
      );
    } catch (e) {
      debugPrint("Share error: $e");
    }
  }

  // ✅ ম্যাজিক শেয়ার প্রিভিউ ডায়লগ
  void _showMagicPreviewDialog(DailyReport report) {
    final GlobalKey magicKey = GlobalKey();
    final tasksDone = report.completedTasks + report.skippedTasks;
    final totalTasks = report.completedTasks + report.skippedTasks + report.pendingTasks;

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 📸 এই RepaintBoundary নোটখাতার ডিজাইনের ছবি তুলবে
            RepaintBoundary(
              key: magicKey,
              child: Container(
                width: 320,
                height: 480,
                decoration: const BoxDecoration(
                  image: DecorationImage(
                    image: AssetImage('assets/images/magic_bg.png'), // আপনার আপলোড করা ছবি
                    fit: BoxFit.cover,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 170, left: 45, right: 45), // নোটখাতার মাঝখানে লেখার জন্য প্যাডিং
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(
                        _formatDatePretty(report.date),
                        style: const TextStyle(
                          color: Color(0xFF6AE2C1), // পান্ডার নিচের লেখার কালারের সাথে মিলিয়ে
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 25),
                      Text('Study Time: ${report.studyMinutes}m', style: _magicStyle()),
                      const SizedBox(height: 12),
                      Text('Tasks Done: $tasksDone/$totalTasks', style: _magicStyle()),
                      const SizedBox(height: 12),
                      Text('Focus Sessions: ${report.focusSessions}', style: _magicStyle()),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF6AE2C1),
                foregroundColor: Colors.black87,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              ),
              onPressed: () async {
                Navigator.pop(ctx); // ডায়লগ বন্ধ করে শেয়ার করবে
                await _shareLogAsImage(magicKey, 'Magic_${report.date}');
              },
              icon: const Icon(Icons.share_rounded),
              label: const Text('Share Magic Card', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }

  TextStyle _magicStyle() {
    return const TextStyle(
      color: Color(0xFF555555), // সাদা খাতার ওপর গাঢ় ছাই রঙের লেখা
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayTasksDone = completedTasks + skippedTasks;
    final totalTodayTasks = completedTasks + skippedTasks + pendingTasks;
    final savedReportsCount = _savedReports.length;

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
                              'Stats',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 30,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _buildTodayOverviewCard(
                        todayTasksDone: todayTasksDone,
                        totalTodayTasks: totalTodayTasks,
                        savedReportsCount: savedReportsCount,
                      ),
                      const SizedBox(height: 20),
                      _buildDailyLogsCard(),
                    ],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildTodayOverviewCard({required int todayTasksDone, required int totalTodayTasks, required int savedReportsCount}) {
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
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Overview', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          _overviewRow(Icons.swap_horiz_rounded, 'Focus Sessions', '$focusSessions'),
          const SizedBox(height: 16),
          _overviewRow(Icons.timer_outlined, 'Total Study Time', '${studyMinutes}m'),
          const SizedBox(height: 16),
          _overviewRow(Icons.check_circle_rounded, 'Today Tasks Done', '$todayTasksDone/$totalTodayTasks'),
          const SizedBox(height: 16),
          _overviewRow(Icons.history_rounded, 'Saved Reports', '$savedReportsCount'),
        ],
      ),
    );
  }

  Widget _overviewRow(IconData icon, String label, String value) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF42B7FF), size: 28),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: const TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.w700))),
        Text(value, style: const TextStyle(color: AppColors.primaryText, fontSize: 17, fontWeight: FontWeight.w800)),
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
          BoxShadow(color: Colors.black.withOpacity(0.25), blurRadius: 14, offset: const Offset(0, 8)),
        ],
        border: Border.all(color: Colors.white.withOpacity(0.08), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Daily Logs', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          if (_displayLogs.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18), color: Colors.white.withOpacity(0.05)),
              child: const Text('No daily logs yet.', style: TextStyle(color: Colors.white70, fontSize: 14)),
            )
          else
            Column(
              children: _displayLogs.map((report) {
                return Padding(padding: const EdgeInsets.only(bottom: 14), child: _dailyLogItem(report));
              }).toList(),
            ),
        ],
      ),
    );
  }

  Widget _dailyLogItem(DailyReport report) {
    final tasksDone = report.completedTasks + report.skippedTasks;
    final totalTasks = report.completedTasks + report.skippedTasks + report.pendingTasks;
    final key = _logKeys.putIfAbsent(report.date, () => GlobalKey());

    return Stack(
      children: [
        RepaintBoundary(
          key: key,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              gradient: const LinearGradient(
                colors: [Color(0xFF1B2E49), Color(0xFF102643)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: report.date == todayDate ? const Color(0xFF42B7FF).withOpacity(0.4) : Colors.white.withOpacity(0.08),
                width: 1.5,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_formatDatePretty(report.date), style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                Text('Study Time: ${report.studyMinutes}m', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Tasks Done: $tasksDone/$totalTasks', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Skipped Tasks: ${report.skippedTasks}', style: const TextStyle(color: Colors.redAccent, fontSize: 15)),
                const SizedBox(height: 6),
                Text('Focus Sessions: ${report.focusSessions}', style: const TextStyle(color: Colors.white70, fontSize: 15)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Text('Rating: ', style: TextStyle(color: Color(0xFFFFB84D), fontSize: 15, fontWeight: FontWeight.w800)),
                    ...List.generate(5, (index) => Icon(Icons.star_rounded, size: 18, color: index < report.rating ? const Color(0xFFFFB84D) : Colors.white24)),
                  ],
                ),
              ],
            ),
          ),
        ),
        
        // 📤 Magic and Regular Share Buttons
        Positioned(
          top: 8,
          right: 8,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Text('🪄', style: TextStyle(fontSize: 20)),
                onPressed: () => _showMagicPreviewDialog(report),
                tooltip: 'Magic Share',
              ),
              IconButton(
                icon: const Icon(Icons.share_rounded, color: Colors.white70, size: 22),
                onPressed: () => _shareLogAsImage(key, report.date),
                tooltip: 'Standard Share',
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDatePretty(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    const months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    final monthName = (month >= 1 && month <= 12) ? months[month - 1] : parts[1];
    return '$monthName $day, $year';
  }
}
