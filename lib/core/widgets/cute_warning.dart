import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// A friendly, on-brand warning dialog — used anywhere the app needs to
/// stop the user and say "not quite yet" (empty required fields, a locked
/// Deluxe mood, etc.) without breaking the soft/playful Moodify tone with
/// a stock system [AlertDialog].
///
/// Returns `true` if the user tapped [confirmLabel] (when provided),
/// otherwise `false`/`null` if they dismissed it.
Future<bool?> showCuteWarning(
  BuildContext context, {
  required String emoji,
  required String title,
  required String message,
  String dismissLabel = 'Got it',
  String? confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (context) => Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32),
      child: Container(
        padding: const EdgeInsets.fromLTRB(22, 22, 22, 16),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(28),
          boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 6), blurRadius: 0)],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 56,
              height: 56,
              alignment: Alignment.center,
              decoration: const BoxDecoration(color: AppColors.paperSoft, shape: BoxShape.circle),
              child: Text(emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 14),
            Text(title, textAlign: TextAlign.center, style: AppTextStyles.baloo(size: 17)),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.4),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                if (confirmLabel != null) ...[
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.paperSoft,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(dismissLabel, style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: Text(confirmLabel, style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
                ] else
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: Text(dismissLabel, style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w800, color: Colors.white)),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
