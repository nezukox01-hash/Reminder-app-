import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_core/firebase_core.dart'; //  Imported Firebase Core
import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'services/midnight_alarm_service.dart';
import 'services/task_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  //  Initialize Firebase (Must be called before using any Firebase services)
  await Firebase.initializeApp();

  await AndroidAlarmManager.initialize();
  await TaskReminderService.init();
  await MidnightAlarmService.scheduleNextMidnightAlarm();

  runApp(const TSReminderApp());
}

class TSReminderApp extends StatelessWidget {
  const TSReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TS Reminder',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        fontFamily: 'Roboto',
      ),
      home: const HomeScreen(),
    );
  }
}
