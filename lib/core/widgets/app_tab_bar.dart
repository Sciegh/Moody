import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

enum AppTab { create, friends, profile }

/// `.tabbar` — the bottom nav shared by Profile/Friends/Add-friend.
///
/// NOTE: this is duplicated per-screen (rebuilt fresh on every route)
/// rather than hoisted into a `go_router` `ShellRoute`, matching how the
/// source HTML repeats the same `<nav class="tabbar">` markup on every
/// page. Once all three destinations are real screens, consider a
/// `ShellRoute` instead so the bar doesn't rebuild/lose state on navigation.
class AppTabBar extends StatelessWidget {
  const AppTabBar({super.key, required this.active, required this.accent});

  final AppTab active;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 700),
      padding: EdgeInsets.fromLTRB(10, 10, 10, 12 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        // Was `Color.lerp(AppColors.bg1, accent, 0.14)` — barely different
        // from the mood-background wash it sits on top of, so the bar
        // visually disappeared into the screen. A solid paper color plus
        // a real elevation shadow (instead of just a 2px top line) makes
        // it read clearly as a separate surface regardless of the current
        // mood accent.
        color: AppColors.paper,
        // A slim accent-colored top edge keeps the current mood color
        // present (instead of dropping it entirely), but as a 3px stripe
        // on a solid white bar it stays a clear accent, not a wash.
        border: Border(top: BorderSide(color: accent, width: 3)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.08), offset: const Offset(0, -3), blurRadius: 14),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _TabItem(
            emoji: '💭',
            label: 'Create',
            active: active == AppTab.create,
            onTap: () => context.go('/moodify-create'),
          ),
          _TabItem(
            emoji: '👥',
            label: 'Friends',
            active: active == AppTab.friends,
            onTap: () => context.go('/friends'),
          ),
          _TabItem(
            emoji: '🙂',
            label: 'Profile',
            active: active == AppTab.profile,
            onTap: () => context.go('/profile'),
          ),
        ],
      ),
    );
  }
}

class _TabItem extends StatelessWidget {
  const _TabItem({required this.emoji, required this.label, required this.active, required this.onTap});

  final String emoji;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.coralDark : AppColors.inkFaint;
    return GestureDetector(
      // Was just wrapping the tight Column with no padding or hit-test
      // behavior — the tappable area was literally the pixel bounds of
      // the emoji + label glyphs, so taps a few px off (very easy on a
      // bottom nav) missed entirely. HitTestBehavior.opaque makes the
      // whole padded box tappable, not just the glyphs' opaque pixels;
      // the padding pushes the effective target well past the 44dp
      // minimum recommended tap size.
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 19)),
            const SizedBox(height: 3),
            Text(label, style: AppTextStyles.quicksand(size: 10.5, weight: FontWeight.w700, color: color)),
          ],
        ),
      ),
    );
  }
}
