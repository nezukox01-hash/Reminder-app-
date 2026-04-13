class TaskItem {
  final String id;
  final String title;
  final String note;
  final bool isDone;
  final bool isSkipped;
  final String reminderTime;
  final int focusMinutes;
  final int priority; // 1 = low, 2 = medium, 3 = high

  TaskItem({
    required this.id,
    required this.title,
    required this.note,
    required this.isDone,
    required this.isSkipped,
    required this.reminderTime,
    required this.focusMinutes,
    required this.priority,
  });

  TaskItem copyWith({
    String? id,
    String? title,
    String? note,
    bool? isDone,
    bool? isSkipped,
    String? reminderTime,
    int? focusMinutes,
    int? priority,
  }) {
    return TaskItem(
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
      priority: parts.length > 7 ? int.tryParse(parts[7]) ?? 2 : 2,
    );
  }
}
