import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  tz.initializeTimeZones();

  runApp(
    ChangeNotifierProvider(
      create: (_) => AppState(prefs),
      child: const TSReminderApp(),
    ),
  );
}

class TSReminderApp extends StatelessWidget {
  const TSReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TS Reminder + Study Timer',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class AppState extends ChangeNotifier {
  final SharedPreferences prefs;
  int dailyTaskCount = 0;

  // Timer
  Timer? timer;
  bool isTimerRunning = false;
  Duration currentDuration = const Duration(minutes: 25);
  bool isFocus = true; // true = focus, false = break

  // Notifications
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer audioPlayer = AudioPlayer();

  AppState(this.prefs) {
    dailyTaskCount = prefs.getInt('dailyTaskCount') ?? 0;
    _initializeNotifications();
  }

  void _initializeNotifications() async {
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const InitializationSettings initializationSettings =
        InitializationSettings(android: initializationSettingsAndroid);
    await flutterLocalNotificationsPlugin.initialize(initializationSettings);
  }

  // Timer functions
  void startTimer(Duration duration) {
    currentDuration = duration;
    isTimerRunning = true;
    timer?.cancel();
    timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (currentDuration.inSeconds > 0) {
        currentDuration -= const Duration(seconds: 1);
        notifyListeners();
      } else {
        _switchTimer();
      }
    });
    notifyListeners();
  }

  void stopTimer() {
    isTimerRunning = false;
    timer?.cancel();
    currentDuration = const Duration(minutes: 25);
    isFocus = true;
    notifyListeners();
  }

  void _switchTimer() {
    // Toggle between focus/break
    isFocus = !isFocus;
    currentDuration = isFocus ? const Duration(minutes: 25) : const Duration(minutes: 5);
    _playSound();
    notifyListeners();
  }

  void incrementDailyTask() {
    dailyTaskCount++;
    prefs.setInt('dailyTaskCount', dailyTaskCount);
    notifyListeners();
  }

  Future<void> _playSound() async {
    try {
      await audioPlayer.setAsset('assets/sounds/reminder.mp3');
      audioPlayer.play();
    } catch (e) {
      debugPrint('Error playing sound: $e');
    }
  }

  Future<void> scheduleReminder({required int seconds}) async {
    final scheduledTime = tz.TZDateTime.now(tz.local).add(Duration(seconds: seconds));
    const androidDetails = AndroidNotificationDetails(
      'reminder_channel',
      'Reminder Notifications',
      channelDescription: 'Notifications for TS Reminder tasks',
      importance: Importance.max,
      priority: Priority.high,
    );
    const notificationDetails = NotificationDetails(android: androidDetails);
    await flutterLocalNotificationsPlugin.zonedSchedule(
      0,
      'TS Reminder',
      'Time to check your task!',
      scheduledTime,
      notificationDetails,
      androidAllowWhileIdle: true,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
    _playSound();
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('TS Reminder + Study Timer'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            // Study Timer Card
            HomeCard(
              title: 'Study Timer',
              icon: Icons.timer,
              color: appState.isFocus ? Colors.greenAccent : Colors.redAccent,
              child: Column(
                children: [
                  Text(
                    appState.isTimerRunning
                        ? formatDuration(appState.currentDuration)
                        : '25:00',
                    style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ElevatedButton(
                        onPressed: appState.isTimerRunning
                            ? null
                            : () => appState.startTimer(const Duration(minutes: 25)),
                        child: const Text('Start Focus'),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: appState.isTimerRunning ? appState.stopTimer : null,
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Daily Tasks Card
            HomeCard(
              title: 'Daily Tasks',
              icon: Icons.check_circle,
              color: Colors.blueAccent,
              child: ListTile(
                title: const Text('Tasks Completed Today'),
                trailing: Text('${appState.dailyTaskCount}'),
                onTap: () => appState.incrementDailyTask(),
              ),
            ),
            const SizedBox(height: 20),

            // Reminder Card
            HomeCard(
              title: 'Reminders',
              icon: Icons.notifications,
              color: Colors.orangeAccent,
              child: Center(
                child: ElevatedButton(
                  onPressed: () => appState.scheduleReminder(seconds: 10),
                  child: const Text('Test Reminder in 10s'),
                ),
              ),
            ),
            const SizedBox(height: 20),

            // Daily Report Card
            HomeCard(
              title: 'Daily Report',
              icon: Icons.bar_chart,
              color: Colors.purpleAccent,
              child: const Center(child: Text('Daily report placeholder')),
            ),
            const SizedBox(height: 20),

            // Notes Card
            HomeCard(
              title: 'Notes',
              icon: Icons.note,
              color: Colors.tealAccent,
              child: const Center(child: Text('Notes placeholder')),
            ),
          ],
        ),
      ),
    );
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$minutes:$seconds';
  }
}

class HomeCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const HomeCard({
    super.key,
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            CircleAvatar(
              backgroundColor: color.withOpacity(0.3),
              radius: 28,
              child: Icon(icon, size: 32, color: Colors.white),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}
