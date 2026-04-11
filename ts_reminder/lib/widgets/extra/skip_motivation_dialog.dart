import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class SkipMotivationDialog extends StatefulWidget {
  final VoidCallback onSkip;
  final VoidCallback onStartMagic;

  const SkipMotivationDialog({
    super.key,
    required this.onSkip,
    required this.onStartMagic,
  });

  @override
  State<SkipMotivationDialog> createState() =>
      _SkipMotivationDialogState();
}

class _SkipMotivationDialogState extends State<SkipMotivationDialog>
    with SingleTickerProviderStateMixin {
  final AudioPlayer _player = AudioPlayer();

  late AnimationController _waveController;

  @override
  void initState() {
    super.initState();

    _waveController =
        AnimationController(vsync: this, duration: const Duration(milliseconds: 800))
          ..repeat(reverse: true);

    _playVoice();
  }

  Future<void> _playVoice() async {
    try {
      await _player.setAsset(
          'assets/audio/assistant/motivation_help_me.mp3');
      await _player.play();
    } catch (_) {}
  }

  @override
  void dispose() {
    _waveController.dispose();
    _player.dispose();
    super.dispose();
  }

  Widget _waveBar(double heightFactor) {
    return AnimatedBuilder(
      animation: _waveController,
      builder: (_, __) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: 6,
          height: 10 + (20 * heightFactor * _waveController.value),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF102643),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(28),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Stay Focused',
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'You chose this task for a reason.\n\nJust start for 5 minutes.',
              style: TextStyle(color: Colors.white70),
              textAlign: TextAlign.center,
            ),

            const SizedBox(height: 20),

            /// 🔊 Voice Wave
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _waveBar(1),
                _waveBar(1.2),
                _waveBar(0.8),
                _waveBar(1.4),
                _waveBar(1),
              ],
            ),

            const SizedBox(height: 24),

            /// Buttons
            Row(
              children: [
                /// Skip Anyway
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.redAccent,
                      side: const BorderSide(color: Colors.redAccent),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: widget.onSkip,
                    child: const Text('Skip Anyway'),
                  ),
                ),

                const SizedBox(width: 10),

                /// Magic 5
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: widget.onStartMagic,
                    child: const Text('Magic 5'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),

            /// Let's Do It
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF20C08A),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("Let's Do It"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
