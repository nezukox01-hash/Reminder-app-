import 'package:flutter/material.dart';

class AppColors {
  static const Color background = Color(0xFF071A2F);
  static const Color surface = Color(0xFF0D2744);
  static const Color surface2 = Color(0xFF123255);

  static const Color primaryText = Colors.white;
  static const Color secondaryText = Color(0xFFB7C9E2);

  static const Color timer = Color(0xFF2ECC71);
  static const Color reminder = Color(0xFFFFA726);
  static const Color tasks = Color(0xFF42A5F5);
  static const Color motivation = Color(0xFFAB47BC);
  static const Color report = Color(0xFFFF7043);
  static const Color notes = Color(0xFF26C6DA);

  static const Color navBackground = Color(0xFF091F37);
  static const Color navSelected = Colors.white;
  static const Color navUnselected = Color(0xFF7F97B5);

  static const LinearGradient pageGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [
      Color(0xFF0A2340),
      Color(0xFF071A2F),
    ],
  );
}
