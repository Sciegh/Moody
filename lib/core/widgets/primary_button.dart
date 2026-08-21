import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// `.primary-btn` — a "squishy" button: a solid drop shadow that collapses
/// and the button shifts down 4px on press.
/// ```css
/// box-shadow: 0 5px 0 var(--coral-dark), 0 10px 18px -6px rgba(226,78,116,.45);
/// transition: transform .12s ease, box-shadow .12s ease;
/// &:active { transform: translateY(4px); box-shadow: 0 1px 0 var(--coral-dark); }
/// ```
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.color = AppColors.coral,
    this.colorDark = AppColors.coralDark,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color color;
  final Color colorDark;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (widget.onPressed == null) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      enabled: widget.onPressed != null,
      label: widget.label,
      child: GestureDetector(
        onTapDown: (_) => _setPressed(true),
        onTapUp: (_) => _setPressed(false),
        onTapCancel: () => _setPressed(false),
        onTap: widget.onPressed,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 15),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [widget.color, widget.colorDark],
            ),
            boxShadow: _pressed
                ? [BoxShadow(color: widget.colorDark, offset: const Offset(0, 1))]
                : [
                    BoxShadow(color: widget.colorDark, offset: const Offset(0, 5)),
                    BoxShadow(
                      color: widget.colorDark.withValues(alpha: 0.45),
                      offset: const Offset(0, 10),
                      blurRadius: 18,
                    ),
                  ],
          ),
          child: Text(
            widget.label,
            style: AppTextStyles.baloo(size: 16, color: Colors.white),
          ),
        ),
      ),
    );
  }
}
