import 'dart:ui' as ui;
import 'dart:io';
import 'dart:typed_data';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/daily_report_model.dart';

class MagicShareDialog extends StatefulWidget {
  final DailyReport report;

  const MagicShareDialog({super.key, required this.report});

  @override
  State<MagicShareDialog> createState() => _MagicShareDialogState();
}

class _MagicShareDialogState extends State<MagicShareDialog> {
  final GlobalKey _magicKey = GlobalKey();
  late String _selectedBg;
  bool _isSharing = false;

  // 📸 আপনার আপলোড করা ছবিগুলোর লিস্ট
  final List<String> _backgrounds = [
    'assets/images/magic_bg1.png',
    'assets/images/magic_bg2.png',
    'assets/images/magic_bg3.png',
  ];

  @override
  void initState() {
    super.initState();
    // 🎲 র‍্যান্ডমলি যেকোনো একটা ছবি সিলেক্ট করবে
    _selectedBg = _backgrounds[Random().nextInt(_backgrounds.length)];
  }

  Future<void> _shareMagicCard() async {
    setState(() => _isSharing = true);
    try {
      RenderRepaintBoundary boundary =
          _magicKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
      ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      Uint8List pngBytes = byteData!.buffer.asUint8List();

      final directory = await getTemporaryDirectory();
      final imagePath = await File('${directory.path}/TS_Magic_${widget.report.date}.png').create();
      await imagePath.writeAsBytes(pngBytes);

      // শেয়ারের ডায়লগ খোলার আগে আমাদের এই ম্যাজিক প্রিভিউ ডায়লগটা বন্ধ করে দিচ্ছি
      if (mounted) Navigator.pop(context);

      await Share.shareXFiles(
        [XFile(imagePath.path)],
        text: 'Here is my TS Reminder Daily Report for ${_formatDatePretty(widget.report.date)}! 🪄✨',
      );
    } catch (e) {
      debugPrint("Magic Share error: $e");
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _formatDatePretty(String date) {
    final parts = date.split('-');
    if (parts.length != 3) return date;
    final year = parts[0];
    final month = int.tryParse(parts[1]) ?? 1;
    final day = int.tryParse(parts[2]) ?? 1;
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    final monthName = (month >= 1 && month <= 12) ? months[month - 1] : parts[1];
    return '$monthName $day, $year';
  }

  TextStyle _magicStyle() {
    return const TextStyle(
      color: Color(0xFF555555), // লেখার কালার
      fontSize: 18,
      fontWeight: FontWeight.w700,
    );
  }

  @override
  Widget build(BuildContext context) {
    final tasksDone = widget.report.completedTasks + widget.report.skippedTasks;
    final totalTasks = widget.report.completedTasks + widget.report.skippedTasks + widget.report.pendingTasks;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 📸 এই RepaintBoundary র‍্যান্ডম ব্যাকগ্রাউন্ডসহ ছবি বানাবে
          RepaintBoundary(
            key: _magicKey,
            child: Container(
              width: 320,
              height: 480,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: AssetImage(_selectedBg),
                  fit: BoxFit.cover,
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.only(top: 170, left: 45, right: 45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      _formatDatePretty(widget.report.date),
                      style: const TextStyle(
                        color: Color(0xFF6AE2C1),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 25),
                    Text('Study Time: ${widget.report.studyMinutes}m', style: _magicStyle()),
                    const SizedBox(height: 12),
                    Text('Tasks Done: $tasksDone/$totalTasks', style: _magicStyle()),
                    const SizedBox(height: 12),
                    Text('Focus Sessions: ${widget.report.focusSessions}', style: _magicStyle()),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6AE2C1),
              foregroundColor: Colors.black87,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            ),
            onPressed: _isSharing ? null : _shareMagicCard,
            icon: _isSharing 
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black87))
                : const Icon(Icons.share_rounded),
            label: Text(
              _isSharing ? 'Preparing Magic...' : 'Share Magic Card', 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
            ),
          ),
        ],
      ),
    );
  }
}
