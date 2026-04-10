import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../utils/colors.dart';

enum TimerPhase { focus, breakTime }

class TimerScreen extends StatefulWidget {
  const TimerScreen({super.key});

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with WidgetsBindingObserver {
  static const String _phaseKey = 'timer_phase';
  static const String _runningKey = 'timer_running';
  static const String _pausedKey = 'timer_paused';
  static const String _endMillisKey = 'timer_end_millis';
  static const String _remainingKey = 'timer_remaining_seconds';
  static const String _focusMinutesKey = 'timer_focus_minutes';
  static const String _breakMinutesKey = 'timer_break_minutes';
  static const String _completedSessionsKey = 'timer_completed_sessions';
  static const String _totalStudySecondsKey = 'timer_total_study_seconds';

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  final AudioPlayer _player = AudioPlayer();

  SharedPreferences? _prefs;
  Timer? _ticker;

  TimerPhase _phase = TimerPhase.focus;
  bool _isRunning = false;
  bool _isPaused = false;

  int _focusMinutes = 25;
  int _breakMinutes = 5;

  int _remainingSeconds = 25 * 60;
  int _completedFocusSessions = 0;
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
    _player.dispose();
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
    tz.initializeTimeZones();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const initSettings = InitializationSettings(android: androidInit);
    await _notifications.initialize(initSettings);

    _prefs = await SharedPreferences.getInstance();
    await _restoreState();
  }

  Future<void> _restoreState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    _phase = (prefs.getString(_phaseKey) ?? 'focus') == 'focus'
        ? TimerPhase.focus
        : TimerPhase.breakTime;

    _isRunning = prefs.getBool(_runningKey) ?? false;
    _isPaused = prefs.getBool(_pausedKey) ?? false;
    _phaseEndMillis = prefs.getInt(_endMillisKey);
    _focusMinutes = prefs.getInt(_focusMinutesKey) ?? 25;
    _breakMinutes = prefs.getInt(_breakMinutesKey) ?? 5;
    _completedFocusSessions = prefs.getInt(_completedSessionsKey) ?? 0;
    _totalStudySeconds = prefs.getInt(_totalStudySecondsKey) ?? 0;

    _remainingSeconds = prefs.getInt(_remainingKey) ??
        (_phase == TimerPhase.focus ? _focusMinutes * 60 : _breakMinutes * 60);

    if (_isRunning && !_isPaused && _phaseEndMillis != null) {
      _catchUpWithCurrentTime();
      _startTicker();
    }

    if (!_isRunning) {
      _remainingSeconds = _phase == TimerPhase.focus
          ? _focusMinutes * 60
          : _breakMinutes * 60;
    }

    if (mounted) setState(() {});
  }

  Future<void> _saveState() async {
    final prefs = _prefs;
    if (prefs == null) return;

    await prefs.setString(
      _phaseKey,
      _phase == TimerPhase.focus ? 'focus' : 'break',
    );
    await prefs.setBool(_runningKey, _isRunning);
    await prefs.setBool(_pausedKey, _isPaused);
    if (_phaseEndMillis != null) {
      await prefs.setInt(_endMillisKey, _phaseEndMillis!);
    }
    await prefs.setInt(_remainingKey, _remainingSeconds);
    await prefs.setInt(_focusMinutesKey, _focusMinutes);
    await prefs.setInt(_breakMinutesKey, _breakMinutes);
    await prefs.setInt(_completedSessionsKey, _completedFocusSessions);
    await prefs.setInt(_totalStudySecondsKey, _totalStudySeconds);
  }

  int get _currentPhaseTotalSeconds {
    return _phase == TimerPhase.focus
        ? _focusMinutes * 60
        : _breakMinutes * 60;
  }

  void _catchUpWithCurrentTime() {
    if (_phaseEndMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    int end = _phaseEndMillis!;

    while (now >= end) {
      if (_phase == TimerPhase.focus) {
        _completedFocusSessions += 1;
        _totalStudySeconds += _focusMinutes * 60;
        _phase = TimerPhase.breakTime;
        end += _breakMinutes * 60 * 1000;
      } else {
        _phase = TimerPhase.focus;
        end += _focusMinutes * 60 * 1000;
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
        await _advancePhase();
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

  Future<void> _startTimer() async {
    if (_isRunning && _isPaused) {
      await _resumeTimer();
      return;
    }

    if (_isRunning) return;

    _isRunning = true;
    _isPaused = false;
    _phaseEndMillis =
        DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

    await _schedulePhaseNotification();
    _startTicker();
    await _playVoiceForStart();
    await _saveState();

    if (mounted) setState(() {});
  }

  Future<void> _pauseTimer() async {
    if (!_isRunning || _isPaused || _phaseEndMillis == null) return;

    final now = DateTime.now().millisecondsSinceEpoch;
    _remainingSeconds = ((_phaseEndMillis! - now) / 1000).ceil();
    if (_remainingSeconds < 0) _remainingSeconds = 0;

    _isPaused = true;
    _ticker?.cancel();
    await _notifications.cancel(100);
    await _saveState();

    if (mounted) setState(() {});
  }

  Future<void> _resumeTimer() async {
    if (!_isRunning || !_isPaused) return;

    _isPaused = false;
    _phaseEndMillis =
        DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

    await _schedulePhaseNotification();
    _startTicker();
    await _saveState();

    if (mounted) setState(() {});
  }

  Future<void> _resetTimer() async {
    _ticker?.cancel();
    await _notifications.cancel(100);

    _isRunning = false;
    _isPaused = false;
    _phase = TimerPhase.focus;
    _remainingSeconds = _focusMinutes * 60;
    _phaseEndMillis = null;

    await _saveState();

    if (mounted) setState(() {});
  }

  Future<void> _advancePhase() async {
    final wasFocus = _phase == TimerPhase.focus;

    if (wasFocus) {
      _completedFocusSessions += 1;
      _totalStudySeconds += _focusMinutes * 60;
      await _playAudio('assets/audio/assistant/focus_session_complete_sir.mp3');
      _phase = TimerPhase.breakTime;
      _remainingSeconds = _breakMinutes * 60;
      await _playAudio('assets/audio/assistant/break_time_sir.mp3');
    } else {
      await _playAudio(
        'assets/audio/assistant/break_is_over_back_to_work_sir.mp3',
      );
      _phase = TimerPhase.focus;
      _remainingSeconds = _focusMinutes * 60;
    }

    _isRunning = true;
    _isPaused = false;
    _phaseEndMillis =
        DateTime.now().millisecondsSinceEpoch + (_remainingSeconds * 1000);

    await _schedulePhaseNotification();
    await _saveState();

    if (mounted) setState(() {});
  }

  Future<void> _schedulePhaseNotification() async {
    if (_phaseEndMillis == null) return;

    await _notifications.cancel(100);

    const androidDetails = AndroidNotificationDetails(
      'timer_channel',
      'Timer Alerts',
      channelDescription: 'Timer phase completion alerts',
      importance: Importance.max,
      priority: Priority.high,
    );

    final details = NotificationDetails(android: androidDetails);
    final scheduledTime = DateTime.fromMillisecondsSinceEpoch(_phaseEndMillis!);

    await _notifications.zonedSchedule(
      100,
      'TS Reminder',
      _phase == TimerPhase.focus
          ? 'Focus session complete, sir.'
          : 'Break is over, sir. Back to work.',
      tz.TZDateTime.from(scheduledTime, tz.local),
      details,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
    );
  }

  Future<void> _playVoiceForStart() async {
    if (_phase == TimerPhase.focus) {
      await _playAudio('assets/audio/assistant/focus_started_sir.mp3');
    } else {
      await _playAudio('assets/audio/assistant/break_time_sir.mp3');
    }
  }

  Future<void> _playAudio(String assetPath) async {
    try {
      await _player.stop();
      await _player.setAsset(assetPath);
      await _player.play();
    } catch (_) {
      // ignore missing audio for now
    }
  }

  Future<void> _openPresetDialog() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) {
        return Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Timer Presets',
                style: TextStyle(
                  color: AppColors.primaryText,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 16),
              _presetTile('25 / 5', 25, 5),
              _presetTile('30 / 10', 30, 10),
              _presetTile('50 / 10', 50, 10),
            ],
          ),
        );
      },
    );
  }

  Widget _presetTile(String label, int focus, int brk) {
    return ListTile(
      title: Text(
        label,
        style: const TextStyle(color: AppColors.primaryText),
      ),
      onTap: () async {
        Navigator.pop(context);
        _ticker?.cancel();
        await _notifications.cancel(100);

        _focusMinutes = focus;
        _breakMinutes = brk;
        _phase = TimerPhase.focus;
        _isRunning = false;
        _isPaused = false;
        _phaseEndMillis = null;
        _remainingSeconds = _focusMinutes * 60;

        await _saveState();
        if (mounted) setState(() {});
      },
    );
  }

  String _formatTime(int seconds) {
    final minutes = (seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  @override
  Widget build(BuildContext context) {
    final progress = _currentPhaseTotalSeconds == 0
        ? 0.0
        : _remainingSeconds / _currentPhaseTotalSeconds;

    final phaseColor = _phase == TimerPhase.focus
        ? const Color(0xFF22C58B)
        : const Color(0xFFFFB347);

    final phaseLabel = _phase == TimerPhase.focus ? 'Focus' : 'Break';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: Container(
        decoration: const BoxDecoration(
          gradient: AppColors.pageGradient,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
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
                      onPressed: _openPresetDialog,
                      icon: const Icon(
                        Icons.tune_rounded,
                        color: Colors.white,
                        size: 30,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.fromLTRB(18, 26, 18, 18),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(28),
                    gradient: const LinearGradient(
                      colors: [AppColors.surface2, AppColors.surface],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.24),
                        blurRadius: 26,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      SizedBox(
                        height: 270,
                        width: 270,
                        child: CustomPaint(
                          painter: _RingPainter(
                            progress: progress,
                            color: phaseColor,
                          ),
                          child: Center(
                            child: Container(
                              height: 190,
                              width: 190,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    phaseColor.withOpacity(0.22),
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
                                      fontSize: 56,
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
                                      borderRadius: BorderRadius.circular(20),
                                      color: AppColors.surface.withOpacity(0.85),
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
                      const SizedBox(height: 26),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20),
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
                              'Session ${_completedFocusSessions + 1}',
                              style: const TextStyle(
                                color: AppColors.secondaryText,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: _ActionButton(
                              color: const Color(0xFF253E67),
                              icon: Icons.pause_rounded,
                              label: 'Pause',
                              onTap: _pauseTimer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            flex: 2,
                            child: _ActionButton(
                              color: const Color(0xFF4D88F8),
                              icon: Icons.play_arrow_rounded,
                              label:
                                  _isRunning && _isPaused ? 'Resume' : 'Start',
                              onTap: _startTimer,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: _ActionButton(
                              color: const Color(0xFFE95D73),
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
                        value: '$_completedFocusSessions',
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
    return InkWell(
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
