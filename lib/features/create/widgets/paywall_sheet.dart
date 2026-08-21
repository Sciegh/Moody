import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../models/mood_option.dart';

/// `#paywallScrim` / `.sheet` — the Deluxe-unlock paywall.
class PaywallSheet extends StatelessWidget {
  const PaywallSheet({
    super.key,
    required this.processing,
    required this.unlocked,
    required this.onBuy,
    required this.onLater,
  });

  final bool processing;
  final bool unlocked;
  final VoidCallback onBuy;
  final VoidCallback onLater;

  @override
  Widget build(BuildContext context) {
    final premium = kAllMoods.where((m) => m.premium).toList();
    final buyLabel = unlocked ? 'Unlocked ✓' : (processing ? 'Processing…' : 'Unlock for \$4.99');

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      decoration: BoxDecoration(
        color: Color.lerp(AppColors.bg1, AppColors.marigold, 0.10),
        borderRadius: const BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)),
          ),
          Text('Unlock Deluxe moods', style: AppTextStyles.baloo(size: 19), textAlign: TextAlign.center),
          const SizedBox(height: 4),
          Text(
            'A one-time purchase — no subscription, yours for good',
            textAlign: TextAlign.center,
            style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint),
          ),
          const SizedBox(height: 14),

          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: premium
                .map((m) => Container(
                      width: 42,
                      height: 42,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.paper,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
                      ),
                      child: Text(m.emoji, style: const TextStyle(fontSize: 19)),
                    ))
                .toList(),
          ),
          const SizedBox(height: 14),

          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text('\$4.99', style: AppTextStyles.baloo(size: 30)),
              const SizedBox(width: 6),
              Text('one time', style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: AppColors.inkDim)),
            ],
          ),
          const SizedBox(height: 18),

          const _PaywallListItem(emoji: '🎉', text: "16 extra moods for the fun, flirty, and expressive stuff the everyday moods don't quite cover."),
          const SizedBox(height: 9),
          const _PaywallListItem(emoji: '🔁', text: 'Pay once — no recurring charge, and it stays unlocked if you reinstall.'),
          const SizedBox(height: 9),
          const _PaywallListItem(emoji: '🫶', text: 'Every core mood, including the harder ones, stays free — always. This is just extra flavor.'),
          const SizedBox(height: 20),

          SizedBox(
            width: double.infinity,
            child: GestureDetector(
              onTap: (processing || unlocked) ? null : onBuy,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                padding: const EdgeInsets.symmetric(vertical: 15),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(22),
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFFFF8A5B), Color(0xFFE8863C)],
                  ),
                  boxShadow: const [
                    BoxShadow(color: Color(0xFFC46B2B), offset: Offset(0, 5)),
                    BoxShadow(color: Color(0x73E8863C), offset: Offset(0, 10), blurRadius: 18),
                  ],
                ),
                child: Opacity(
                  opacity: processing ? 0.7 : 1,
                  child: Text(buyLabel, style: AppTextStyles.baloo(size: 15.5, color: Colors.white)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 4),
          TextButton(
            onPressed: onLater,
            child: Text('Maybe later', style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w700, color: AppColors.inkFaint)),
          ),
        ],
      ),
    );
  }
}

class _PaywallListItem extends StatelessWidget {
  const _PaywallListItem({required this.emoji, required this.text});
  final String emoji;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(emoji, style: const TextStyle(fontSize: 14)),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.4)),
        ),
      ],
    );
  }
}
