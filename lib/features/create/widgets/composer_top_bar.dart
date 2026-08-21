import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/circle_icon_button.dart';

/// `.top-bar` — close button, title, and the 3-dot step indicator.
class ComposerTopBar extends StatelessWidget {
  const ComposerTopBar({super.key, required this.stepsActive, required this.onClose});

  /// Number of active dots (1 = mood not yet picked, 3 = mood picked —
  /// mirrors the source's dot1-always-active / dot2+dot3-on-mood-select).
  final int stepsActive;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 2, 20, 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          CircleIconButton(
            semanticLabel: 'Close and discard this Moodify',
            onPressed: onClose,
            child: const Icon(Icons.close, size: 18, color: AppColors.inkDim),
          ),
          Text('New Moodify', style: AppTextStyles.baloo(size: 16)),
          Row(
            children: List.generate(3, (i) {
              final active = i < stepsActive;
              return Container(
                margin: EdgeInsets.only(left: i == 0 ? 0 : 6),
                width: 7,
                height: 7,
                decoration: BoxDecoration(shape: BoxShape.circle, color: active ? AppColors.coral : AppColors.line),
              );
            }),
          ),
        ],
      ),
    );
  }
}

/// `.audience-row` — "Who sees this" summary, opens [AudienceSheet].
class AudienceRow extends StatelessWidget {
  const AudienceRow({super.key, required this.title, required this.subtitle, required this.onTap});

  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(20),
          boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            const Text('👥', style: TextStyle(fontSize: 19)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                  const SizedBox(height: 1),
                  Text(subtitle, style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint)),
                ],
              ),
            ),
            const Text('›', style: TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}