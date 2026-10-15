import 'package:flutter/material.dart';

extension ThemeExt on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get bg => Theme.of(this).scaffoldBackgroundColor;
  Color get bgSidebar => isDark ? AppColors.darkBgSidebar : AppColors.lightBgSidebar;
  Color get bgPanel => Theme.of(this).colorScheme.surface;
  Color get bgInput => isDark ? AppColors.darkBgInput : AppColors.lightBgInput;
  Color get bgMsgAi => isDark ? AppColors.darkBgMsgAi : AppColors.lightBgMsgAi;
  Color get bgHover => isDark ? AppColors.darkBgHover : AppColors.lightBgHover;
  Color get border => Theme.of(this).dividerColor;
  Color get borderFaint => isDark ? AppColors.darkBorderFaint : AppColors.lightBorderFaint;
  
  Color get text => isDark ? AppColors.darkText : AppColors.lightText;
  Color get textM => isDark ? AppColors.darkTextM : AppColors.lightTextM;
  Color get textD => isDark ? AppColors.darkTextD : AppColors.lightTextD;
}

/// Pink-first design tokens for light and dark modes.
class AppColors {
  AppColors._();

  // ── Common Colors ──────────────────────────────────────────────
  static const accent    = Color(0xFFE84D93);
  static const accentDim = Color(0xFFC72B72);
  static const accentHi  = Color(0xFFFF80B5);
  static const green  = Color(0xFF3FB950);
  static const red    = Color(0xFFF85149);
  static const orange = Color(0xFFE3B341);

  // ── Dark Theme Colors ──────────────────────────────────────────
  static const darkBg        = Color(0xFF121212); // Neutral charcoal
  static const darkBgSidebar = Color(0xFF121212);
  static const darkBgPanel   = Color(0xFF1D1D1F);
  static const darkBgInput   = Color(0xFF262629);
  static const darkBgMsgAi   = Color(0xFF1D1D1F);
  static const darkBgHover   = Color(0xFF262629);
  static const darkBorder    = Color(0xFF39393D);
  static const darkBorderFaint = Color(0xFF2C2C30);
  static const darkText      = Color(0xFFF7F7F8);
  static const darkTextM     = Color(0xFFB8B8BD);
  static const darkTextD     = Color(0xFF85858D);

  // ── Light Theme Colors ─────────────────────────────────────────
  static const lightBg        = Color(0xFFFFFFFF);
  static const lightBgSidebar = Color(0xFFFFF5FA); // Soft blush white
  static const lightBgPanel   = Color(0xFFFFF5FA);
  static const lightBgInput   = Color(0xFFFFFFFF);
  static const lightBgMsgAi   = Color(0xFFFFF5FA);
  static const lightBgHover   = Color(0xFFF5DCE8);
  static const lightBorder    = Color(0xFFF5DCE8); // Soft borders
  static const lightBorderFaint = Color(0xFFFFEAF3);
  static const lightText      = Color(0xFF301A2A); // Dark slate
  static const lightTextM     = Color(0xFF70546A);
  static const lightTextD     = Color(0xFFA58D9F);

  // ── Label colours ────────────────────────────────────────────
  static const uncensored = Color(0xFFEF4444);
  static const standard   = Color(0xFF06B6D4);
  static const custom     = Color(0xFF22C55E);

  // ── Gradients ────────────────────────────────────────────────
  static const accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFF9AC5)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}
