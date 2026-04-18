import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

class CloudSyncService {
  static final FirebaseFirestore _db = FirebaseFirestore.instance;

  // 👉 Upload local SharedPreferences data to Firestore
  static Future<void> uploadData(String uid) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // 1. Get current local data
      final List<String> tasksData = prefs.getStringList('ts_tasks_v5') ?? [];
      final String timerDate = prefs.getString('daily_timer_date') ?? '';
      final int focusSessions = prefs.getInt('daily_completed_focus_sessions') ?? 0;
      final int studySeconds = prefs.getInt('daily_study_seconds') ?? 0;
      
      // ✅ NEW: Get Daily Reports (History)
      final List<String> reportsData = prefs.getStringList('ts_daily_reports_v1') ?? [];

      // 2. Save to Firestore under the user's unique ID
      await _db.collection('users').doc(uid).set({
        'tasks': tasksData,
        'daily_timer_date': timerDate,
        'focus_sessions': focusSessions,
        'study_seconds': studySeconds,
        'reports': reportsData, // ✅ NEW: Save reports to Firebase
        'last_sync': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true)); // merge: true updates only changed fields

      print("Data successfully uploaded to Cloud!");
    } catch (e) {
      print("Upload Error: $e");
    }
  }

  // 👉 Download Firestore data to local SharedPreferences safely
  static Future<void> downloadData(String uid) async {
    try {
      final doc = await _db.collection('users').doc(uid).get();

      if (doc.exists && doc.data() != null) {
        final prefs = await SharedPreferences.getInstance();
        final data = doc.data()!;

        // 3. Save Cloud data to Local Storage (Safe Parsing)
        if (data.containsKey('tasks') && data['tasks'] != null) {
          List<String> cloudTasks = (data['tasks'] as List).map((e) => e.toString()).toList();
          await prefs.setStringList('ts_tasks_v5', cloudTasks);
        }
        
        if (data.containsKey('daily_timer_date') && data['daily_timer_date'] != null) {
          await prefs.setString('daily_timer_date', data['daily_timer_date'].toString());
        }
        
        if (data.containsKey('focus_sessions') && data['focus_sessions'] != null) {
          await prefs.setInt('daily_completed_focus_sessions', (data['focus_sessions'] as num).toInt());
        }
        
        if (data.containsKey('study_seconds') && data['study_seconds'] != null) {
          await prefs.setInt('daily_study_seconds', (data['study_seconds'] as num).toInt());
        }

        // ✅ NEW: Download Daily Reports (History) safely
        if (data.containsKey('reports') && data['reports'] != null) {
          List<String> cloudReports = (data['reports'] as List).map((e) => e.toString()).toList();
          await prefs.setStringList('ts_daily_reports_v1', cloudReports);
        }

        print("Data successfully downloaded from Cloud!");
      }
    } catch (e) {
      print("Download Error: $e");
    }
  }
}
