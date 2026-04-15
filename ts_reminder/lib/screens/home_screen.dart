import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item.dart';
import '../services/audio_service.dart';
import '../services/daily_task_reset_service.dart'; // ✅ Added
import '../services/midnight_alarm_service.dart';   // ✅ Added
import '../utils/colors.dart';
import '../widgets/assistant_card.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/home_card.dart';
import 'daily_report_screen.dart';
import 'reminder_screen.dart';
import 'stats_screen.dart';
import 'tasks_screen.dart';
import 'timer_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int unfinishedTasks = 0;
  int totalTasks = 0;
  int highPriorityPendingCount = 0;

  bool isAssistantSpeaking = true;
  bool _hasPlayedOnce = false;

  Timer? _waveTimer;
  final Random _random = Random();

  List<double> waveValues = [14, 20, 12, 28, 16, 22, 14];

  @override
  void initState() {
    super.initState();
    _initApp(); // ✅ Changed to use the new _initApp() method
  }

  // ✅ NEW: Fallback logic for handling day rollover and alarms
  Future<void> _initApp() async {
    await DailyTaskResetService.handleDayRollover();
    await MidnightAlarmService.reschedule();

    _startWaveAnimation();

    await _loadTaskData();

    if (!_hasPlayedOnce) {
      _hasPlayedOnce = true;
      _playAssistantVoice();
    }
  }

  Future<void> _loadTaskData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList('ts_tasks_v5') ?? [];

    final tasks = data.map((e) => TaskItem.fromStorage(e)).toList();

    final int pendingCount =
        tasks.where((e) => !e.isDone && !e.isSkipped).length;

    final int highPriorityCount = tasks
        .where((e) => !e.isDone && !e.isSkipped && e.priority == 3)
        .length;

    if (!mounted) return;

    setState(() {
      totalTasks = tasks.length;
      unfinishedTasks = pendingCount;
      highPriorityPendingCount = highPriorityCount;
    });
  }

  Future<void> _playAssistantVoice() async {
    await Future.delayed(const Duration(milliseconds: 300));

    if (!mounted) return;

    setState(() {
      isAssistantSpeaking = true;
    });

    await AudioService.playHomeAssistantSequence(
      unfinishedTasks,
      totalTasks,
    );

    if (!mounted) return;

    setState(() {
      isAssistantSpeaking = false;
      waveValues = [12, 12, 12, 12, 12, 12, 12];
    });
  }

  void _startWaveAnimation() {
    _waveTimer?.cancel();

    _waveTimer = Timer.periodic(const Duration(milliseconds: 220), (_) {
      if (!mounted || !isAssistantSpeaking) return;

      setState(() {
        waveValues = List.generate(
          7,
          (_) => 10 + _random.nextInt(18).toDouble(),
        );
      });
    });
  }

  @override
  void dispose() {
    _waveTimer?.cancel();
    AudioService.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final greeting = AudioService.getGreetingByTime();
    final assistantText = AudioService.getAssistantMessage(
      unfinishedTasks,
      totalTasks,
      highPriorityPendingCount: highPriorityPendingCount,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      bottomNavigationBar: AppBottomNavBar(
        currentIndex: 2,
        onTap: (index) async {
          if (index == 0) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TimerScreen(),
              ),
            );
          } else if (index == 1) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const StatsScreen(),
              ),
            );
          } else if (index == 2) {
            return;
          } else if (index == 3) {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const DailyReportScreen(),
              ),
            );
          } else if (index == 4) {
            // Notes screen later
          }

          if (!mounted) return;
          await _loadTaskData();
        },
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            children: [
              _buildTopBar(),
              const SizedBox(height: 20),
              AssistantCard(
                greeting: greeting,
                message: assistantText,
                isSpeaking: isAssistantSpeaking,
                waveValues: waveValues,
              ),
              const SizedBox(height: 18),
              _buildQuickActions(),
              const SizedBox(height: 18),
              _buildFeatureGrid(),
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
              fontSize: 30,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
        Container(
          height: 62,
          width: 62,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: AppColors.surface.withOpacity(0.85),
          ),
          child: const Icon(
            Icons.notifications_none_rounded,
            color: Colors.white,
            size: 32,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(
          child: _QuickActionButton(
            icon: Icons.play_arrow_rounded,
            label: 'Start Focus',
            onTap: () {},
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.add_task_rounded,
            label: 'Add Task',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const TasksScreen(),
                ),
              );

              if (!mounted) return;
              await _loadTaskData();
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _QuickActionButton(
            icon: Icons.notifications_active_outlined,
            label: 'Add Reminder',
            onTap: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const ReminderScreen(),
                ),
              );

              if (!mounted) return;
              await _loadTaskData();
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 18,
      mainAxisSpacing: 18,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.95,
      children: [
        HomeCard(
          title: 'Timer',
          icon: Icons.timer_rounded,
          color: AppColors.timer,
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TimerScreen(),
              ),
            );
          },
        ),
        HomeCard(
          title: 'Reminder',
          icon: Icons.notifications_active_rounded,
          color: AppColors.reminder,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const ReminderScreen(),
              ),
            );

            if (!mounted) return;
            await _loadTaskData();
          },
        ),
        HomeCard(
          title: 'Daily Tasks',
          icon: Icons.check_circle_rounded,
          color: AppColors.tasks,
          onTap: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const TasksScreen(),
              ),
            );

            if (!mounted) return;
            await _loadTaskData();
          },
        ),
        const HomeCard(
          title: 'Motivation',
          icon: Icons.auto_awesome_rounded,
          color: AppColors.motivation,
        ),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: AppColors.surface,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              color: Colors.white,
              size: 34,
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: AppColors.primaryText,
                fontSize: 14,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
