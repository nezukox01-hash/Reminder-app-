import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';

class TaskItem {
  final String id;
  final String title;
  final bool isDone;

  TaskItem({
    required this.id,
    required this.title,
    required this.isDone,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    bool? isDone,
  }) {
    return TaskItem(
      id: id ?? this.id,
      title: title ?? this.title,
      isDone: isDone ?? this.isDone,
    );
  }

  String toStorage() {
    return "$id||$title||$isDone";
  }

  factory TaskItem.fromStorage(String value) {
    final parts = value.split("||");
    return TaskItem(
      id: parts[0],
      title: parts[1],
      isDone: parts[2] == 'true',
    );
  }
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  static const String storageKey = "ts_tasks";

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

    setState(() {});
  }

  Future<void> _saveTasks() async {
    final prefs = _prefs ?? await SharedPreferences.getInstance();
    _prefs = prefs;

    final data = _tasks.map((e) => e.toStorage()).toList();
    await prefs.setStringList(storageKey, data);
  }

  Future<void> _addTaskDialog({TaskItem? existing}) async {
    final controller =
        TextEditingController(text: existing != null ? existing.title : '');

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102643),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: Text(
            existing == null ? "Add Task" : "Edit Task",
            style: const TextStyle(color: Colors.white),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: "Enter task...",
              hintStyle: const TextStyle(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF1B2E49),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text("Cancel",
                  style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                final text = controller.text.trim();
                if (text.isEmpty) return;

                if (existing == null) {
                  _tasks.add(
                    TaskItem(
                      id: DateTime.now().millisecondsSinceEpoch.toString(),
                      title: text,
                      isDone: false,
                    ),
                  );
                } else {
                  final index =
                      _tasks.indexWhere((e) => e.id == existing.id);
                  if (index != -1) {
                    _tasks[index] = existing.copyWith(title: text);
                  }
                }

                await _saveTasks();
                setState(() {});
                Navigator.pop(dialogContext);
              },
              child: const Text("Save"),
            )
          ],
        );
      },
    );
  }

  void _toggleTask(TaskItem task) async {
    final index = _tasks.indexWhere((e) => e.id == task.id);
    if (index == -1) return;

    _tasks[index] = task.copyWith(isDone: !task.isDone);

    await _saveTasks();
    setState(() {});
  }

  void _deleteTask(TaskItem task) async {
    _tasks.removeWhere((e) => e.id == task.id);
    await _saveTasks();
    setState(() {});
  }

  int get _doneCount => _tasks.where((e) => e.isDone).length;
  int get _pendingCount => _tasks.where((e) => !e.isDone).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      floatingActionButton: FloatingActionButton(
        backgroundColor: const Color(0xFF4D88F8),
        onPressed: () => _addTaskDialog(),
        child: const Icon(Icons.add),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.arrow_back,
                          color: Colors.white),
                    ),
                    const Expanded(
                      child: Text(
                        "Daily Tasks",
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Stats
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    _statBox("Pending", _pendingCount, Colors.orange),
                    const SizedBox(width: 10),
                    _statBox("Done", _doneCount, Colors.green),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // List
              Expanded(
                child: _tasks.isEmpty
                    ? const Center(
                        child: Text(
                          "No tasks yet",
                          style: TextStyle(color: Colors.white70),
                        ),
                      )
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

  Widget _statBox(String title, int value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Column(
          children: [
            Text(
              title,
              style: const TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 6),
            Text(
              "$value",
              style: TextStyle(
                color: color,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _taskTile(TaskItem task) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: Colors.white.withOpacity(0.05),
        ),
        child: Row(
          children: [
            GestureDetector(
              onTap: () => _toggleTask(task),
              child: Icon(
                task.isDone
                    ? Icons.check_circle
                    : Icons.radio_button_unchecked,
                color: task.isDone ? Colors.green : Colors.white70,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.title,
                style: TextStyle(
                  color: Colors.white,
                  decoration:
                      task.isDone ? TextDecoration.lineThrough : null,
                ),
              ),
            ),
            PopupMenuButton(
              color: const Color(0xFF102643),
              onSelected: (value) {
                if (value == 'edit') _addTaskDialog(existing: task);
                if (value == 'delete') _deleteTask(task);
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                    value: 'edit',
                    child: Text("Edit",
                        style: TextStyle(color: Colors.white))),
                PopupMenuItem(
                    value: 'delete',
                    child: Text("Delete",
                        style: TextStyle(color: Colors.white))),
              ],
            )
          ],
        ),
      ),
    );
  }
}
