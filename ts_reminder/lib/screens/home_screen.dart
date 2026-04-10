import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final int unfinishedTasks = 2;

  bool isAssistantSpeaking = true;
  late Timer _waveTimer;
  final Random _random = Random();

  List<double> waveValues = [18, 26, 14, 30, 22, 16, 28];

  @override
  void initState() {
    super.initState();
    _startWaveAnimation();

    Future.delayed(const Duration(seconds: 4), () {
      if (mounted) {
        setState(() {
          isAssistantSpeaking = false;
          waveValues = [8, 8, 8, 8, 8, 8, 8];
        });
      }
    });
  }

  void _startWaveAnimation() {
    _waveTimer = Timer.periodic(const Duration(milliseconds: 180), (_) {
      if (!mounted) return;

      if (isAssistantSpeaking) {
        setState(() {
          waveValues = List.generate(
            7,
            (_) => 10 + _random.nextInt(26).toDouble(),
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _waveTimer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = AudioService.getGreetingByTime();
    final assistantText = AudioService.getAssistantMessage(unfinishedTasks);

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: _buildBottomNav(),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 24),
            children: [
              _buildTopBar(),
              const SizedBox(height: 18),
              _buildAssistantCard(greeting, assistantText),
              const SizedBox(height: 18),
              _buildQuickActions(),
              const SizedBox(height: 18),
              _buildFeatureGrid(),
              const SizedBox(height: 18),
              _buildTodaySummary(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar() {
    return Row(
      children: [
        const Expanded(
          child: Text(
            'TS Reminder',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 28,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        Container(
          height: 44,
          width: 44,
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(14),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
          ),
        ),
      ],
    );
  }

  Widget _buildAssistantCard(String greeting, String assistantText) {
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
            color: Colors.black.withOpacity(0.25),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.graphic_eq_rounded, color: Colors.white),
              SizedBox(width: 8),
              Text(
                'Personal Assistant',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            greeting,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            assistantText,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          _buildWaveRow(),
        ],
      ),
    );
  }

  Widget _buildWaveRow() {
    return SizedBox(
      height: 42,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: waveValues.map((value) {
          return AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeInOut,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: 7,
            height: value,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _quickButton(
            icon: Icons.play_arrow_rounded,
            label: 'Start Focus',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickButton(
            icon: Icons.add_task_rounded,
            label: 'Add Task',
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _quickButton(
            icon: Icons.add_alert_rounded,
            label: 'Add Reminder',
          ),
        ),
      ],
    );
  }

  Widget _quickButton({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          Icon(icon, color: Colors.white, size: 24),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.02,
      children: const [
        _FeatureCard(
          title: 'Timer',
          subtitle: '25/5 focus',
          icon: Icons.timer_rounded,
          color: AppColors.timer,
        ),
        _FeatureCard(
          title: 'Reminder',
          subtitle: 'Alerts & plans',
          icon: Icons.notifications_active_rounded,
          color: AppColors.reminder,
        ),
        _FeatureCard(
          title: 'Daily Tasks',
          subtitle: 'Track progress',
          icon: Icons.check_circle_rounded,
          color: AppColors.tasks,
        ),
        _FeatureCard(
          title: 'Motivation',
          subtitle: 'Stay strong',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.motivation,
        ),
        _FeatureCard(
          title: 'Daily Report',
          subtitle: 'Rate your day',
          icon: Icons.bar_chart_rounded,
          color: AppColors.report,
        ),
        _FeatureCard(
          title: 'Notes',
          subtitle: 'Write quickly',
          icon: Icons.note_alt_rounded,
          color: AppColors.notes,
        ),
      ],
    );
  }

  Widget _buildTodaySummary() {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: AppColors.surface,
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Today Summary',
            style: TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          SizedBox(height: 14),
          _SummaryRow(label: 'Today Rating', value: '4/10'),
          SizedBox(height: 10),
          _SummaryRow(label: 'Focus Sessions', value: '2'),
          SizedBox(height: 10),
          _SummaryRow(label: 'Completed Tasks', value: '3/5'),
        ],
      ),
    );
  }

  Widget _buildBottomNav() {
    return Container(
      height: 76,
      decoration: const BoxDecoration(
        color: AppColors.navBackground,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _navItem(Icons.timer_outlined, 'Timer', false),
          _navItem(Icons.bar_chart_outlined, 'Stats', false),
          Container(
            height: 58,
            width: 58,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
            child: const Icon(
              Icons.home_rounded,
              color: AppColors.background,
              size: 30,
            ),
          ),
          _navItem(Icons.description_outlined, 'Report', false),
          _navItem(Icons.note_outlined, 'Notes', false),
        ],
      ),
    );
  }

  Widget _navItem(IconData icon, String label, bool selected) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          icon,
          color: selected ? AppColors.navSelected : AppColors.navUnselected,
          size: 23,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: selected ? AppColors.navSelected : AppColors.navUnselected,
            fontSize: 11,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _FeatureCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  const _FeatureCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: const LinearGradient(
          colors: [AppColors.surface2, AppColors.surface],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.45)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Icon(icon, color: Colors.white, size: 30),
          ),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  final String label;
  final String value;

  const _SummaryRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 14,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
