import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';

class TaskItem {
  final String id;
  final String title;
  final String note;
  final bool isDone;
  final bool isSkipped;
  final String reminderTime;
  final int focusMinutes;

  TaskItem({
    required this.id,
    required this.title,
    required this.note,
    required this.isDone,
    required this.isSkipped,
    required this.reminderTime,
    required this.focusMinutes,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
    bool? isSkipped,
    String? reminderTime,
    int? focusMinutes,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
      isSkipped: isSkipped ?? this.isSkipped,
      reminderTime: reminderTime ?? this.reminderTime,
      focusMinutes: focusMinutes ?? this.focusMinutes,
    );
  }

  String toStorage() {
    return [
      id,
      title,
      note,
      isDone.toString(),
      isSkipped.toString(),
      reminderTime,
      focusMinutes.toString(),
    ].join('||');
  }

  factory TaskItem.fromStorage(String value) {
    final parts = value.split('||');
    return TaskItem(
      id: parts.isNotEmpty ? parts[0] : '',
      title: parts.length > 1 ? parts[1] : '',
      note: parts.length > 2 ? parts[2] : '',
      isDone: parts.length > 3 ? parts[3] == 'true' : false,
      isSkipped: parts.length > 4 ? parts[4] == 'true' : false,
      reminderTime: parts.length > 5 ? parts[5] : '',
      focusMinutes: parts.length > 6 ? int.tryParse(parts[6]) ?? 0 : 0,
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String storageKey = 'ts_tasks_v3';

  final List<TaskItem> _tasks = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final data = _prefs?.getStringList(storageKey) ?? [];

    _tasks
      ..clear()
      ..addAll(data.map(TaskItem.fromStorage));

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

  int get _doneCount => _tasks.where((e) => e.isDone).length;
  int get _pendingCount =>
      _tasks.where((e) => !e.isDone && !e.isSkipped).length;

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
                            const Icon(Icons.access_time_rounded,
                                color: Colors.white),
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
                        : selectedTime!.format(context);

                    if (title.isEmpty) return;

                    if (existing == null) {
                      _tasks.add(
                        TaskItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          note: note,
                          isDone: false,
                          isSkipped: false,
                          reminderTime: reminderString,
                          focusMinutes: focusMinutes,
                        ),
                      );
                    } else {
                      final index =
                          _tasks.indexWhere((e) => e.id == existing.id);
                      if (index != -1) {
                        _tasks[index] = existing.copyWith(
                          title: title,
                          note: note,
                          reminderTime: reminderString,
                          focusMinutes: focusMinutes,
                        );
                      }
                    }

                    await _saveTasks();
                    if (mounted) {
                      setState(() {});
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
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

  TimeOfDay? _parseTime(String value) {
    try {
      final parts = value.split(' ');
      if (parts.length != 2) return null;
      final hm = parts[0].split(':');
      if (hm.length != 2) return null;

      int hour = int.parse(hm[0]);
      final minute = int.parse(hm[1]);
      final suffix = parts[1].toUpperCase();

      if (suffix == 'PM' && hour != 12) hour += 12;
      if (suffix == 'AM' && hour == 12) hour = 0;

      return TimeOfDay(hour: hour, minute: minute);
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleTask(TaskItem task) async {
    final index = _tasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(
      isDone: !task.isDone,
      isSkipped: false,
    );

    await _saveTasks();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _skipTask(TaskItem task) async {
    final index = _tasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(
      isSkipped: true,
      isDone: false,
    );

    await _saveTasks();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteTask(TaskItem task) async {
    _tasks.removeWhere((e) => e.id == task.id);
    await _saveTasks();
    if (mounted) {
      setState(() {});
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
                    IconButton(
                      onPressed: () => _openTaskDialog(),
                      icon: const Icon(Icons.add_task, color: Colors.white),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _statBox(
                      'Pending',
                      _pendingCount,
                      Colors.orange,
                      Icons.access_time_filled_rounded,
                    ),
                    const SizedBox(width: 10),
                    _statBox(
                      'Done',
                      _doneCount,
                      Colors.green,
                      Icons.check_circle_rounded,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
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
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
          ],
        ),
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
      decorationColor: task.isDone
          ? const Color(0xFF20C08A)
          : Colors.black,
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
            PopupMenuButton(
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
