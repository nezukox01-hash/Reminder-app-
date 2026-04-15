class DailyReport {
  final String date;

  final int completedTasks;
  final int skippedTasks;
  final int pendingTasks;

  final int focusSessions;
  final int studyMinutes;

  final int rating; // 1-5
  final String note;

  DailyReport({
    required this.date,
    required this.completedTasks,
    required this.skippedTasks,
    required this.pendingTasks,
    required this.focusSessions,
    required this.studyMinutes,
    required this.rating,
    required this.note,
  });

  // 🔁 CopyWith (future use)
  DailyReport copyWith({
    String? date,
    int? completedTasks,
    int? skippedTasks,
    int? pendingTasks,
    int? focusSessions,
    int? studyMinutes,
    int? rating,
    String? note,
  }) {
    return DailyReport(
      date: date ?? this.date,
      completedTasks: completedTasks ?? this.completedTasks,
      skippedTasks: skippedTasks ?? this.skippedTasks,
      pendingTasks: pendingTasks ?? this.pendingTasks,
      focusSessions: focusSessions ?? this.focusSessions,
      studyMinutes: studyMinutes ?? this.studyMinutes,
      rating: rating ?? this.rating,
      note: note ?? this.note,
    );
  }

  // 💾 Save to storage
  String toStorage() {
    return [
      date,
      completedTasks.toString(),
      skippedTasks.toString(),
      pendingTasks.toString(),
      focusSessions.toString(),
      studyMinutes.toString(),
      rating.toString(),
      note,
    ].join('||');
  }

  // 📦 Load from storage
  factory DailyReport.fromStorage(String value) {
    final parts = value.split('||');

    return DailyReport(
      date: parts.isNotEmpty ? parts[0] : '',
      completedTasks: parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0,
      skippedTasks: parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0,
      pendingTasks: parts.length > 3 ? int.tryParse(parts[3]) ?? 0 : 0,
      focusSessions: parts.length > 4 ? int.tryParse(parts[4]) ?? 0 : 0,
      studyMinutes: parts.length > 5 ? int.tryParse(parts[5]) ?? 0 : 0,
      rating: parts.length > 6 ? int.tryParse(parts[6]) ?? 0 : 0,
      note: parts.length > 7 ? parts[7] : '',
    );
  }
}
