import 'package:flutter/material.dart';
import '../theme/app_text_theme.dart';
import 'circle_icon_button.dart';

/// `.top-bar` used by Notifications/Privacy/Account details/Help & support:
/// a back arrow + page title. [subtitle] supports the Friends/Add-friend
/// variant, which puts a second line under the h1 instead of a back arrow
/// immediately next to it.
class DetailTopBar extends StatelessWidget {
  const DetailTopBar({
    super.key,
    required this.title,
    required this.onBack,
    this.subtitle,
    this.trailing,
    this.backIcon = Icons.arrow_back,
  });

  final String title;
  final VoidCallback onBack;
  final String? subtitle;
  final Widget? trailing;
  final IconData backIcon;

  @override
  Widget build(BuildContext context) {
    if (trailing != null) {
      // Friends/Add-friend layout: title block on the left, an action
      // button (add / back) on the right.
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: AppTextStyles.baloo(size: 22)),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(subtitle!, style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600)),
                  ],
                ],
              ),
            ),
            trailing!,
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
      child: Row(
        children: [
          CircleIconButton(
            semanticLabel: 'Back to profile', 
            onPressed: onBack, 
            child: Icon(backIcon, color: Colors.black),
          ),
          const SizedBox(width: 10),
          Text(title, style: AppTextStyles.baloo(size: 19)),
        ],
      ),
    );
  }
}
