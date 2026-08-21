import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// `.field` + `.field-input` — a labeled pill input:
/// ```css
/// .field-input{ background:var(--paper); border-radius:18px; box-shadow:0 3px 0 var(--line); }
/// .field-input:focus-within{ box-shadow:0 3px 0 var(--coral); }
/// ```
/// The focus ring is a color swap on the bottom "pressed edge" shadow
/// rather than a Material outline, so this widget tracks focus itself
/// instead of using Flutter's default [TextField] decoration.
class PillTextField extends StatefulWidget {
  const PillTextField({
    super.key,
    required this.label,
    required this.emoji,
    required this.controller,
    this.placeholder,
    this.obscureText = false,
    this.keyboardType,
    this.trailing,
    this.autofillHints,
  });

  final String label;
  final String emoji;
  final TextEditingController controller;
  final String? placeholder;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Widget? trailing;
  final Iterable<String>? autofillHints;

  @override
  State<PillTextField> createState() => _PillTextFieldState();
}

class _PillTextFieldState extends State<PillTextField> {
  final _focusNode = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _focused = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Text(
            widget.label,
            style: AppTextStyles.quicksand(
              size: 12.5,
              weight: FontWeight.w700,
              color: AppColors.inkDim,
            ),
          ),
        ),
        AnimatedContainer(
          duration: const Duration(milliseconds: 120),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.paper,
            borderRadius: BorderRadius.circular(18),
            boxShadow: [
              BoxShadow(
                color: _focused ? AppColors.coral : AppColors.line,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 16)),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: widget.controller,
                  focusNode: _focusNode,
                  obscureText: widget.obscureText,
                  keyboardType: widget.keyboardType,
                  autofillHints: widget.autofillHints,
                  style: AppTextStyles.quicksand(size: 14.5, weight: FontWeight.w600),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    isCollapsed: true,
                    hintText: widget.placeholder,
                    hintStyle: AppTextStyles.quicksand(
                      size: 14.5,
                      weight: FontWeight.w600,
                      color: AppColors.inkFaint,
                    ),
                  ),
                ),
              ),
              if (widget.trailing != null) widget.trailing!,
            ],
          ),
        ),
      ],
    );
  }
}
