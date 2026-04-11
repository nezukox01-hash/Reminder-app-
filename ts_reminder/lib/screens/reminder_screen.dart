import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';

class ReminderItem {
  final String id;
  final String title;
  final String note;
  final TimeOfDay time;
  final bool isDone;

  ReminderItem({
    required this.id,
    required this.title,
    required this.note,
    required this.time,
    required this.isDone,
  });

  ReminderItem copyWith({
    String? id,
    String? title,
    String? note,
    TimeOfDay? time,
    bool? isDone,
  }) {
    return ReminderItem(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      time: time ?? this.time,
      isDone: isDone ?? this.isDone,
    );
  }

  String toStorageString() {
    return [
      id,
      title,
      note,
      time.hour.toString(),
      time.minute.toString(),
      isDone.toString(),
    ].join('||');
  }

  factory ReminderItem.fromStorageString(String value) {
    final parts = value.split('||');
    return ReminderItem(
      id: parts[0],
      title: parts[1],
      note: parts[2],
      time: TimeOfDay(
        hour: int.tryParse(parts[3]) ?? 0,
        minute: int.tryParse(parts[4]) ?? 0,
      ),
      isDone: parts.length > 5 ? parts[5] == 'true' : false,
    );
  }
}

class ReminderScreen extends StatefulWidget {
  const ReminderScreen({super.key});

  @override
  State<ReminderScreen> createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  static const String _storageKey = 'ts_reminders_list';

  final List<ReminderItem> _reminders = [];
  SharedPreferences? _prefs;

  @override
  void initState() {
    super.initState();
    _loadReminders();
  }

  Future<void> _loadReminders() async {
    _prefs = await SharedPreferences.getInstance();
    final stored = _prefs?.getStringList(_storageKey) ?? [];

    _reminders
      ..clear()
      ..addAll(stored.map(ReminderItem.fromStorageString));

    _sortReminders();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveReminders() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;
    final stored = _reminders.map((e) => e.toStorageString()).toList();
    await prefs.setStringList(_storageKey, stored);
  }

  void _sortReminders() {
    _reminders.sort((a, b) {
      final aMinutes = a.time.hour * 60 + a.time.minute;
      final bMinutes = b.time.hour * 60 + b.time.minute;
      return aMinutes.compareTo(bMinutes);
    });
  }

  Future<void> _openAddReminderDialog({ReminderItem? existing}) async {
    final titleController =
        TextEditingController(text: existing != null ? existing.title : '');
    final noteController =
        TextEditingController(text: existing != null ? existing.note : '');

    TimeOfDay selectedTime = existing?.time ?? TimeOfDay.now();

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
                existing == null ? 'Add Reminder' : 'Edit Reminder',
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
                      label: 'Title',
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
                          initialTime: selectedTime,
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
                              selectedTime.format(context),
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
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(dialogContext);
                  },
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

                    if (title.isEmpty) return;

                    if (existing == null) {
                      _reminders.add(
                        ReminderItem(
                          id: DateTime.now().millisecondsSinceEpoch.toString(),
                          title: title,
                          note: note,
                          time: selectedTime,
                          isDone: false,
                        ),
                      );
                    } else {
                      final index =
                          _reminders.indexWhere((e) => e.id == existing.id);
                      if (index != -1) {
                        _reminders[index] = existing.copyWith(
                          title: title,
                          note: note,
                          time: selectedTime,
                        );
                      }
                    }

                    _sortReminders();
                    await _saveReminders();

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
  }) {
    return TextField(
      controller: controller,
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

  Future<void> _toggleDone(ReminderItem item) async {
    final index = _reminders.indexWhere((e) => e.id == item.id);
    if (index == -1) return;

    _reminders[index] = item.copyWith(isDone: !item.isDone);
    await _saveReminders();

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _deleteReminder(ReminderItem item) async {
    _reminders.removeWhere((e) => e.id == item.id);
    await _saveReminders();

    if (mounted) {
      setState(() {});
    }
  }

  int get _pendingCount => _reminders.where((e) => !e.isDone).length;
  int get _doneCount => _reminders.where((e) => e.isDone).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4D88F8),
        onPressed: () => _openAddReminderDialog(),
        child: const Icon(Icons.add, color: Colors.white),
      ),
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
                      onPressed: () => _openAddReminderDialog(),
                      icon: const Icon(
                        Icons.notifications_active_rounded,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 14),
                child: Container(
                  width: double.infinity,
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
                    children: [
                      Expanded(
                        child: _StatBox(
                          title: 'Pending',
                          value: '$_pendingCount',
                          color: const Color(0xFFFFB347),
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
                ),
              ),
              Expanded(
                child: _reminders.isEmpty
                    ? const _EmptyReminderView()
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                        itemCount: _reminders.length,
                        separatorBuilder: (_, __) =>
                            const SizedBox(height: 14),
                        itemBuilder: (context, index) {
                          final item = _reminders[index];
                          return _ReminderTile(
                            item: item,
                            onToggleDone: () => _toggleDone(item),
                            onEdit: () =>
                                _openAddReminderDialog(existing: item),
                            onDelete: () => _deleteReminder(item),
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
  final ReminderItem item;
  final VoidCallback onToggleDone;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _ReminderTile({
    required this.item,
    required this.onToggleDone,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final timeText = item.time.format(context);

    return Container(
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
            child: Container(
              height: 28,
              width: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: item.isDone
                    ? const Color(0xFF20C08A)
                    : Colors.transparent,
                border: Border.all(
                  color: item.isDone
                      ? const Color(0xFF20C08A)
                      : Colors.white70,
                  width: 2,
                ),
              ),
              child: item.isDone
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: TextStyle(
                    color: AppColors.primaryText,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    decoration:
                        item.isDone ? TextDecoration.lineThrough : null,
                    decorationColor: Colors.white70,
                  ),
                ),
                if (item.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    item.note,
                    style: TextStyle(
                      color: AppColors.secondaryText,
                      fontSize: 14,
                      decoration:
                          item.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: Colors.white54,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: Colors.white.withOpacity(0.08),
                  ),
                  child: Text(
                    timeText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
          PopupMenuButton<String>(
            color: const Color(0xFF102643),
            icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
            onSelected: (value) {
              if (value == 'edit') onEdit();
              if (value == 'delete') onDelete();
            },
            itemBuilder: (context) => const [
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
                'No reminders yet',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Tap the + button to add your first reminder.',
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
