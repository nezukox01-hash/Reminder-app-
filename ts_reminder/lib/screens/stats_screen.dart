import 'package:flutter/material.dart';

import '../models/daily_report_model.dart';
import '../services/daily_report_service.dart';
import '../utils/colors.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  List<DailyReport> reports = [];

  @override
  void initState() {
    super.initState();
    _loadReports();
  }

  Future<void> _loadReports() async {
    // ✅ FIXED: Changed getAllReports() to getReports()
    final data = await DailyReportService.getReports();

    if (!mounted) return;

    setState(() {
      // ✅ FIXED: Removed .reversed.toList() to keep the original safe order
      reports = data; 
    });
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
          child: reports.isEmpty
              ? const _EmptyView()
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: reports.length,
                  itemBuilder: (_, index) {
                    final report = reports[index];
                    return _reportCard(report);
                  },
                ),
        ),
      ),
    );
  }

  Widget _reportCard(DailyReport report) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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
            color: Colors.black.withOpacity(0.25),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          /// 📅 DATE
          Text(
            _formatDate(report.date),
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),

          const SizedBox(height: 10),

          /// ⭐ RATING
          Row(
            children: List.generate(5, (index) {
              return Icon(
                Icons.star_rounded,
                size: 20,
                color: index < report.rating
                    ? Colors.amber
                    : Colors.white24,
              );
            }),
          ),

          const SizedBox(height: 14),

          /// 📊 STATS
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _tag(Icons.timer, '${report.studyMinutes} min', Colors.blue),
              _tag(Icons.check, '${report.completedTasks} done', Colors.green),
              _tag(Icons.close, '${report.skippedTasks} skip', Colors.red),
              _tag(Icons.pending, '${report.pendingTasks} pending', Colors.orange),
            ],
          ),

          if (report.note.isNotEmpty) ...[
            const SizedBox(height: 14),

            /// 📝 NOTE
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: Colors.blue.withOpacity(0.08),
              ),
              child: Text(
                report.note,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                ),
              ),
            ),
          ]
        ],
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;

    return '${parts[2]}-${parts[1]}-${parts[0]}';
  }
}

class _EmptyView extends StatelessWidget {
  const _EmptyView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Text(
        'No reports yet 📊',
        style: TextStyle(
          color: Colors.white70,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
