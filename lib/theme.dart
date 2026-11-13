import 'package:flutter/material.dart';

/// Colour tokens (taken from the reference recordings). Getters so the whole app can switch
/// between light and dark: flip [C.dark] and rebuild from the root (see main.dart).
class C {
  static bool dark = false;
  static Color _p(int light, int dk) => Color(dark ? dk : light);

  static Color get bg => _p(0xFFF4F4F5, 0xFF0E0E10);
  static Color get card => _p(0xFFFFFFFF, 0xFF1B1B1E);
  static Color get surface => _p(0xFFFFFFFF, 0xFF1B1B1E); // sheets, nav bar, search fields
  static Color get ink => _p(0xFF0B0B0C, 0xFFF2F2F3);
  static Color get onInk => _p(0xFFFFFFFF, 0xFF0B0B0C); // text/icons placed on an [ink] fill
  static Color get muted => _p(0xFF8A8A8F, 0xFF9A9AA0);
  static Color get faint => _p(0xFFB4B4B8, 0xFF5F5F66);
  static Color get track => _p(0xFFEAEAEC, 0xFF2A2A2F);
  static const accent = Color(0xFFFF4D0D);
  static Color get accentBg => _p(0xFFFFEEE6, 0xFF35190C);
  static const blue = Color(0xFF2F6BFF); // selection accent (calendar)
  static const blueLight = Color(0xFF7DB0FF);
  static const green = Color(0xFF16A34A);
  static Color get greenBg => _p(0xFFE7F6EC, 0xFF10281A);
  static const amber = Color(0xFFD97706);
  static Color get amberBg => _p(0xFFFFF4E0, 0xFF33260F);
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
  static TextStyle get title => TextStyle(fontSize: 26, fontWeight: FontWeight.w700, letterSpacing: -0.6, color: C.ink);
  static TextStyle get sub => TextStyle(fontSize: 12, color: C.muted);
  static TextStyle get body => TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: C.ink);
  static TextStyle get small => TextStyle(fontSize: 11.5, color: C.muted);
  static TextStyle get big => TextStyle(fontSize: 34, fontWeight: FontWeight.w600, letterSpacing: -1, color: C.ink);
}

ThemeData buildTheme() => ThemeData(
      useMaterial3: true,
      brightness: C.dark ? Brightness.dark : Brightness.light,
      scaffoldBackgroundColor: C.bg,
      colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B0B0C), brightness: C.dark ? Brightness.dark : Brightness.light, surface: C.bg),
      splashFactory: NoSplash.splashFactory,
      highlightColor: Colors.transparent,
    );

/// Rebuilds the app from the root when the theme flips (see FinanceApp).
final ValueNotifier<bool> darkNotifier = ValueNotifier(false);

void setDarkMode(bool dark) {
  C.dark = dark;
  darkNotifier.value = dark;
}
