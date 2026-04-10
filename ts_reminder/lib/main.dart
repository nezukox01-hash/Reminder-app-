import 'package:flutter/material.dart';

void main() {
  runApp(const TSReminderApp());
}

class TSReminderApp extends StatelessWidget {
  const TSReminderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TS Reminder',
      home: Scaffold(
        appBar: AppBar(
          title: const Text('TS Reminder Home'),
        ),
        body: const Center(
          child: Text('Welcome to TS Reminder!'),
        ),
      ),
    );
  }
}
