import 'package:flutter/material.dart';

class AssistantRobotCard extends StatelessWidget {
  final double taskProgress; // 0.0 - 1.0
  final double studyProgress; // 0.0 - 1.0

  final String greeting;
  final String message;

  const AssistantRobotCard({
    super.key,
    required this.taskProgress,
    required this.studyProgress,
    required this.greeting,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          colors: [Color(0xFF1B3558), Color(0xFF0E223D)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: const [
              Icon(Icons.smart_toy_rounded, color: Colors.white, size: 28),
              SizedBox(width: 10),
              Text(
                'Personal Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // 👁️ Eyes Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ProgressEye(
                progress: taskProgress,
                color: Colors.amber,
                label: '${(taskProgress * 100).toInt()}%',
                sub: 'Tasks',
              ),
              _ProgressEye(
                progress: studyProgress,
                color: Colors.green,
                label: '${(studyProgress * 100).toInt()}%',
                sub: 'Study',
              ),
            ],
          ),

          const SizedBox(height: 18),

          Text(
            greeting,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 6),

          Text(
            message,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }
}

// ✅ Added _ProgressEye Widget here
class _ProgressEye extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  final String sub;

  const _ProgressEye({
    required this.progress,
    required this.color,
    required this.label,
    required this.sub,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 800),
      builder: (context, value, _) {
        return SizedBox(
          height: 90,
          width: 90,
          child: Stack(
            alignment: Alignment.center,
            children: [
              CircularProgressIndicator(
                value: value,
                strokeWidth: 8,
                backgroundColor: Colors.white10,
                valueColor: AlwaysStoppedAnimation(color),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: Colors.white54,
                      fontSize: 10,
                    ),
                  ),
                ],
              )
            ],
          ),
        );
      },
    );
  }
}
