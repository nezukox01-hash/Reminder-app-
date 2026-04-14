import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/audio_service.dart';
import '../utils/colors.dart';
import '../widgets/extra/skip_motivation_dialog.dart';
import '../widgets/extra/magic_five_bubble.dart';

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
  static const String storageKey = 'ts_tasks_v5';

  final List<ReminderTaskItem> _allTasks = [];
  Timer? _pollTimer;
  String _lastSnapshot = '';
  OverlayEntry? _magicFiveEntry;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    _pollTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _loadTasks(silentIfUnchanged: true);
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _magicFiveEntry?.remove();
    super.dispose();
  }

  Future<void> _loadTasks({bool silentIfUnchanged = false}) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getStringList(storageKey) ?? [];
    final snapshot = data.join('###');

    if (silentIfUnchanged && snapshot == _lastSnapshot) return;
    _lastSnapshot = snapshot;

    _allTasks
      ..clear()
      ..addAll(data.map(ReminderTaskItem.fromStorage));

    _sortTasks();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final data = _allTasks.map((e) => e.toStorage()).toList();
    await prefs.setStringList(storageKey, data);
    _lastSnapshot = data.join('###');
  }

  int _timeToMinutes(String reminderTime) {
    if (reminderTime.isEmpty) return 999999;

    try {
      final parts = reminderTime.split(':');
      if (parts.length != 2) return 999999;

      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);

      return hour * 60 + minute;
    } catch (_) {
      return 999999;
    }
  }

  void _sortTasks() {
    _allTasks.sort((a, b) {
      final aTime = _timeToMinutes(a.reminderTime);
      final bTime = _timeToMinutes(b.reminderTime);

      if (aTime != bTime) {
        return aTime.compareTo(bTime);
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

  Future<void> _applySkipTask(ReminderTaskItem task) async {
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

  Future<void> _showMotivationDialog(ReminderTaskItem task) async {
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
      await AudioService.playTaskSkipped();
    } else if (result == 'magic') {
      _showMagicFiveBubble();
    }
  }

  Future<void> _showHighPrioritySkipWarning(ReminderTaskItem task) async {
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
      await AudioService.playTaskSkipped();
    } else if (result == 'help') {
      await _showMotivationDialog(task);
    }
  }

  Future<void> _toggleDone(ReminderTaskItem task) async {
    final index = _allTasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    final int previousPendingCount =
        _allTasks.where((e) => !e.isDone && !e.isSkipped).length;

    final updatedTask = task.copyWith(
      isDone: !task.isDone,
      isSkipped: false,
    );

    _allTasks[index] = updatedTask;

    _sortTasks();
    await _saveTasks();

    if (mounted) {
      setState(() {});
    }

    final int currentPendingCount =
        _allTasks.where((e) => !e.isDone && !e.isSkipped).length;
    final int totalTasksCount = _allTasks.length;

    if (!task.isDone && updatedTask.isDone) {
      await AudioService.playTaskCompleted();

      if (previousPendingCount > 0 &&
          currentPendingCount == 0 &&
          totalTasksCount > 0) {
        await AudioService.playAllTasksCompleted();
      }
    }
  }

  Future<void> _skipTask(ReminderTaskItem task) async {
    if (task.priority == 3) {
      await _showHighPrioritySkipWarning(task);
      return;
    }

    await _applySkipTask(task);
    await AudioService.playTaskSkipped();
  }

  Future<void> _deleteTask(ReminderTaskItem task) async {
    _allTasks.removeWhere((e) => e.id == task.id);
    await _saveTasks();

    if (mounted) setState(() {});
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
                    IconButton(
                      onPressed: () => _loadTasks(),
                      icon: const Icon(
                        Icons.refresh_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Row(
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
                    const SizedBox(width: 12),
                    Expanded(
                      child: _StatBox(
                        title: 'Skipped',
                        value: '$_skippedCount',
                        color: Colors.redAccent,
                        icon: Icons.cancel_rounded,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _reminderTasks.isEmpty
                    ? const _EmptyReminderView()
                    : RefreshIndicator(
                        onRefresh: _loadTasks,
                        child: ListView.builder(
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
                              onDelete: () => _deleteTask(task),
                            );
                          },
                        ),
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
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.task,
    required this.priorityColor,
    required this.priorityLabel,
    required this.onToggleDone,
    required this.onSkip,
    required this.onDelete,
  });

  Widget _premiumCheckButton({
    required bool isDone,
    required bool isSkipped,
    required VoidCallback onTap,
  }) {
    Color borderColor;
    Color fillColor;
    IconData? icon;

    if (isDone) {
      borderColor = const Color(0xFF20C08A);
      fillColor = const Color(0xFF20C08A);
      icon = Icons.check;
    } else if (isSkipped) {
      borderColor = Colors.redAccent;
      fillColor = Colors.transparent;
      icon = Icons.close;
    } else {
      borderColor = Colors.orange;
      fillColor = Colors.transparent;
      icon = null;
    }

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        height: 28,
        width: 28,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fillColor,
          border: Border.all(color: borderColor, width: 2),
          boxShadow: [
            if (isDone)
              BoxShadow(
                color: borderColor.withOpacity(0.5),
                blurRadius: 10,
              ),
            if (isSkipped)
              BoxShadow(
                color: borderColor.withOpacity(0.4),
                blurRadius: 8,
              ),
          ],
        ),
        child: icon != null
            ? Icon(icon, size: 18, color: Colors.white)
            : null,
      ),
    );
  }

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
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: const LinearGradient(
            colors: [AppColors.surface2, AppColors.surface],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(
            color: task.isDone
                ? const Color(0xFF20C08A).withOpacity(0.3)
                : task.isSkipped
                    ? Colors.redAccent.withOpacity(0.3)
                    : Colors.transparent,
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _premiumCheckButton(
              isDone: task.isDone,
              isSkipped: task.isSkipped,
              onTap: onToggleDone,
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
              color: color.withOpacity(0.20),
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
            value,
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
