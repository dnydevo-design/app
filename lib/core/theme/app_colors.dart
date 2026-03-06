import 'package:flutter/material.dart';

/// Curated color palette for Fast Share.
///
/// Designed for visual excellence with vibrant gradients and
/// harmonious tones — no generic primary colors.
abstract final class AppColors {
  // ─── Primary Brand Colors ─────────────────────────────
  static const Color primary = Color(0xFF6C5CE7);
  static const Color primaryDark = Color(0xFF8B7CF7);
  static const Color primaryLight = Color(0xFFD6CFFF);

  // ─── Secondary Colors ─────────────────────────────────
  static const Color secondary = Color(0xFF00B894);
  static const Color secondaryDark = Color(0xFF55EFC4);

  // ─── Accent Colors ────────────────────────────────────
  static const Color accent = Color(0xFFFD79A8);
  static const Color accentDark = Color(0xFFFF9FBB);

  // ─── Gradient Colors ──────────────────────────────────
  static const Color gradientStart = Color(0xFF6C5CE7);
  static const Color gradientMiddle = Color(0xFFA29BFE);
  static const Color gradientEnd = Color(0xFFFD79A8);

  // ─── Light Theme ──────────────────────────────────────
  static const Color backgroundLight = Color(0xFFF8F9FE);
  static const Color surfaceLight = Color(0xFFFFFFFF);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color onSurfaceLight = Color(0xFF2D3436);
  static const Color textSecondaryLight = Color(0xFF636E72);
  static const Color dividerLight = Color(0xFFE0E0E0);

  // ─── Dark Theme (True Black / OLED) ────────────────────
  static const Color backgroundDark = Color(0xFF000000);
  static const Color surfaceDark = Color(0xFF111111);
  static const Color cardDark = Color(0xFF1A1A2E);
  static const Color onSurfaceDark = Color(0xFFF5F5F5);
  static const Color textSecondaryDark = Color(0xFFB2BEC3);
  static const Color dividerDark = Color(0xFF2D2D2D);

  // ─── Status Colors ────────────────────────────────────
  static const Color success = Color(0xFF00B894);
  static const Color warning = Color(0xFFFDCB6E);
  static const Color error = Color(0xFFFF6B6B);
  static const Color info = Color(0xFF74B9FF);

  // ─── Transfer Progress ────────────────────────────────
  static const Color progressActive = Color(0xFF6C5CE7);
  static const Color progressPaused = Color(0xFFFDCB6E);
  static const Color progressComplete = Color(0xFF00B894);
  static const Color progressFailed = Color(0xFFFF6B6B);

  // ─── Gradients ────────────────────────────────────────
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [gradientStart, gradientEnd],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A2E), Color(0xFF16213E)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient shimmerGradient = LinearGradient(
    colors: [
      Color(0x00FFFFFF),
      Color(0x33FFFFFF),
      Color(0x00FFFFFF),
    ],
    stops: [0.0, 0.5, 1.0],
  );
}
