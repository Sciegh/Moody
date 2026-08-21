import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTheme {
  AppTheme._();

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.bg1,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.coral,
        primary: AppColors.coral,
        secondary: AppColors.peach,
        surface: AppColors.paper,
      ),
      fontFamily: GoogleFonts.quicksand().fontFamily,
    );

    return base.copyWith(
      textTheme: GoogleFonts.quicksandTextTheme(base.textTheme).copyWith(
        // Headline-ish styles borrow Baloo 2, matching `h1,h2,h3` in the CSS.
        headlineLarge: GoogleFonts.baloo2(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineMedium: GoogleFonts.baloo2(
          fontSize: 23,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
        headlineSmall: GoogleFonts.baloo2(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: AppColors.ink,
        ),
      ),
    );
  }
}
