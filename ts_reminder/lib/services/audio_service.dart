import 'package:just_audio/just_audio.dart';

class AudioService {
  static final AudioPlayer _player = AudioPlayer();

  static String getGreetingByTime() {
    final int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'Good Morning Sir';
    } else if (hour >= 12 && hour < 17) {
      return 'Good Afternoon Sir';
    } else if (hour >= 17 && hour < 21) {
      return 'Good Evening Sir';
    } else {
      return 'Good Night Sir';
    }
  }

  static String getAssistantMessage(int unfinishedTasks, int totalTasks) {
    if (totalTasks == 0) {
      return 'No tasks added yet, sir.';
    } else if (unfinishedTasks == 0) {
      return 'All tasks completed, sir.';
    } else if (unfinishedTasks == 1) {
      return 'You have 1 unfinished task, sir.';
    } else {
      return 'You have $unfinishedTasks unfinished tasks, sir.';
    }
  }

  static String _greetingFileByTime() {
    final int hour = DateTime.now().hour;

    if (hour >= 5 && hour < 12) {
      return 'assets/audio/assistant/good_morning.mp3';
    } else if (hour >= 12 && hour < 17) {
      return 'assets/audio/assistant/good_afternoon.mp3';
    } else if (hour >= 17 && hour < 21) {
      return 'assets/audio/assistant/good_evening.mp3';
    } else {
      return 'assets/audio/assistant/good_night.mp3';
    }
  }

  static String _taskFileByCount(int unfinishedTasks, int totalTasks) {
    if (totalTasks == 0) {
      return '';
    }

    if (unfinishedTasks == 0) {
      return 'assets/audio/assistant/all_task_completed.mp3';
    }

    if (unfinishedTasks == 1) {
      return 'assets/audio/assistant/one_task.mp3';
    }

    return 'assets/audio/assistant/multiple_tasks.mp3';
  }

  static Future<void> playHomeAssistantSequence(
    int unfinishedTasks,
    int totalTasks,
  ) async {
    try {
      await stop();

      final List<AudioSource> sources = [
        AudioSource.asset(_greetingFileByTime()),
      ];

      final String taskFile = _taskFileByCount(unfinishedTasks, totalTasks);
      if (taskFile.isNotEmpty) {
        sources.add(AudioSource.asset(taskFile));
      }

      final playlist = ConcatenatingAudioSource(children: sources);

      await _player.setAudioSource(playlist);
      await _player.play();

      await _player.playerStateStream.firstWhere(
        (state) =>
            state.processingState == ProcessingState.completed ||
            !state.playing,
      );
    } catch (_) {}
  }

  static Future<void> playAllTasksCompleted() async {
    try {
      await stop();
      await _player.setAudioSource(
        AudioSource.asset('assets/audio/assistant/all_task_completed.mp3'),
      );
      await _player.play();
      await _player.playerStateStream.firstWhere(
        (state) =>
            state.processingState == ProcessingState.completed ||
            !state.playing,
      );
    } catch (_) {}
  }

  static Future<void> stop() async {
    try {
      await _player.stop();
    } catch (_) {}
  }

  static Future<void> disposePlayer() async {
    try {
      await _player.dispose();
    } catch (_) {}
  }
}
