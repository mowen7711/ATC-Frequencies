import 'package:flutter/material.dart';

@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.background,
    required this.surface,
    required this.card,
    required this.border,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.accent,
    required this.accentDim,
  });

  final Color background;
  final Color surface;
  final Color card;
  final Color border;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color accent;
  final Color accentDim;

  static const dark = AppColors(
    background:    Color(0xFF0B1120),
    surface:       Color(0xFF131E30),
    card:          Color(0xFF1C2B40),
    border:        Color(0xFF2A3F5A),
    textPrimary:   Color(0xFFE8EDF5),
    textSecondary: Color(0xFF8EA4C0),
    textMuted:     Color(0xFF4A6280),
    accent:        Color(0xFFFFB300),
    accentDim:     Color(0xFFCC8E00),
  );

  static const light = AppColors(
    background:    Color(0xFFF0F4F8),
    surface:       Color(0xFFFFFFFF),
    card:          Color(0xFFFFFFFF),
    border:        Color(0xFFD0DCE8),
    textPrimary:   Color(0xFF0B1120),
    textSecondary: Color(0xFF4A6280),
    textMuted:     Color(0xFF8EA4C0),
    accent:        Color(0xFFE6A000),
    accentDim:     Color(0xFFB87D00),
  );

  @override
  AppColors copyWith({
    Color? background,
    Color? surface,
    Color? card,
    Color? border,
    Color? textPrimary,
    Color? textSecondary,
    Color? textMuted,
    Color? accent,
    Color? accentDim,
  }) {
    return AppColors(
      background:    background    ?? this.background,
      surface:       surface       ?? this.surface,
      card:          card          ?? this.card,
      border:        border        ?? this.border,
      textPrimary:   textPrimary   ?? this.textPrimary,
      textSecondary: textSecondary ?? this.textSecondary,
      textMuted:     textMuted     ?? this.textMuted,
      accent:        accent        ?? this.accent,
      accentDim:     accentDim     ?? this.accentDim,
    );
  }

  @override
  AppColors lerp(AppColors? other, double t) {
    if (other is! AppColors) return this;
    return AppColors(
      background:    Color.lerp(background,    other.background,    t)!,
      surface:       Color.lerp(surface,       other.surface,       t)!,
      card:          Color.lerp(card,          other.card,          t)!,
      border:        Color.lerp(border,        other.border,        t)!,
      textPrimary:   Color.lerp(textPrimary,   other.textPrimary,   t)!,
      textSecondary: Color.lerp(textSecondary, other.textSecondary, t)!,
      textMuted:     Color.lerp(textMuted,     other.textMuted,     t)!,
      accent:        Color.lerp(accent,        other.accent,        t)!,
      accentDim:     Color.lerp(accentDim,     other.accentDim,     t)!,
    );
  }
}

extension AppColorsX on BuildContext {
  AppColors get col => Theme.of(this).extension<AppColors>()!;
}
