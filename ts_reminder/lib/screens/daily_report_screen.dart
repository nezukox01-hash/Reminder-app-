import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/daily_report_model.dart';
import '../services/daily_report_service.dart';
import '../utils/colors.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  static const String tasksStorageKey = 'ts_tasks_v5';
  static const String dailyTimerDateKey = 'daily_timer_date';
  static const String dailyCompletedSessionsKey = 'daily_completed_focus_sessions';
  static const String dailyStudySecondsKey = 'daily_study_seconds';

  int rating = 0;
  final TextEditingController noteController = TextEditingController();

  int completedTasks = 0;
  int skippedTasks = 0;
  int pendingTasks = 0;
  int focusSessions = 0;
  int studyMinutes = 0;

  bool _isSaving = false;

  String get todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _loadAutoStats();
    _loadExistingReport();
  }

  @override
  void dispose() {
    noteController.dispose();
    super.dispose();
  }

  Future<void> _loadAutoStats() async {
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
    final int dailySessions =
        savedTimerDate == todayDate ? (prefs.getInt(dailyCompletedSessionsKey) ?? 0) : 0;
    final int dailyStudySeconds =
        savedTimerDate == todayDate ? (prefs.getInt(dailyStudySecondsKey) ?? 0) : 0;

    if (!mounted) return;

    setState(() {
      completedTasks = completed;
      skippedTasks = skipped;
      pendingTasks = pending;
      focusSessions = dailySessions;
      studyMinutes = dailyStudySeconds ~/ 60;
    });
  }

  Future<void> _loadExistingReport() async {
    final report = await DailyReportService.getReportByDate(todayDate);
    if (report == null || !mounted) return;

    setState(() {
      rating = report.rating;
      noteController.text = report.note;
    });
  }

  Future<void> _saveReport() async {
    if (rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please give rating ⭐'),
        ),
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    final report = DailyReport(
      date: todayDate,
      completedTasks: completedTasks,
      skippedTasks: skippedTasks,
      pendingTasks: pendingTasks,
      focusSessions: focusSessions,
      studyMinutes: studyMinutes,
      rating: rating,
      note: noteController.text.trim(),
    );

    await DailyReportService.saveReport(report);

    if (!mounted) return;

    setState(() {
      _isSaving = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Report Saved Successfully ✅'),
      ),
    );
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
                      'Daily Report',
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
              _buildStatsCard(),
              const SizedBox(height: 18),
              _buildRatingCard(),
              const SizedBox(height: 16),
              _buildNoteCard(),
              const SizedBox(height: 24),
              _buildSaveButton(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.22),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          _statRow('Study Time', '$studyMinutes min'),
          _divider(),
          _statRow('Completed Tasks', '$completedTasks'),
          _divider(),
          _statRow('Skipped Tasks', '$skippedTasks'),
          _divider(),
          _statRow('Pending Tasks', '$pendingTasks'),
          _divider(),
          _statRow('Focus Sessions', '$focusSessions'),
        ],
      ),
    );
  }

  Widget _statRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _divider() {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      height: 1,
      color: Colors.white.withOpacity(0.06),
    );
  }

  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.amber.withOpacity(0.14),
        boxShadow: [
          BoxShadow(
            color: Colors.amber.withOpacity(0.10),
            blurRadius: 14,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          const Text(
            'Rate your day',
            style: TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              final i = index + 1;
              return IconButton(
                onPressed: () {
                  setState(() {
                    rating = i;
                  });
                },
                icon: Icon(
                  Icons.star_rounded,
                  size: 34,
                  color: i <= rating ? Colors.amber : Colors.white24,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: Colors.blue.withOpacity(0.08),
        boxShadow: [
          BoxShadow(
            color: Colors.blue.withOpacity(0.08),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: TextField(
        controller: noteController,
        maxLines: 5,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: 'Write your progress note...',
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
    );
  }

  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: _isSaving ? null : _saveReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4D88F8),
        disabledBackgroundColor: const Color(0xFF4D88F8).withOpacity(0.5),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      child: _isSaving
          ? const SizedBox(
              height: 22,
              width: 22,
              child: CircularProgressIndicator(
                strokeWidth: 2.4,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            )
          : const Text(
              'Save Report',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: Colors.white,
              ),
            ),
    );
  }
}
