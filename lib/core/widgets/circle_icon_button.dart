import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Shared shape behind `.icon-btn`, `.social-btn`, and `.edit-badge`:
/// a white circle with a flat "pressed edge" shadow that collapses on tap.
class CircleIconButton extends StatefulWidget {
  const CircleIconButton({
    super.key,
    required this.child,
    required this.onPressed,
    required this.semanticLabel,
    this.size = 38,
    this.fontSize = 15,
  });

  final Widget child;
  final VoidCallback? onPressed;
  final String semanticLabel;
  final double size;
  final double fontSize;

  @override
  State<CircleIconButton> createState() => _CircleIconButtonState();
}

class _CircleIconButtonState extends State<CircleIconButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    // Enlarges the tappable area to a ~44dp minimum without changing the
    // widget's layout footprint. This button is used inside
    // `Positioned(bottom: -2, right: -2, ...)` for corner badges (the
    // edit-avatar pencil) — real Padding around the content would grow
    // the box Positioned measures from and visibly shift the badge away
    // from the avatar's corner. OverflowBox keeps the reported size at
    // widget.size (so Positioned/Align placement is unaffected) while
    // letting its child — and therefore hit-testing — extend symmetrically
    // beyond those bounds.
    const minTapTarget = 44.0;
    final tapSize = widget.size < minTapTarget ? minTapTarget : widget.size;
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: SizedBox(
        width: widget.size,
        height: widget.size,
        child: OverflowBox(
          minWidth: tapSize,
          minHeight: tapSize,
          maxWidth: tapSize,
          maxHeight: tapSize,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (_) => setState(() => _pressed = true),
            onTapUp: (_) => setState(() => _pressed = false),
            onTapCancel: () => setState(() => _pressed = false),
            onTap: widget.onPressed,
            child: Center(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
                width: widget.size,
                height: widget.size,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.paper,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.line,
                      offset: Offset(0, _pressed ? 1 : 3),
                    ),
                  ],
                ),
                child: DefaultTextStyle(
                  style: TextStyle(fontSize: widget.fontSize),
                  child: widget.child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}