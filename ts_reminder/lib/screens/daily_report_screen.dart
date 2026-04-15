import 'package:flutter/material.dart';

import '../models/daily_report_model.dart';
import '../services/daily_report_service.dart';
import '../utils/colors.dart';

class DailyReportScreen extends StatefulWidget {
  const DailyReportScreen({super.key});

  @override
  State<DailyReportScreen> createState() => _DailyReportScreenState();
}

class _DailyReportScreenState extends State<DailyReportScreen> {
  int rating = 0;
  final TextEditingController noteController = TextEditingController();

  // 🔹 Dummy values এখন (later real data connect করবো)
  int completedTasks = 0;
  int skippedTasks = 0;
  int pendingTasks = 0;
  int focusSessions = 0;
  int studyMinutes = 0;

  String get todayDate {
    final now = DateTime.now();
    return "${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}";
  }

  Future<void> _saveReport() async {
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
            padding: const EdgeInsets.all(20),
            children: [
              const Text(
                'Daily Report',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 20),

              /// 🔹 AUTO STATS CARD
              _buildStatsCard(),

              const SizedBox(height: 20),

              /// ⭐ RATING
              _buildRatingCard(),

              const SizedBox(height: 16),

              /// 📝 NOTE
              _buildNoteCard(),

              const SizedBox(height: 24),

              /// 💾 SAVE BUTTON
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
        borderRadius: BorderRadius.circular(22),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          _statRow("Study Time", "$studyMinutes min"),
          _statRow("Completed Tasks", "$completedTasks"),
          _statRow("Skipped Tasks", "$skippedTasks"),
          _statRow("Pending Tasks", "$pendingTasks"),
          _statRow("Focus Sessions", "$focusSessions"),
        ],
      ),
    );
  }

  Widget _statRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  /// ⭐ RATING CARD
  Widget _buildRatingCard() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.amber.withOpacity(0.15),
      ),
      child: Column(
        children: [
          const Text(
            "Rate your day",
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
                  Icons.star,
                  size: 32,
                  color: i <= rating ? Colors.amber : Colors.white24,
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  /// 📝 NOTE CARD
  Widget _buildNoteCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: Colors.blue.withOpacity(0.08),
      ),
      child: TextField(
        controller: noteController,
        maxLines: 4,
        style: const TextStyle(color: Colors.white),
        decoration: const InputDecoration(
          hintText: "Write your progress note...",
          hintStyle: TextStyle(color: Colors.white54),
          border: InputBorder.none,
        ),
      ),
    );
  }

  /// 💾 SAVE BUTTON
  Widget _buildSaveButton() {
    return ElevatedButton(
      onPressed: rating == 0 ? null : _saveReport,
      style: ElevatedButton.styleFrom(
        backgroundColor: const Color(0xFF4D88F8),
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      child: const Text(
        "Save Report",
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Colors.white,
        ),
      ),
    );
  }
}
