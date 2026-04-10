class AudioService {
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

  static String getAssistantMessage(int unfinishedTasks) {
    if (unfinishedTasks <= 0) {
      return 'Well done sir, you did good today.';
    } else if (unfinishedTasks == 1) {
      return 'You have 1 unfinished task, sir.';
    } else {
      return 'You have $unfinishedTasks unfinished tasks, sir.';
    }
  }
}
