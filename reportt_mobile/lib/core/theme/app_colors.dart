import 'package:flutter/material.dart';

/// Reportt Resmi Renk Paleti
///
/// Daha az kırmızı, daha koyu lacivert tonları — devlet kurumsal kimliğine uygun.
class AppColors {
  AppColors._();

  // Primary — Koyu Lacivert (Resmi görünüm)
  static const Color primary = Color(0xFF1A2744);
  static const Color primaryLight = Color(0xFF2D4373);
  static const Color primaryDark = Color(0xFF0F1A2E);

  // Secondary/Accent — Altın sarısı (Kurumsal vurgu)
  static const Color accent = Color(0xFFD4A843);
  static const Color accentLight = Color(0xFFE8C66A);

  // Tertiary — Türk Bayrağı kırmızısı (minimal kullanım)
  static const Color turkishRed = Color(0xFFE30A17);

  // Status Colors
  static const Color success = Color(0xFF059669);
  static const Color warning = Color(0xFFD97706);
  static const Color error = Color(0xFFDC2626);
  static const Color info = Color(0xFF2563EB);

  // Backgrounds
  static const Color backgroundLight = Color(0xFFF5F7FA);
  static const Color backgroundDark = Color(0xFF0B1120);
  static const Color surfaceLight = Colors.white;
  static const Color surfaceDark = Color(0xFF1A2332);

  // Text Colors
  static const Color textPrimaryLight = Color(0xFF0F172A);
  static const Color textSecondaryLight = Color(0xFF64748B);
  static const Color textPrimaryDark = Color(0xFFF1F5F9);
  static const Color textSecondaryDark = Color(0xFF94A3B8);
}
