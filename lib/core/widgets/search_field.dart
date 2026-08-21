import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// `.search-wrap` — a rounded search pill used on Help & support,
/// Friends, and Add friends.
class AppSearchField extends StatelessWidget {
  const AppSearchField({
    super.key,
    required this.controller,
    required this.placeholder,
    this.onChanged,
  });

  final TextEditingController controller;
  final String placeholder;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(20),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          const Text('🔎'),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              style: AppTextStyles.quicksand(size: 14, weight: FontWeight.w600),
              decoration: InputDecoration(
                border: InputBorder.none,
                isCollapsed: true,
                hintText: placeholder,
                hintStyle: AppTextStyles.quicksand(size: 14, weight: FontWeight.w600, color: AppColors.inkFaint),
                contentPadding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
