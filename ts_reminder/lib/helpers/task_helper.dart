import '../models/task_item.dart';

int timeToMinutes(String reminderTime) {
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

void sortTasks(List<TaskItem> tasks) {
  tasks.sort((a, b) {
    final aPending = !a.isDone && !a.isSkipped;
    final bPending = !b.isDone && !b.isSkipped;

    if (aPending != bPending) {
      return aPending ? -1 : 1;
    }

    if (a.isDone != b.isDone) {
      return a.isDone ? 1 : -1;
    }

    if (a.isSkipped != b.isSkipped) {
      return a.isSkipped ? 1 : -1;
    }

    final aTime = timeToMinutes(a.reminderTime);
    final bTime = timeToMinutes(b.reminderTime);

    if (aTime != bTime) {
      return aTime.compareTo(bTime);
    }

    return b.priority.compareTo(a.priority);
  });
}
