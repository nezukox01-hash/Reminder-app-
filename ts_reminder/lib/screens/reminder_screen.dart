import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';

class ReminderTaskItem {
  final String id;
  final String title;
  final String note;
  final bool isDone;
  final bool isSkipped;
  final String reminderTime;
  final int focusMinutes;
  final int priority;

  ReminderTaskItem({
    required this.id,
    required this.title,
    required this.note,
    required this.isDone,
    required this.isSkipped,
    required this.reminderTime,
    required this.focusMinutes,
    required this.priority,
  });

  ReminderTaskItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
    bool? isSkipped,
    String? reminderTime,
    int? focusMinutes,
    int? priority,
  }) {
    return ReminderTaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      isDone: isDone ?? this.isDone,
      isSkipped: isSkipped ?? this.isSkipped,
      reminderTime: reminderTime ?? this.reminderTime,
      focusMinutes: focusMinutes ?? this.focusMinutes,
      priority: priority ?? this.priority,
    );
  }

  factory ReminderTaskItem.fromStorage(String value) {
    final parts = value.split('||');
    return ReminderTaskItem(
      id: parts.isNotEmpty ? parts[0] : '',
      title: parts.length > 1 ? parts[1] : '',
      note: parts.length > 2 ? parts[2] : '',
      isDone: parts.length > 3 ? parts[3] == 'true' : false,
      isSkipped: parts.length > 4 ? parts[4] == 'true' : false,
      reminderTime: parts.length > 5 ? parts[5] : '',
      focusMinutes: parts.length > 6 ? int.tryParse(parts[6]) ?? 0 : 0,
      priority: parts.length > 7 ? int.tryParse(parts[7]) ?? 2 : 2,
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
      priority.toString(),
    ].join('||');
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  static const String storageKey = 'ts_tasks_v4';

  final List<ReminderTaskItem> _allTasks = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    _prefs = await SharedPreferences.getInstance();
    final data = _prefs?.getStringList(storageKey) ?? [];

    _allTasks
      ..clear()
      ..addAll(data.map(ReminderTaskItem.fromStorage));

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
      _allTasks.map((e) => e.toStorage()).toList(),
    );
  }

  void _sortTasks() {
    _allTasks.sort((a, b) {
      final aPending = !a.isDone && !a.isSkipped;
      final bPending = !b.isDone && !b.isSkipped;

      if (aPending != bPending) {
        return aPending ? -1 : 1;
      }

      return b.priority.compareTo(a.priority);
    });
  }

  List<ReminderTaskItem> get _reminderTasks =>
      _allTasks.where((e) => e.reminderTime.isNotEmpty).toList();

  int get _pendingCount =>
      _reminderTasks.where((e) => !e.isDone && !e.isSkipped).length;
  int get _doneCount => _reminderTasks.where((e) => e.isDone).length;
  int get _skippedCount => _reminderTasks.where((e) => e.isSkipped).length;

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

  Future<void> _toggleDone(ReminderTaskItem task) async {
    final index = _allTasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _allTasks[index] = task.copyWith(
      isDone: !task.isDone,
      isSkipped: false,
    );

    _sortTasks();
    await _saveTasks();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _skipTask(ReminderTaskItem task) async {
    final index = _allTasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _allTasks[index] = task.copyWith(
      isSkipped: true,
      isDone: false,
    );

    _sortTasks();
    await _saveTasks();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteTask(ReminderTaskItem task) async {
    _allTasks.removeWhere((e) => e.id == task.id);
    await _saveTasks();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _openEditDialog(ReminderTaskItem existing) async {
    final titleController = TextEditingController(text: existing.title);
    final noteController = TextEditingController(text: existing.note);
    final focusController = TextEditingController(
      text: existing.focusMinutes > 0 ? existing.focusMinutes.toString() : '',
    );

    int selectedPriority = existing.priority;
    TimeOfDay? selectedTime = _parseTime(existing.reminderTime);

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
              title: const Text(
                'Edit Reminder Task',
                style: TextStyle(
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
                        : selectedTime!.format(context);

                    if (title.isEmpty) return;

                    final index =
                        _allTasks.indexWhere((e) => e.id == existing.id);
                    if (index != -1) {
                      _allTasks[index] = existing.copyWith(
                        title: title,
                        note: note,
                        reminderTime: reminderString,
                        focusMinutes: focusMinutes,
                        priority: selectedPriority,
                      );
                    }

                    _sortTasks();
                    await _saveTasks();

                    if (mounted) {
                      setState(() {});
                    }

                    if (dialogContext.mounted) {
                      Navigator.pop(dialogContext);
                    }
                  },
                  child: const Text(
                    'Update',
                    style: TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 10),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        color: Colors.white,
                      ),
                    ),
                    const Expanded(
                      child: Text(
                        'Reminder',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 32,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    const Icon(
                      Icons.notifications_active_rounded,
                      color: Colors.white,
                      size: 28,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _StatBox(
                            title: 'Pending',
                            value: '$_pendingCount',
                            color: Colors.orange,
                            icon: Icons.access_time_filled_rounded,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: _StatBox(
                            title: 'Done',
                            value: '$_doneCount',
                            color: const Color(0xFF20C08A),
                            icon: Icons.check_circle_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _WideStatBox(
                      title: 'Skipped',
                      value: '$_skippedCount',
                      color: Colors.redAccent,
                      icon: Icons.cancel_rounded,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _reminderTasks.isEmpty
                    ? const _EmptyReminderView()
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _reminderTasks.length,
                        itemBuilder: (context, index) {
                          final task = _reminderTasks[index];
                          return _ReminderTile(
                            task: task,
                            priorityColor: _priorityColor(task.priority),
                            priorityLabel: _priorityLabel(task.priority),
                            onToggleDone: () => _toggleDone(task),
                            onSkip: () => _skipTask(task),
                            onEdit: () => _openEditDialog(task),
                            onDelete: () => _deleteTask(task),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReminderTile extends StatelessWidget {
  final ReminderTaskItem task;
  final Color priorityColor;
  final String priorityLabel;
  final VoidCallback onToggleDone;
  final VoidCallback onSkip;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.task,
    required this.priorityColor,
    required this.priorityLabel,
    required this.onToggleDone,
    required this.onSkip,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final titleStyle = TextStyle(
      color: task.isDone
          ? Colors.white54
          : task.isSkipped
              ? Colors.white60
              : Colors.white,
      fontSize: 17,
      fontWeight: FontWeight.w700,
      decoration:
          task.isDone || task.isSkipped ? TextDecoration.lineThrough : null,
      decorationColor:
          task.isDone ? const Color(0xFF20C08A) : Colors.black,
      decorationThickness: task.isDone ? 3 : 4,
    );

    final statusColor = task.isDone
        ? const Color(0xFF20C08A)
        : task.isSkipped
            ? Colors.redAccent
            : Colors.orange;

    final statusText = task.isDone
        ? 'Done'
        : task.isSkipped
            ? 'Skipped'
            : 'Pending';

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppColors.surface2, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            GestureDetector(
              onTap: onToggleDone,
              child: Icon(
                task.isDone
                    ? Icons.check_circle
                    : task.isSkipped
                        ? Icons.cancel
                        : Icons.radio_button_unchecked,
                color: task.isDone
                    ? const Color(0xFF20C08A)
                    : task.isSkipped
                        ? Colors.redAccent
                        : Colors.orange,
                size: 28,
              ),
            ),
            const SizedBox(width: 14),
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
                        color: AppColors.secondaryText,
                        fontSize: 14,
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _tag(
                        Icons.access_time_rounded,
                        task.reminderTime,
                        Colors.orange,
                      ),
                      _tag(
                        Icons.flag_rounded,
                        priorityLabel,
                        priorityColor,
                      ),
                      if (task.focusMinutes > 0)
                        _tag(
                          Icons.timer_rounded,
                          '${task.focusMinutes} min',
                          const Color(0xFF20C08A),
                        ),
                      _tag(
                        task.isDone
                            ? Icons.check_circle_rounded
                            : task.isSkipped
                                ? Icons.cancel_rounded
                                : Icons.notifications_active_rounded,
                        statusText,
                        statusColor,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            PopupMenuButton<String>(
              color: const Color(0xFF102643),
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              onSelected: (value) {
                if (value == 'done') onToggleDone();
                if (value == 'skip') onSkip();
                if (value == 'edit') onEdit();
                if (value == 'delete') onDelete();
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'done',
                  child: Text('Toggle Done',
                      style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'skip',
                  child: Text('Skip', style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text('Edit', style: TextStyle(color: Colors.white)),
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

class _StatBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _StatBox({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.20),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppColors.secondaryText,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: const TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WideStatBox extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;

  const _WideStatBox({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withOpacity(0.06),
      ),
      child: Row(
        children: [
          Container(
            height: 42,
            width: 42,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withOpacity(0.20),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              color: AppColors.secondaryText,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 20,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyReminderView extends StatelessWidget {
  const _EmptyReminderView();

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
                Icons.notifications_off_rounded,
                color: Colors.white70,
                size: 54,
              ),
              SizedBox(height: 16),
              Text(
                'No reminder tasks yet',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Add a task with a reminder time from the Tasks page.',
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
