import 'package:flutter/material.dart';

class AssistantRobotCard extends StatelessWidget {
  final double taskProgress; // 0.0 - 1.0
  final double studyProgress; // 0.0 - 1.0
  final String greeting;
  final String message;
  final bool isSpeaking;
  final List<double> waveValues;

  const AssistantRobotCard({
    super.key,
    required this.taskProgress,
    required this.studyProgress,
    required this.greeting,
    required this.message,
    required this.isSpeaking,
    required this.waveValues,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: const LinearGradient(
          colors: [Color(0xFF16345A), Color(0xFF0D2442)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.25),
            blurRadius: 18,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: const [
              Icon(Icons.smart_toy_rounded, color: Colors.white, size: 30),
              SizedBox(width: 10),
              Text(
                'Personal Assistant',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          SizedBox(
            height: 235,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final double w = constraints.maxWidth;

                final double eyeSize = w < 340 ? 88 : 104;
                final double rawCenterWidth = w - (eyeSize * 2) - 44;
                final double centerWidth =
                    rawCenterWidth < 130 ? 130 : rawCenterWidth;

                final double greetingFontSize =
                    centerWidth < 170 ? 20 : 28;
                final double messageFontSize =
                    centerWidth < 170 ? 12 : 15;

                return Stack(
                  children: [
                    Positioned(
                      left: 6,
                      top: 8,
                      child: _ProgressEye(
                        progress: taskProgress,
                        color: const Color(0xFFFFD54F),
                        label: '${(taskProgress * 100).toInt()}%',
                        sub: 'Tasks',
                        size: eyeSize,
                      ),
                    ),
                    Positioned(
                      right: 6,
                      top: 8,
                      child: _ProgressEye(
                        progress: studyProgress,
                        color: const Color(0xFF7CFC00),
                        label: '${(studyProgress * 100).toInt()}%',
                        sub: 'Study',
                        size: eyeSize,
                      ),
                    ),
                    Positioned(
                      top: 30,
                      left: (w - centerWidth) / 2,
                      width: centerWidth,
                      child: Column(
                        children: [
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              greeting,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: greetingFontSize,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            message,
                            textAlign: TextAlign.center,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: messageFontSize,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),

                    // ✅ GREEN MARK AREA = Voice wave
                    Positioned(
                      bottom: 42,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: _CenterVoiceWave(
                          isSpeaking: isSpeaking,
                          waveValues: waveValues,
                        ),
                      ),
                    ),

                    // ✅ RED MARK AREA = Smile
                    const Positioned(
                      bottom: 0,
                      left: 0,
                      right: 0,
                      child: Center(
                        child: SizedBox(
                          width: 96,
                          height: 34,
                          child: CustomPaint(
                            painter: _SmilePainter(),
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressEye extends StatelessWidget {
  final double progress;
  final Color color;
  final String label;
  final String sub;
  final double size;

  const _ProgressEye({
    required this.progress,
    required this.color,
    required this.label,
    required this.sub,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: progress),
      duration: const Duration(milliseconds: 900),
      builder: (context, value, _) {
        return Container(
          height: size,
          width: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withOpacity(0.30),
                blurRadius: 24,
                spreadRadius: 2,
              ),
            ],
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                height: size,
                width: size,
                child: CircularProgressIndicator(
                  value: value,
                  strokeWidth: 9,
                  backgroundColor: Colors.white10,
                  valueColor: AlwaysStoppedAnimation(color),
                ),
              ),
              Container(
                height: size - 20,
                width: size - 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.black.withOpacity(0.18),
                ),
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: const TextStyle(
                      color: Colors.white70,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _CenterVoiceWave extends StatelessWidget {
  final bool isSpeaking;
  final List<double> waveValues;

  const _CenterVoiceWave({
    required this.isSpeaking,
    required this.waveValues,
  });

  @override
  Widget build(BuildContext context) {
    final bars = waveValues.isEmpty
        ? [10.0, 14.0, 11.0, 16.0, 12.0, 15.0, 10.0]
        : waveValues;

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars.length, (index) {
        final rawHeight = isSpeaking ? bars[index] : 8.0;
        final height = rawHeight.clamp(6.0, 24.0).toDouble();

        return AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 8,
          height: height,
          decoration: BoxDecoration(
            color: const Color(0xFF26E07F),
            borderRadius: BorderRadius.circular(10),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF26E07F).withOpacity(0.40),
                blurRadius: 8,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _SmilePainter extends CustomPainter {
  const _SmilePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black.withOpacity(0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.28)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 0.95,
        size.width * 0.82,
        size.height * 0.28,
      );

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
