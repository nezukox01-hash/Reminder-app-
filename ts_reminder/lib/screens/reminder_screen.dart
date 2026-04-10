import 'package:flutter/material.dart';

class ReminderScreen extends StatelessWidget {
  const ReminderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reminder')),
      body: const Center(child: Text('Reminder Screen')),
    );
  }
}
