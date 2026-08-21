import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../create_controller.dart';

/// `#notifCard` — the "turn on notifications" prompt.
class NotifCard extends StatelessWidget {
  const NotifCard({super.key, required this.onAllow, required this.onSkip});
  final VoidCallback onAllow;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 4))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('🔔', style: TextStyle(fontSize: 20)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Turn on notifications so friends know when you post a Moodify, and so you know when they do!',
                  style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.4),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _NotifButton(label: 'Sounds good', primary: true, onTap: onAllow),
                    const SizedBox(width: 8),
                    _NotifButton(label: 'Not now', primary: false, onTap: onSkip),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _NotifButton extends StatelessWidget {
  const _NotifButton({required this.label, required this.primary, required this.onTap});
  final String label;
  final bool primary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: primary ? AppColors.coral : AppColors.paperSoft,
          borderRadius: BorderRadius.circular(20),
          boxShadow: primary ? const [BoxShadow(color: AppColors.coralDark, offset: Offset(0, 3))] : null,
        ),
        child: Text(
          label,
          style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: primary ? Colors.white : AppColors.ink),
        ),
      ),
    );
  }
}

/// `#errorBanner`.
class ComposerErrorBanner extends StatelessWidget {
  const ComposerErrorBanner({super.key, required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(20, 0, 20, 14),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFE7E0),
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: Color(0xFFF6C4B4), offset: Offset(0, 3))],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: Color(0xFFB4472A), fontWeight: FontWeight.w700, fontSize: 12.5, height: 1.4),
            ),
          ),
          const SizedBox(width: 10),
          GestureDetector(
            onTap: onRetry,
            child: const Text(
              'Retry',
              style: TextStyle(color: Color(0xFFB4472A), fontWeight: FontWeight.w800, fontSize: 12, decoration: TextDecoration.underline),
            ),
          ),
        ],
      ),
    );
  }
}

/// `#offlineBanner`.
class OfflineBanner extends StatelessWidget {
  const OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 9),
      color: const Color(0xFFFFE7B0),
      child: Text(
        "You're offline — this Moodify will send once you're back online 💌",
        textAlign: TextAlign.center,
        style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w700, color: const Color(0xFF7A5300)),
      ),
    );
  }
}

/// `#postBtn` — the footer's primary CTA, with disabled/ready/loading states.
class ComposerPostButton extends StatelessWidget {
  const ComposerPostButton({super.key, required this.status, required this.moodSelected, required this.onTap});

  final PostStatus status;
  final bool moodSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final loading = status == PostStatus.posting;
    final ready = moodSelected && !loading;
    final label = loading ? 'Posting…' : (moodSelected ? 'Post Moodify 🚀' : 'Pick a mood to continue');

    return GestureDetector(
      onTap: ready ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 15),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          gradient: ready
              ? const LinearGradient(colors: [AppColors.coral, AppColors.coralDark], begin: Alignment.topCenter, end: Alignment.bottomCenter)
              : null,
          color: ready ? null : AppColors.inkFaint,
          boxShadow: ready
              ? const [BoxShadow(color: AppColors.coralDark, offset: Offset(0, 5)), BoxShadow(color: Color(0x73E24E74), offset: Offset(0, 10), blurRadius: 18)]
              : const [BoxShadow(color: Color(0x2E5B4033), offset: Offset(0, 4))],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (loading) ...[
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation(Colors.white)),
              ),
              const SizedBox(width: 8),
            ],
            Text(label, style: AppTextStyles.baloo(size: 16, color: Colors.white)),
          ],
        ),
      ),
    );
  }
}
