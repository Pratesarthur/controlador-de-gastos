import 'package:flutter/material.dart';

/// Colour tokens (taken from the reference recordings).
class C {
  static const bg = Color(0xFFF4F4F5);
  static const card = Colors.white;
  static const ink = Color(0xFF0B0B0C);
  static const muted = Color(0xFF8A8A8F);
  static const faint = Color(0xFFB4B4B8);
  static const track = Color(0xFFEAEAEC);
  static const accent = Color(0xFFFF4D0D);
  static const green = Color(0xFF16A34A);
  static const greenBg = Color(0xFFE7F6EC);
  static const amber = Color(0xFFD97706);
  static const amberBg = Color(0xFFFFF4E0);
}

/// Motion tokens: every animation in the app pulls from here so the
/// whole app feels like it moves with one "personality".
class Motion {
  static const fast = Duration(milliseconds: 180);
  static const base = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 700);
  static const curve = Curves.easeOutCubic;
  static const spring = Curves.easeOutBack;
}

class T {
  static const title = TextStyle(
      fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: C.ink);
  static const sub = TextStyle(fontSize: 12, color: C.muted);
  static const body = TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink);
  static const small = TextStyle(fontSize: 11.5, color: C.muted);
  static const big = TextStyle(
      fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1, color: C.ink);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: C.ink, surface: C.bg),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );
