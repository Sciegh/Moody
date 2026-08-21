import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../models/mood_entry.dart';

/// `.mood-strip` / `.mood-chip` — tapping a chip in the source re-themes
/// the whole screen's accent color (see [ProfileController.selectMoodAccent]).
/// Press and hold instead opens that entry's detail sheet, with a trash
/// icon to delete it — see [ProfileScreen._openMoodDetail].
class MoodChipStrip extends StatelessWidget {
  const MoodChipStrip({super.key, required this.moods, required this.onTap, this.onLongPress});

  final List<MoodEntry> moods;
  final ValueChanged<MoodEntry> onTap;
  final ValueChanged<MoodEntry>? onLongPress;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      // Was 66, then 80 — an extra label line (mood name) needs a bit
      // more headroom again to avoid the same RenderFlex overflow.
      height: 86,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: moods.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final mood = moods[i];
          return GestureDetector(
            onTap: () => onTap(mood),
            onLongPress: onLongPress == null ? null : () => onLongPress!(mood),
            child: Container(
              width: 64,
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(mood.emoji, style: const TextStyle(fontSize: 18)),
                  // Was just emoji + day — added the mood name so the
                  // chip is actually readable at a glance instead of
                  // relying on recognizing the emoji.
                  if (mood.label != null && mood.label!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      mood.label!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.quicksand(size: 10, weight: FontWeight.w800, color: AppColors.ink),
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(
                    formatMoodDay(mood.date),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.quicksand(
                      size: 9.5,
                      weight: FontWeight.w700,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}