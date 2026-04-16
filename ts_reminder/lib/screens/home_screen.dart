import 'dart:async';
import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart'; // ✅ Added for Auth state
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task_item.dart';
import '../services/audio_service.dart';
import '../services/auth_service.dart'; // ✅ Imported your new AuthService
import '../services/cloud_sync_service.dart'; // ✅ Imported your new SyncService
import '../services/daily_task_reset_service.dart';
import '../services/midnight_alarm_service.dart';
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
  static const String tasksKey = 'ts_tasks_v5';
  static const String dailyTimerDateKey = 'daily_timer_date';
  static const String dailyCompletedSessionsKey =
      'daily_completed_focus_sessions';
  static const String dailyStudySecondsKey = 'daily_study_seconds';

  int unfinishedTasks = 0;
  int totalTasks = 0;
  int highPriorityPendingCount = 0;

  int dailyStudyMinutes = 0;
  int dailyFocusSessions = 0;

  bool isAssistantSpeaking = true;
  bool _hasPlayedOnce = false;
  bool _isLoading = false; // ✅ To show loading during login

  Timer? _waveTimer;
  final Random _random = Random();

  List<double> waveValues = [14, 20, 12, 28, 16, 22, 14];

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  String get todayDate {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  Future<void> _initApp() async {
    await DailyTaskResetService.handleDayRollover();
    await MidnightAlarmService.reschedule();

    _startWaveAnimation();
    await _loadTaskData();

    if (!_hasPlayedOnce) {
      _hasPlayedOnce = true;
      await _playAssistantVoice();
    }
  }

  Future<void> _loadTaskData() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(tasksKey) ?? [];

    final tasks = data.map((e) => TaskItem.fromStorage(e)).toList();

    final todayTasks = tasks.where((task) {
      final date = task.taskDate.isEmpty ? todayDate : task.taskDate;
      return date == todayDate;
    }).toList();

    final int pendingCount =
        todayTasks.where((e) => !e.isDone && !e.isSkipped).length;

    final int highPriorityCount = todayTasks
        .where((e) => !e.isDone && !e.isSkipped && e.priority == 3)
        .length;

    final savedTimerDate = prefs.getString(dailyTimerDateKey) ?? '';
    final int studySeconds = savedTimerDate == todayDate
        ? (prefs.getInt(dailyStudySecondsKey) ?? 0)
        : 0;
    final int sessions = savedTimerDate == todayDate
        ? (prefs.getInt(dailyCompletedSessionsKey) ?? 0)
        : 0;

    if (!mounted) return;

    setState(() {
      totalTasks = todayTasks.length;
      unfinishedTasks = pendingCount;
      highPriorityPendingCount = highPriorityCount;
      dailyStudyMinutes = studySeconds ~/ 60;
      dailyFocusSessions = sessions;
    });
  }

  // ✅ New: Handle Login Process
  Future<void> _handleLogin() async {
    setState(() => _isLoading = true);

    try {
      final user = await AuthService.signInWithGoogle();
      if (user != null) {
        // Download old data from cloud after login
        await CloudSyncService.downloadData(user.uid);
        // Refresh UI with downloaded data
        await _loadTaskData();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Welcome, ${user.displayName}!")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Login Failed. Please try again.")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ✅ New: Handle Logout Process
  Future<void> _handleLogout() async {
    await AuthService.signOut();
    if (mounted) {
      setState(() {}); // Refresh to show login icon
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Logged out successfully.")),
      );
    }
  }

  Future<void> _playAssistantVoice() async {
    await Future.delayed(const Duration(milliseconds: 300));
    if (!mounted) return;
    setState(() => isAssistantSpeaking = true);

    await AudioService.playHomeAssistantSequence(unfinishedTasks, totalTasks);

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
        waveValues = List.generate(7, (_) => 10 + _random.nextInt(18).toDouble());
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
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
          } else if (index == 1) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const StatsScreen()));
          } else if (index == 2) {
            return;
          } else if (index == 3) {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const DailyReportScreen()));
          }
          if (!mounted) return;
          await _loadTaskData();
        },
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.pageGradient),
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
    final User? user = AuthService.currentUser;

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
        GestureDetector(
          onTap: user == null ? _handleLogin : () {
            // Show logout option if already logged in
            showDialog(
              context: context,
              builder: (context) => AlertDialog(
                title: const Text("Account"),
                content: Text("Logged in as ${user.displayName}"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      _handleLogout();
                    }, 
                    child: const Text("Logout", style: TextStyle(color: Colors.red))
                  ),
                ],
              ),
            );
          },
          child: Container(
            height: 62,
            width: 62,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              color: AppColors.surface.withOpacity(0.85),
              image: user != null && user.photoURL != null
                  ? DecorationImage(image: NetworkImage(user.photoURL!), fit: BoxFit.cover)
                  : null,
            ),
            child: user == null
                ? (_isLoading 
                    ? const Padding(padding: EdgeInsets.all(15), child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Icon(Icons.person_outline_rounded, color: Colors.white, size: 32))
                : (user.photoURL == null ? const Icon(Icons.person, color: Colors.white) : null),
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActions() {
    return Row(
      children: [
        Expanded(child: _QuickActionButton(icon: Icons.play_arrow_rounded, label: 'Start Focus', onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
          await _loadTaskData();
        })),
        const SizedBox(width: 12),
        Expanded(child: _QuickActionButton(icon: Icons.add_task_rounded, label: 'Add Task', onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
          await _loadTaskData();
        })),
        const SizedBox(width: 12),
        Expanded(child: _QuickActionButton(icon: Icons.notifications_active_outlined, label: 'Add Reminder', onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderScreen()));
          await _loadTaskData();
        })),
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
        HomeCard(title: 'Timer', icon: Icons.timer_rounded, color: AppColors.timer, onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TimerScreen()));
          await _loadTaskData();
        }),
        HomeCard(title: 'Reminder', icon: Icons.notifications_active_rounded, color: AppColors.reminder, onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const ReminderScreen()));
          await _loadTaskData();
        }),
        HomeCard(title: 'Daily Tasks', icon: Icons.check_circle_rounded, color: AppColors.tasks, onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const TasksScreen()));
          await _loadTaskData();
        }),
        const HomeCard(title: 'Motivation', icon: Icons.auto_awesome_rounded, color: AppColors.motivation),
      ],
    );
  }
}

class _QuickActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickActionButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.symmetric(vertical: 22),
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(22), color: AppColors.surface),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 34),
            const SizedBox(height: 10),
            Text(label, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.primaryText, fontSize: 14, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
