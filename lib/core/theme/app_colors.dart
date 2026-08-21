import 'package:flutter/material.dart';

/// Static design tokens lifted 1:1 from the `:root { --var: ... }` block
/// shared by every screen in the source HTML (Login/Register/Profile/etc).
///
/// CSS custom properties don't have a Flutter equivalent that lets every
/// widget "just read a variable," so these become `static const Color`s.
/// Where a screen redefines `--accent` dynamically (Profile, moodify-create)
/// that's modeled as Riverpod state instead — see
/// `features/profile/profile_controller.dart` — not as a static token here.
class AppColors {
  AppColors._();

  // Backgrounds
  static const bg1 = Color(0xFFFFF6EC);
  static const bg2 = Color(0xFFFFE7D3);
  static const paper = Color(0xFFFFFFFF);
  static const paperSoft = Color(0xFFFFF1E3);

  // Ink (text)
  static const ink = Color(0xFF5B4033);
  static const inkDim = Color(0xFF9B7E6C);
  static const inkFaint = Color(0xFFC9AF9C);

  // `--line: rgba(91,64,51,0.10)` — the flat 1px/3px "pressed edge" color
  // used on every card/button shadow.
  static const line = Color(0x1A5B4033);
  static const lineSoft = Color(0x0F5B4033);

  // Palette accents
  static const coral = Color(0xFFFF6F91);
  static const coralDark = Color(0xFFE24E74);
  static const peach = Color(0xFFFFA65C);
  static const peachDark = Color(0xFFE8863C);
  static const sky = Color(0xFF4FB9E8);
  static const skyDark = Color(0xFF2E96C6);
  static const mint = Color(0xFF3FCE9A);
  static const mintDark = Color(0xFF26AD7C);
  static const lilac = Color(0xFFB084E0);
  static const lilacDark = Color(0xFF9364C2);
  static const marigold = Color(0xFFFFC24B);

  // Default `--accent` / `--accent-light` (matches Profile.html's initial
  // values before the "today's mood" script runs).
  static const accentDefault = coral;
  static const accentLightDefault = Color(0xFFFFC1D2);

  /// `radial-gradient(circle at 12% 8%, rgba(255,196,148,.55), transparent 45%)`
  /// on top of `--bg-1`. Used behind Login/Register (the static variant,
  /// with no dynamic accent).
  static const bodyGradientSpot1 = Color(0x8CFFC494); // rgba(255,196,148,.55)

  /// Bottom spot is intentionally just `bg2` (not an accent color) — it
  /// blends the bottom of the screen into the same warm-neutral palette
  /// as the base instead of introducing a contrasting hue.
  static const bodyGradientSpot2 = bg2;
}