import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import '../theme/app_text_theme.dart';

/// `.save-toast` / `.toast` — a dark pill that fades/slides in at the
/// bottom of the screen and auto-dismisses.
///
/// Source used two slightly different positions (`bottom:20px` for the
/// settings screens, `bottom:88px` on Friends to clear the tab bar) — pass
/// [bottomOffset] to match.
class SaveToastController extends ChangeNotifier {
  String _message = '';
  bool _visible = false;
  Timer? _timer;

  String get message => _message;
  bool get visible => _visible;

  void show(String message, {Duration duration = const Duration(milliseconds: 1400)}) {
    _message = message;
    _visible = true;
    notifyListeners();
    _timer?.cancel();
    _timer = Timer(duration, () {
      _visible = false;
      notifyListeners();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

class SaveToast extends StatelessWidget {
  const SaveToast({super.key, required this.controller, this.bottomOffset = 20});

  final SaveToastController controller;
  final double bottomOffset;

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Positioned(
          left: 20,
          right: 20,
          bottom: bottomOffset,
          child: IgnorePointer(
            child: AnimatedSlide(
              duration: const Duration(milliseconds: 250),
              offset: controller.visible ? Offset.zero : const Offset(0, 0.3),
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: controller.visible ? 1 : 0,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  decoration: BoxDecoration(color: AppColors.ink, borderRadius: BorderRadius.circular(16)),
                  child: Text(
                    controller.message,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w700, color: Colors.white),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
