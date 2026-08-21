import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';

class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.emoji,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool danger;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
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
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: AppColors.line, offset: Offset(0, _pressed ? 1 : 3)),
          ],
        ),
        child: Row(
          children: [
            SizedBox(width: 22, child: Text(widget.emoji, style: const TextStyle(fontSize: 17))),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                widget.label,
                style: AppTextStyles.quicksand(
                  size: 13.5,
                  weight: FontWeight.w700,
                  color: widget.danger ? AppColors.coralDark : AppColors.ink,
                ),
              ),
            ),
            const Text('›', style: TextStyle(color: AppColors.inkFaint, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class SettingsList extends StatelessWidget {
  const SettingsList({
    super.key,
    required this.onNotifications,
    required this.onPrivacy,
    required this.onAccountDetails,
    required this.onHelpSupport,
    required this.onLogout,
  });

  final VoidCallback onNotifications;
  final VoidCallback onPrivacy;
  final VoidCallback onAccountDetails;
  final VoidCallback onHelpSupport;
  final VoidCallback onLogout;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingsRow(emoji: '🔔', label: 'Notifications', onTap: onNotifications),
        const SizedBox(height: 8),
        SettingsRow(emoji: '🔒', label: 'Privacy', onTap: onPrivacy),
        const SizedBox(height: 8),
        SettingsRow(emoji: '👤', label: 'Account details', onTap: onAccountDetails),
        const SizedBox(height: 8),
        SettingsRow(emoji: '💛', label: 'Help & support', onTap: onHelpSupport),
        const SizedBox(height: 8),
        SettingsRow(emoji: '🚪', label: 'Log out', onTap: onLogout, danger: true),
      ],
    );
  }
}
