import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../profile_controller.dart';

/// Content of `#streakScrim` / `.sheet`, shown via [showModalBottomSheet]
/// rather than a hand-rolled scrim+transform (Flutter's modal sheet already
/// gives the slide-up transition, scrim, and drag-to-dismiss the source
/// CSS was implementing by hand).
class StreakSheet extends StatelessWidget {
  const StreakSheet({super.key, required this.streak, required this.week});

  final int streak;

  /// Real last-7-days activity, oldest first — see
  /// `ProfileRepository.watchLast7DaysActivity` / `buildWeek`. Passed in
  /// rather than read from a constant so this widget stays presentation-only.
  final List<WeekDay> week;

  @override
  Widget build(BuildContext context) {
    final flame = flameForStreak(streak);
    final next = nextMilestone(streak);
    final prev = prevMilestone(streak);
    final pct = ((streak - prev) / (next - prev)).clamp(0.0, 1.0);

    return Container(
      padding: EdgeInsets.fromLTRB(22, 10, 22, 24 + MediaQuery.of(context).padding.bottom),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFFF1DE), AppColors.bg1],
        ),
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)),
          ),
          Text(flame, style: const TextStyle(fontSize: 56)),
          const SizedBox(height: 2),
          Text('$streak-day streak', style: AppTextStyles.baloo(size: 30)),
          const SizedBox(height: 4),
          Text(
            "You've shared a Moodify $streak days in a row 🎉",
            textAlign: TextAlign.center,
            style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w700, color: AppColors.inkDim),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: week
                .map((d) => _WeekDot(label: d.today ? 'Today' : d.label, filled: d.filled, today: d.today))
                .toList(),
          ),
          const SizedBox(height: 20),

          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.paper,
              borderRadius: BorderRadius.circular(18),
              boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Next flame level',
                      style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: AppColors.inkDim),
                    ),
                    Text('$next days', style: AppTextStyles.baloo(size: 13)),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: pct,
                    minHeight: 10,
                    backgroundColor: AppColors.paperSoft,
                    valueColor: const AlwaysStoppedAnimation(AppColors.peach), // gradient approximated as solid peach
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          RichText(
            textAlign: TextAlign.center,
            text: TextSpan(
              style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.55),
              children: const [
                TextSpan(
                  text: 'How your streak works: ',
                  style: const TextStyle(color: AppColors.ink, fontWeight: FontWeight.w700),
                ),
                TextSpan(
                  text: 'post at least one Moodify any time during the day to keep your flame lit. '
                      "Miss a full day and the streak resets to 0 — so today isn't locked in until you post. "
                      'Bigger streaks earn a bigger, brighter flame right on your profile.',
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),

          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.paper,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Got it', style: AppTextStyles.baloo(size: 14.5)),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeekDot extends StatelessWidget {
  const _WeekDot({required this.label, required this.filled, required this.today});

  final String label;
  final bool filled;
  final bool today;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(
            label,
            style: AppTextStyles.quicksand(
              size: 10,
              weight: FontWeight.w800,
              color: today ? AppColors.coralDark : AppColors.inkFaint,
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: filled
                  ? const LinearGradient(colors: [Color(0xFFFFD08A), AppColors.peach])
                  : null,
              color: filled ? null : AppColors.paper,
              border: today ? Border.all(color: AppColors.coral, width: 2) : null,
              boxShadow: [BoxShadow(color: filled ? AppColors.peachDark : AppColors.line, offset: const Offset(0, 3))],
            ),
            child: filled ? const Text('🔥', style: TextStyle(fontSize: 15)) : null,
          ),
        ],
      ),
    );
  }
}