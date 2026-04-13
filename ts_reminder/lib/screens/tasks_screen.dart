import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/task_helper.dart';
import '../models/task_item.dart';
import '../services/task_reminder_service.dart';
import '../utils/colors.dart';
import '../widgets/extra/magic_five_bubble.dart';
import '../widgets/extra/skip_motivation_dialog.dart';

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String storageKey = 'ts_tasks_v5';

  final List<TaskItem> _tasks = [];
  SharedPreferences? _prefs;
  OverlayEntry? _magicFiveEntry;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  @override
  void dispose() {
    _magicFiveEntry?.remove();
    super.dispose();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final data = _prefs?.getStringList(storageKey) ?? [];

    _tasks
      ..clear()
      ..addAll(data.map(TaskItem.fromStorage));

    _sortTasks();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveTasks() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    await prefs.setStringList(
      storageKey,
      _tasks.map((e) => e.toStorage()).toList(),
    );
  }

  void _sortTasks() {
    sortTasks(_tasks);
  }

  int get _doneCount => _tasks.where((e) => e.isDone).length;
  int get _skippedCount => _tasks.where((e) => e.isSkipped).length;
  int get _pendingCount =>
      _tasks.where((e) => !e.isDone && !e.isSkipped).length;

  Future<void> _scheduleIfNeeded(TaskItem task) async {
    await TaskReminderService.cancelTaskReminder(task.id);

    if (task.reminderTime.isEmpty || task.isDone || task.isSkipped) return;

    try {
      await TaskReminderService.scheduleTaskReminder(
        taskId: task.id,
        title: 'Task Reminder',
        body: task.title,
        reminderTime: task.reminderTime,
      );
    } catch (e, stacktrace) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('NOTIFICATION ERROR:\n$e', style: const TextStyle(fontWeight: FontWeight.bold)),
            backgroundColor: Colors.redAccent,
            duration: const Duration(seconds: 10),
          ),
        );
      }
      print("Error: $e\n$stacktrace");
    }
  }

  Future<void> _openTaskDialog({TaskItem? existing}) async {
    final titleController =
        TextEditingController(text: existing != null ? existing.title : '');
    final noteController =
        TextEditingController(text: existing != null ? existing.note : '');
    final focusController = TextEditingController(
      text: existing != null && existing.focusMinutes > 0
          ? existing.focusMinutes.toString()
          : '',
    );

    int selectedPriority = existing?.priority ?? 2;

    TimeOfDay? selectedTime;
    if (existing != null && existing.reminderTime.isNotEmpty) {
      selectedTime = _parseTime(existing.reminderTime);
    }

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setLocalState) {
            return AlertDialog(
              backgroundColor: const Color(0xFF102643),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(24),
              ),
              title: Text(
                existing == null ? 'Add Task' : 'Edit Task',
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildField(
                      label: 'Task Title',
                      controller: titleController,
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Note',
                      controller: noteController,
                    ),
                    const SizedBox(height: 14),
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: () async {
                        final picked = await showTimePicker(
                          context: context,
                          initialTime: selectedTime ?? TimeOfDay.now(),
                        );
                        if (picked != null) {
                          setLocalState(() {
                            selectedTime = picked;
                          });
                        }
                      },
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1B2E49),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.access_time_rounded,
                              color: Colors.white,
                            ),
                            const SizedBox(width: 10),
                            Text(
                              selectedTime == null
                                  ? 'Set Reminder Time'
                                  : selectedTime!.format(context),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    _buildField(
                      label: 'Focus Timer Minutes (optional)',
                      controller: focusController,
                      numberOnly: true,
                    ),
                    const SizedBox(height: 14),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF1B2E49),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Priority',
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: _priorityButton(
                                  label: 'Low',
                                  color: Colors.grey,
                                  selected: selectedPriority == 1,
                                  onTap: () {
                                    setLocalState(() {
                                      selectedPriority = 1;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _priorityButton(
                                  label: 'Medium',
                                  color: Colors.blue,
                                  selected: selectedPriority == 2,
                                  onTap: () {
                                    setLocalState(() {
                                      selectedPriority = 2;
                                    });
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: _priorityButton(
                                  label: 'High',
                                  color: Colors.redAccent,
                                  selected: selectedPriority == 3,
                                  onTap: () {
                                    setLocalState(() {
                                      selectedPriority = 3;
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.white70),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4D88F8),
                  ),
                  onPressed: () async {
                    final title = titleController.text.trim();
                    final note = noteController.text.trim();
                    final focusMinutes =
                        int.tryParse(focusController.text.trim()) ?? 0;
                    final reminderString = selectedTime == null
                        ? ''
                        : '${selectedTime!.hour}:${selectedTime!.minute.toString().padLeft(2, '0')}';

                    if (title.isEmpty) return;

                    TaskItem savedTask;

                    if (existing == null) {
                      savedTask = TaskItem(
                        id: DateTime.now().millisecondsSinceEpoch.toString(),
                        title: title,
                        note: note,
                        isDone: false,
                        isSkipped: false,
                        reminderTime: reminderString,
                        focusMinutes: focusMinutes,
                        priority: selectedPriority,
                      );
                      _tasks.add(savedTask);
                    } else {
                      final index =
                          _tasks.indexWhere((e) => e.id == existing.id);
                      if (index == -1) return;

                      savedTask = existing.copyWith(
                        title: title,
                        note: note,
                        reminderTime: reminderString,
                        focusMinutes: focusMinutes,
                        priority: selectedPriority,
                      );
                      _tasks[index] = savedTask;
                    }

                    _sortTasks();

                    if (mounted) {
                      setState(() {});
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }

                    await _saveTasks();
                    await _scheduleIfNeeded(savedTask);
                  },
                  child: Text(
                    existing == null ? 'Save' : 'Update',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
    bool numberOnly = false,
  }) {
    return TextField(
      controller: controller,
      keyboardType: numberOnly ? TextInputType.number : TextInputType.text,
      style: const TextStyle(color: Colors.white),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: Colors.white70),
        filled: true,
        fillColor: const Color(0xFF1B2E49),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  Widget _priorityButton({
    required String label,
    required Color color,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: selected ? color.withOpacity(0.25) : Colors.white10,
          border: Border.all(
            color: selected ? color : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: selected ? color : Colors.white70,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  TimeOfDay? _parseTime(String value) {
    try {
      final parts = value.split(':');
      if (parts.length != 2) return null;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  void _showMagicFiveBubble() {
    _magicFiveEntry?.remove();

    _magicFiveEntry = OverlayEntry(
      builder: (_) => MagicFiveBubble(
        onClose: () {
          _magicFiveEntry?.remove();
          _magicFiveEntry = null;
        },
      ),
    );

    Overlay.of(context).insert(_magicFiveEntry!);
  }

  Future<void> _applySkipTask(TaskItem task) async {
    final index = _tasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(
      isSkipped: true,
      isDone: false,
    );

    _sortTasks();

    if (mounted) {
      setState(() {});
    }

    await _saveTasks();
    await TaskReminderService.cancelTaskReminder(task.id);
  }

  Future<void> _showHighPrioritySkipWarning(TaskItem task) async {
    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102643),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Skip High Priority Task?',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: const Text(
            'Are you sure you want to skip this task?\n\nIf you need a little push, tap Help Me.',
            style: TextStyle(
              color: Colors.white70,
              height: 1.5,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'cancel');
              },
              child: const Text(
                'Cancel',
                style: TextStyle(color: Colors.white70),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(context, 'skip');
              },
              child: const Text(
                'Skip Anyway',
                style: TextStyle(color: Colors.redAccent),
              ),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4D88F8),
              ),
              onPressed: () {
                Navigator.pop(context, 'help');
              },
              child: const Text(
                'Help Me',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );

    if (result == 'skip') {
      await _applySkipTask(task);
    } else if (result == 'help') {
      await _showMotivationDialog(task);
    }
  }

  Future<void> _showMotivationDialog(TaskItem task) async {
    if (!mounted) return;

    final result = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (_) {
        return SkipMotivationDialog(
          onSkip: () {
            Navigator.pop(context, 'skip');
          },
          onStartMagic: () {
            Navigator.pop(context, 'magic');
          },
          onLetsDoIt: () {
            Navigator.pop(context, 'doit');
          },
        );
      },
    );

    if (result == 'skip') {
      await _applySkipTask(task);
    } else if (result == 'magic') {
      _showMagicFiveBubble();
    }
  }

  Future<void> _toggleTask(TaskItem task) async {
    final index = _tasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(
      isDone: !task.isDone,
      isSkipped: false,
    );

    _sortTasks();

    if (mounted) {
      setState(() {});
    }

    final updatedTask = _tasks[index];
    await _saveTasks();
    await _scheduleIfNeeded(updatedTask);
  }

  Future<void> _skipTask(TaskItem task) async {
    if (task.priority == 3) {
      await _showHighPrioritySkipWarning(task);
      return;
    }

    await _applySkipTask(task);
  }

  Future<void> _deleteTask(TaskItem task) async {
    _tasks.removeWhere((e) => e.id == task.id);

    if (mounted) {
      setState(() {});
    }

    await _saveTasks();
    await TaskReminderService.cancelTaskReminder(task.id);
  }

  Color _priorityColor(int priority) {
    switch (priority) {
      case 1:
        return Colors.grey;
      case 2:
        return Colors.blue;
      case 3:
        return Colors.redAccent;
      default:
        return Colors.blue;
    }
  }

  String _priorityLabel(int priority) {
    switch (priority) {
      case 1:
        return 'Low';
      case 2:
        return 'Medium';
      case 3:
        return 'High';
      default:
        return 'Medium';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4D88F8),
        onPressed: () => _openTaskDialog(),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        'Daily Tasks',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    // 👈 THE 10-SECOND TIMER TEST
                    IconButton(
                      onPressed: () async {
                        try {
                          final plugin = FlutterLocalNotificationsPlugin();
                          
                          // Force Bangladesh time for the test
                          tz.initializeTimeZones();
                          tz.setLocalLocation(tz.getLocation('Asia/Dhaka'));

                          await plugin.zonedSchedule(
                            54321,
                            'TIMER TEST',
                            '10 seconds have passed! Timers work!',
                            tz.TZDateTime.now(tz.local).add(const Duration(seconds: 10)),
                            const NotificationDetails(
                              android: AndroidNotificationDetails(
                                'timer_test_channel', 
                                'Timer Test', 
                                importance: Importance.max, 
                                priority: Priority.high,
                                icon: '@mipmap/ic_launcher', 
                              ),
                            ),
                            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
                            uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
                          );

                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('⏳ Timer set! Wait 10 seconds...'), backgroundColor: Colors.orange),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('❌ CRASH: $e'), backgroundColor: Colors.red, duration: const Duration(seconds: 10)),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.timer, color: Colors.orangeAccent, size: 30),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    Expanded(
                      child: _statBox(
                        'Pending',
                        _pendingCount,
                        Colors.orange,
                        Icons.access_time_filled_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        'Done',
                        _doneCount,
                        Colors.green,
                        Icons.check_circle_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _statBox(
                        'Skipped',
                        _skippedCount,
                        Colors.redAccent,
                        Icons.cancel_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Expanded(
                child: _tasks.isEmpty
                    ? const _EmptyTasksView()
                    : ListView.builder(
                        itemCount: _tasks.length,
                        itemBuilder: (context, index) {
                          final task = _tasks[index];
                          return _taskTile(task);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _statBox(
    String title,
    int value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: Colors.white.withOpacity(0.05),
      ),
      child: Column(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.18),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: const TextStyle(color: Colors.white70),
          ),
          const SizedBox(height: 4),
          Text(
            '$value',
            style: TextStyle(
              color: color,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskTile(TaskItem task) {
    final titleStyle = TextStyle(
      color: task.isDone
          ? Colors.white54
          : task.isSkipped
              ? Colors.white60
              : Colors.white,
      fontSize: 16,
      fontWeight: FontWeight.w600,
      decoration: task.isDone || task.isSkipped
          ? TextDecoration.lineThrough
          : null,
      decorationColor:
          task.isDone ? const Color(0xFF20C08A) : Colors.black,
      decorationThickness: task.isDone ? 3 : 4,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: () => _toggleTask(task),
              child: Icon(
                task.isDone
                    ? Icons.check_circle
                    : task.isSkipped
                        ? Icons.cancel
                        : Icons.radio_button_unchecked,
                color: task.isDone
                    ? Colors.green
                    : task.isSkipped
                        ? Colors.redAccent
                        : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title, style: titleStyle),
                  if (task.note.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      task.note,
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _tag(
                        Icons.flag_rounded,
                        _priorityLabel(task.priority),
                        _priorityColor(task.priority),
                      ),
                      if (task.reminderTime.isNotEmpty)
                        _tag(
                          Icons.access_time_rounded,
                          task.reminderTime,
                          Colors.orange,
                        ),
                      if (task.focusMinutes > 0)
                        _tag(
                          Icons.timer_rounded,
                          '${task.focusMinutes} min',
                          const Color(0xFF20C08A),
                        ),
                      if (task.isDone)
                        _tag(
                          Icons.check_circle_rounded,
                          'Done',
                          const Color(0xFF20C08A),
                        ),
                      if (task.isSkipped)
                        _tag(
                          Icons.close_rounded,
                          'Skipped',
                          Colors.redAccent,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: const Icon(
                Icons.more_vert,
                color: Colors.white,
              ),
              color: const Color(0xFF102643),
              onSelected: (value) {
                if (value == 'edit') _openTaskDialog(existing: task);
                if (value == 'skip') _skipTask(task);
                if (value == 'delete') _deleteTask(task);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'skip',
                  child: Text('Skip', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete', style: TextStyle(color: Colors.white)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withOpacity(0.15),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyTasksView extends StatelessWidget {
  const _EmptyTasksView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: const LinearGradient(
              colors: [AppColors.surface2, AppColors.surface],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.task_alt_rounded,
                color: Colors.white70,
                size: 54,
              ),
              SizedBox(height: 16),
              Text(
                'No tasks yet',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap the + button to add your first task.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.secondaryText,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
