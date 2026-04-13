import 'package:flutter/material.dart';
import 'package:timezone/data/latest_all.dart' as tz;

import 'screens/home_screen.dart';
import 'services/task_reminder_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await TaskReminderService.init();
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
