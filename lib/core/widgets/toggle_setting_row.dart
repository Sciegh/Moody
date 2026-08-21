import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';
import 'app_toggle.dart';

/// `.setting-row` containing a `.toggle` — shared by Notifications and
/// Privacy so both screens style identically.
class ToggleSettingRow extends StatelessWidget {
  const ToggleSettingRow({
    super.key,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.activeColor = AppColors.coral,
  });

  final String emoji;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          SizedBox(width: 22, child: Text(emoji, style: const TextStyle(fontSize: 17))),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: AppColors.inkFaint)),
              ],
            ),
          ),
          AppToggle(value: value, onChanged: onChanged, activeColor: activeColor),
        ],
      ),
    );
  }
}
