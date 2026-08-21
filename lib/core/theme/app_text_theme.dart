import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

/// Source CSS:
///   @import url('.../css2?family=Baloo+2:wght@500;600;700;800&family=Quicksand:wght@400;500;600;700&display=swap');
///   h1,h2,h3 { font-family:'Baloo 2', sans-serif; }
///   body { font-family:'Quicksand', system-ui, sans-serif; }
///
/// `google_fonts` fetches these at runtime (and caches them), same as the
/// browser's @import. If you'd rather ship them as offline assets instead
/// (recommended for release builds / app-store review consistency), swap
/// these `GoogleFonts.xxx()` calls for `TextStyle(fontFamily: 'Baloo2')` /
/// `'Quicksand'` pointing at bundled .ttf files declared in pubspec.yaml.
class AppTextStyles {
  AppTextStyles._();

  static TextStyle baloo({
    required double size,
    FontWeight weight = FontWeight.w700,
    Color color = AppColors.ink,
    double? height,
  }) =>
      GoogleFonts.baloo2(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle quicksand({
    required double size,
    FontWeight weight = FontWeight.w500,
    Color color = AppColors.ink,
    double? height,
  }) =>
      GoogleFonts.quicksand(
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );
}
