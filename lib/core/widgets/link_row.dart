import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// `.link-row` — a full-width tappable row that navigates somewhere,
/// optionally with a small pill [badge] (e.g. blocked-accounts count).
class LinkRow extends StatefulWidget {
  const LinkRow({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.badge,
    this.badgeColor = AppColors.lilac,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final String? badge;
  final Color badgeColor;

  @override
  State<LinkRow> createState() => _LinkRowState();
}

class _LinkRowState extends State<LinkRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: AppColors.line, offset: Offset(0, _pressed ? 1 : 3))],
        ),
        child: Row(
          children: [
            SizedBox(width: 22, child: Text(widget.emoji, style: const TextStyle(fontSize: 17))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(widget.label, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
            ),
            if (widget.badge != null)
              Container(
                margin: const EdgeInsets.only(right: 2),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(color: widget.badgeColor, borderRadius: BorderRadius.circular(10)),
                child: Text(
                  widget.badge!,
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w800),
                ),
              ),
            const Text('›', style: TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}
