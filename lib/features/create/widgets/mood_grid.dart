import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../models/mood_option.dart';

/// Per-family gradient for the filter chips — two-tone washes pulled from
/// each family's own mood accents (e.g. 'calm' blends its `peaceful` and
/// `chill` accents) so each chip's color story matches the moods it filters.
/// 'all' gets a neutral ink-to-ink gradient rather than a mood color, since
/// it doesn't belong to any one family.
const Map<String, List<Color>> _kFilterGradients = {
  'all': [AppColors.ink, Color(0xFF3A3A3A)],
  'calm': [Color(0xFF7FB7A3), Color(0xFF6FA8DC)],
  'energetic': [Color(0xFFFF8A5B), Color(0xFFFFC145)],
  'social': [Color(0xFFFF7EB6), Color(0xFFF25C78)],
  'heavy': [Color(0xFF6B7A99), Color(0xFF7D6E83)],
  'anxious': [Color(0xFFC99A55), Color(0xFFD97757)],
};

/// `.filter-row` / `.chip` — horizontal family filter chips.
class MoodFilterRow extends StatelessWidget {
  const MoodFilterRow({super.key, required this.activeFilter, required this.onSelect});

  final String activeFilter;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 38,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: kFilters.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final f = kFilters[i];
          final active = f == activeFilter;
          final label = f == 'all' ? 'All moods' : kFamilyLabels[f]!;
          final gradientColors = _kFilterGradients[f]!;
          return GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              decoration: BoxDecoration(
                // Active chip gets the full-strength family gradient;
                // inactive chips keep a faint tint of it so the color story
                // still reads before you tap.
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: active
                      ? gradientColors
                      : [
                          Color.lerp(AppColors.paper, gradientColors[0], 0.14)!,
                          Color.lerp(AppColors.paper, gradientColors[1], 0.14)!,
                        ],
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: active ? gradientColors[1].withOpacity(0.5) : AppColors.line, offset: const Offset(0, 3))],
              ),
              alignment: Alignment.center,
              child: Text(
                label,
                style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w700, color: active ? Colors.white : AppColors.inkDim),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// `.mood-grid` — a 3-column grid of `.mood-tile`s, with a locked style for
/// premium moods when Deluxe isn't unlocked.
class MoodGrid extends StatelessWidget {
  const MoodGrid({
    super.key,
    required this.moods,
    required this.selectedMood,
    required this.deluxeUnlocked,
    required this.onSelect,
    required this.onLockedTap,
  });

  final List<MoodOption> moods;
  final MoodOption? selectedMood;
  final bool deluxeUnlocked;
  final ValueChanged<MoodOption> onSelect;
  final VoidCallback onLockedTap;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: moods.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1.15, // more compact — matches the smaller reference cards
      ),
      itemBuilder: (context, i) {
        final m = moods[i];
        final locked = m.premium && !deluxeUnlocked;
        final selected = selectedMood?.id == m.id;
        return _MoodTile(mood: m, locked: locked, selected: selected, onTap: () => locked ? onLockedTap() : onSelect(m));
      },
    );
  }
}

/// Builds the tile's background gradient from its mood's `accent` color.
///
/// - Unselected: a faint top-left-to-bottom-right wash from white into a
///   light tint of the accent, so every tile carries a hint of its mood's
///   color even at rest (matches `.mood-tile` in the source, which sits on
///   `--paper` but takes a soft `--accent-light` glow).
/// - Selected: a stronger version of the same gradient, going from a light
///   tint straight into the full accent, so the pressed/selected state reads
///   clearly as "this mood's color."
LinearGradient _tileGradient(Color accent, bool selected) {
  if (selected) {
    return LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        Color.lerp(Colors.white, accent, 0.35)!,
        Color.lerp(Colors.white, accent, 0.85)!,
      ],
    );
  }
  return LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      AppColors.paper,
      Color.lerp(AppColors.paper, accent, 0.16)!,
    ],
  );
}

class _MoodTile extends StatelessWidget {
  const _MoodTile({required this.mood, required this.locked, required this.selected, required this.onTap});

  final MoodOption mood;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: locked ? '${mood.label} — Deluxe mood, unlock to use' : mood.label,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
          transformAlignment: Alignment.center,
          transform: selected ? (Matrix4.identity()..scale(1.05)..translate(0.0, -2.0)) : Matrix4.identity(),
          decoration: BoxDecoration(
            color: locked ? AppColors.paperSoft : null,
            gradient: locked ? null : _tileGradient(mood.accent, selected),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: selected ? mood.accent : AppColors.line,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Locked moods stay clearly visible — a light opacity
                  // reduction reads as "locked" without making the emoji
                  // vanish the way the previous very-low opacity did.
                  Opacity(
                    opacity: locked ? 0.75 : 1,
                    child: Text(mood.emoji, style: const TextStyle(fontSize: 20)),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    mood.label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.quicksand(
                      size: 10.5,
                      weight: FontWeight.w700,
                      color: locked ? AppColors.inkFaint : (selected ? AppColors.ink : AppColors.inkDim),
                    ),
                  ),
                ],
              ),
              if (locked)
                Positioned(
                  top: -6,
                  right: -2,
                  child: Container(
                    width: 17,
                    height: 17,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.ink,
                      border: Border.all(color: AppColors.paperSoft, width: 1.5),
                    ),
                    child: const Text('🔒', style: TextStyle(fontSize: 8)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.unlock-banner` — the gradient CTA above the mood grid.
class UnlockBanner extends StatelessWidget {
  const UnlockBanner({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Was hardcoded to "8 Deluxe moods" — now reflects the real count of
    // `premium: true` entries in kAllMoods, so this stays correct if that
    // list changes instead of silently going stale.
    final deluxeCount = kAllMoods.where((m) => m.premium).length;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 13),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [AppColors.marigold, Color(0xFFFF8A5B)]),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            const Text('💎', style: TextStyle(fontSize: 24)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Unlock $deluxeCount Deluxe moods', style: AppTextStyles.baloo(size: 13.5, color: Colors.white)),
                  const SizedBox(height: 2),
                  Text(
                    'One-time purchase — yours forever',
                    style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: Colors.white.withOpacity(0.92)),
                  ),
                ],
              ),
            ),
            const Text('›', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
          ],
        ),
      ),
    );
  }
}