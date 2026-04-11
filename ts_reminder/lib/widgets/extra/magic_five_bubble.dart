import 'dart:async';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

class MagicFiveBubble extends StatefulWidget {
  final VoidCallback? onClose;

  const MagicFiveBubble({
    super.key,
    this.onClose,
  });

  @override
  State<MagicFiveBubble> createState() => _MagicFiveBubbleState();
}

class _MagicFiveBubbleState extends State<MagicFiveBubble> {
  int seconds = 300;
  Timer? timer;
  final AudioPlayer _player = AudioPlayer();

  @override
  void initState() {
    super.initState();
    _start();
    _playStartVoice();
  }

  Future<void> _playStartVoice() async {
    try {
      await _player.stop();
      await _player.setAsset('assets/audio/assistant/magic_start.mp3');
      await _player.play();
    } catch (_) {}
  }

  Future<void> _playEndVoice() async {
    try {
      await _player.stop();
      await _player.setAsset('assets/audio/assistant/magic_end.mp3');
      await _player.play();
    } catch (_) {}
  }

  void _start() {
    timer = Timer.periodic(const Duration(seconds: 1), (t) async {
      if (seconds > 0) {
        setState(() {
          seconds--;
        });
      } else {
        t.cancel();
        await _playEndVoice();
      }
    });
  }

  @override
  void dispose() {
    timer?.cancel();
    _player.dispose();
    super.dispose();
  }

  String format() {
    final m = (seconds ~/ 60).toString().padLeft(2, '0');
    final s = (seconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 120,
      right: 20,
      child: Material(
        color: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: const Color(0xFF102643),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.4),
                blurRadius: 20,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Magic 5',
                    style: TextStyle(color: Colors.white70),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: widget.onClose,
                    child: const Icon(
                      Icons.close,
                      size: 18,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                format(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
