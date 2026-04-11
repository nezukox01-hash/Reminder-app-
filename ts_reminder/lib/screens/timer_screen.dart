import 'dart:async';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/colors.dart';

enum TimerPhase { focus, breakTime }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with WidgetsBindingObserver {
  static const String phaseKey = 'timer_phase';
  static const String runningKey = 'timer_running';
  static const String pausedKey = 'timer_paused';
  static const String endMillisKey = 'timer_end_millis';
  static const String remainingKey = 'timer_remaining_seconds';
  static const String focusMinutesKey = 'focus_minutes';
  static const String breakMinutesKey = 'break_minutes';
  static const String completedSessionsKey = 'completed_focus_sessions';
  static const String totalStudySecondsKey = 'total_study_seconds';

  SharedPreferences? _prefs;
  Timer? _ticker;

  TimerPhase _phase = TimerPhase.focus;
  bool _isRunning = false;
  bool _isPaused = false;

  int _focusMinutes = 25;
  int _breakMinutes = 5;

  int _remainingSeconds = 25 * 60;
  int _completedSessions = 0;
  int _totalStudySeconds = 0;

  int? _phaseEndMillis;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initialize();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _saveState();
    if (state == AppLifecycleState.resumed) {
      _restoreState();
    }
  }

  Future<void> _initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await _restoreState();
  }

  Future<void> _restoreState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    _phase = (prefs.getString(phaseKey) ?? 'focus') == 'focus'
        ? TimerPhase.focus
        : TimerPhase.breakTime;

    _isRunning = prefs.getBool(runningKey) ?? false;
    _isPaused = prefs.getBool(pausedKey) ?? false;
    _phaseEndMillis = prefs.getInt(endMillisKey);

    _focusMinutes = prefs.getInt(focusMinutesKey) ?? 25;
    _breakMinutes = prefs.getInt(breakMinutesKey) ?? 5;
    _completedSessions = prefs.getInt(completedSessionsKey) ?? 0;
    _totalStudySeconds = prefs.getInt(totalStudySecondsKey) ?? 0;

    _remainingSeconds = prefs.getInt(remainingKey) ??
        (_phase == TimerPhase.focus ? _focusMinutes * 60 : _breakMinutes * 60);

    if (_isRunning && !_isPaused && _phaseEndMillis != null) {
      _catchUp();
      _startTicker();
    }

    if (!_isRunning && !_isPaused) {
      _remainingSeconds = _phase == TimerPhase.focus
          ? _focusMinutes * 60
          : _breakMinutes * 60;
    }

    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _saveState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString(
      phaseKey,
      _phase == TimerPhase.focus ? 'focus' : 'break',
    );
    await prefs.setBool(runningKey, _isRunning);
    await prefs.setBool(pausedKey, _isPaused);
    await prefs.setInt(remainingKey, _remainingSeconds);
    await prefs.setInt(focusMinutesKey, _focusMinutes);
    await prefs.setInt(breakMinutesKey, _breakMinutes);
    await prefs.setInt(completedSessionsKey, _completedSessions);
    await prefs.setInt(totalStudySecondsKey, _totalStudySeconds);

    if (_phaseEndMillis != null) {
      await prefs.setInt(endMillisKey, _phaseEndMillis!);
    } else {
      await prefs.remove(endMillisKey);
    }
  }

  int get _phaseTotalSeconds {
    return _phase == TimerPhase.focus
        ? _focusMinutes * 60
        : _breakMinutes * 60;
  }

  void _catchUp() {
    if (_phaseEndMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    int end = _phaseEndMillis!;

    while (now >= end) {
      if (_phase == TimerPhase.focus) {
        _completedSessions += 1;
        _totalStudySeconds += _focusMinutes * 60;

        // focus ended -> auto start break
        _phase = TimerPhase.breakTime;
        end += _breakMinutes * 60 * 1000;
      } else {
        // break ended -> stop and return to focus ready state
        _phase = TimerPhase.focus;
        _isRunning = false;
        _isPaused = false;
        _phaseEndMillis = null;
        _remainingSeconds = _focusMinutes * 60;
        return;
      }
    }

    _phaseEndMillis = end;
    _remainingSeconds = ((end - now) / 1000).ceil();
    if (_remainingSeconds < 0) _remainingSeconds = 0;
  }

  void _startTicker() {
    _ticker?.cancel();

    _ticker = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isRunning || _isPaused || _phaseEndMillis == null) return;

      final now = DateTime.now().millisecondsSinceEpoch;
      final remain = ((_phaseEndMillis! - now) / 1000).ceil();

      if (remain <= 0) {
        _goToNextPhase();
      } else {
        if (mounted) {
          setState(() {
            _remainingSeconds = remain;
          });
        }
      }

      await _saveState();
    });
  }

  void _startOrResumeTimer() {
    if (_isRunning && !_isPaused) return;

    if (_isRunning && _isPaused) {
      _isPaused = false;
    } else {
      _isRunning = true;
      _isPaused = false;
    }

    _phaseEndMillis =
        DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

    _startTicker();

    if (mounted) {
      setState(() {});
    }

    _saveState();
  }

  void _pauseTimer() {
    if (!_isRunning || _isPaused || _phaseEndMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _remainingSeconds = ((_phaseEndMillis! - now) / 1000).ceil();
    if (_remainingSeconds < 0) _remainingSeconds = 0;

    _isPaused = true;
    _ticker?.cancel();

    if (mounted) {
      setState(() {});
    }

    _saveState();
  }

  void _resetTimer() {
    _ticker?.cancel();

    _isRunning = false;
    _isPaused = false;
    _phase = TimerPhase.focus;
    _phaseEndMillis = null;
    _remainingSeconds = _focusMinutes * 60;

    if (mounted) {
      setState(() {});
    }

    _saveState();
  }

  void _goToNextPhase() {
    _ticker?.cancel();

    if (_phase == TimerPhase.focus) {
      _completedSessions += 1;
      _totalStudySeconds += _focusMinutes * 60;

      // Auto start break
      _phase = TimerPhase.breakTime;
      _remainingSeconds = _breakMinutes * 60;
      _isRunning = true;
      _isPaused = false;
      _phaseEndMillis =
          DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

      if (mounted) {
        setState(() {});
      }

      _startTicker();
    } else {
      // Break end -> STOP and return to focus ready state
      _phase = TimerPhase.focus;
      _remainingSeconds = _focusMinutes * 60;
      _isRunning = false;
      _isPaused = false;
      _phaseEndMillis = null;

      if (mounted) {
        setState(() {});
      }
    }

    _saveState();
  }

  Future<void> _openSettingsDialog() async {
    final focusController =
        TextEditingController(text: _focusMinutes.toString());
    final breakController =
        TextEditingController(text: _breakMinutes.toString());

    await showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: const Color(0xFF102643),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          title: const Text(
            'Timer Settings',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildField(
                label: 'Focus Minutes',
                controller: focusController,
              ),
              const SizedBox(height: 14),
              _buildField(
                label: 'Break Minutes',
                controller: breakController,
              ),
            ],
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
                final newFocus =
                    int.tryParse(focusController.text.trim()) ?? 25;
                final newBreak =
                    int.tryParse(breakController.text.trim()) ?? 5;

                _ticker?.cancel();

                _focusMinutes = newFocus <= 0 ? 25 : newFocus;
                _breakMinutes = newBreak <= 0 ? 5 : newBreak;

                _isRunning = false;
                _isPaused = false;
                _phase = TimerPhase.focus;
                _phaseEndMillis = null;
                _remainingSeconds = _focusMinutes * 60;

                if (mounted) {
                  setState(() {});
                }

                await _saveState();

                if (dialogContext.mounted) {
                  Navigator.pop(dialogContext);
                }
              },
              child: const Text(
                'Save',
                style: TextStyle(color: Colors.white),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildField({
    required String label,
    required TextEditingController controller,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            color: Colors.white70,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          style: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF1B2E49),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(18),
              borderSide: BorderSide.none,
            ),
          ),
        ),
      ],
    );
  }

  String _formatTime(int seconds) {
    final mins = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final progress =
        _phaseTotalSeconds == 0 ? 0.0 : _remainingSeconds / _phaseTotalSeconds;

    final phaseColor = _phase == TimerPhase.focus
        ? const Color(0xFF20C08A)
        : const Color(0xFFFFB347);

    final phaseLabel = _phase == TimerPhase.focus ? 'Focus' : 'Break';

    final pauseActive = _isPaused;
    final startActive = _isRunning && !_isPaused;
    final resetActive = false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Timer',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 34,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: _openSettingsDialog,
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(18, 24, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [AppColors.surface2, AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 300,
                        width: 300,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: progress,
                            color: phaseColor,
                          ),
                          child: Center(
                            child: Container(
                              height: 205,
                              width: 205,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    phaseColor.withOpacity(0.18),
                                    AppColors.background,
                                  ],
                                ),
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    _formatTime(_remainingSeconds),
                                    style: const TextStyle(
                                      color: AppColors.primaryText,
                                      fontSize: 58,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 22,
                                      vertical: 10,
                                    ),
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(24),
                                      color: Colors.black.withOpacity(0.18),
                                    ),
                                    child: Text(
                                      phaseLabel,
                                      style: const TextStyle(
                                        color: AppColors.primaryText,
                                        fontSize: 20,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(22),
                          color: Colors.white.withOpacity(0.08),
                        ),
                        child: Column(
                          children: [
                            Text(
                              'Focus $_focusMinutes min  →  Break $_breakMinutes min',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                color: AppColors.primaryText,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Session ${_completedSessions + 1}',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 22),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              color: pauseActive
                                  ? Colors.green
                                  : const Color(0xFFE65C73),
                              icon: Icons.pause_rounded,
                              label: 'Pause',
                              onTap: _pauseTimer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _ActionButton(
                              color: startActive
                                  ? Colors.green
                                  : const Color(0xFFE65C73),
                              icon: Icons.play_arrow_rounded,
                              label: _isPaused ? 'Resume' : 'Start',
                              onTap: _startOrResumeTimer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ActionButton(
                              color: resetActive
                                  ? Colors.green
                                  : const Color(0xFFE65C73),
                              icon: Icons.refresh_rounded,
                              label: 'Reset',
                              onTap: _resetTimer,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 22),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(24),
                    gradient: const LinearGradient(
                      colors: [AppColors.surface2, AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Timer Summary',
                        style: TextStyle(
                          color: AppColors.primaryText,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 18),
                      _SummaryItem(
                        icon: Icons.swap_horiz_rounded,
                        label: 'Completed Focus Sessions',
                        value: '$_completedSessions',
                      ),
                      const SizedBox(height: 16),
                      _SummaryItem(
                        icon: Icons.timer_outlined,
                        label: 'Total Study Time',
                        value: '${(_totalStudySeconds ~/ 60)}m',
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ActionButton({
    required this.color,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeInOut,
      child: InkWell(
        borderRadius: BorderRadius.circular(22),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            color: color,
          ),
          child: Column(
            children: [
              Icon(icon, color: Colors.white, size: 34),
              const SizedBox(height: 8),
              Text(
                label,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _SummaryItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: const Color(0xFF42B7FF), size: 28),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: AppColors.primaryText,
              fontSize: 17,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Text(
          value,
          style: const TextStyle(
            color: AppColors.primaryText,
            fontSize: 17,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  _RingPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 22.0;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) - stroke;

    final basePaint = Paint()
      ..color = Colors.white.withOpacity(0.08)
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);

    final sweepAngle = 6.28318530718 * progress;
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -1.5708,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}
