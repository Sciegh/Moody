import 'dart:math';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../create_controller.dart';

const _kConfettiColors = [
  AppColors.coral,
  Color(0xFFFFA65C),
  AppColors.marigold,
  AppColors.sky,
  AppColors.mint,
  AppColors.lilac,
];

/// `#successOverlay` + `.confetti` / `burstConfetti()`.
class SuccessOverlay extends StatefulWidget {
  const SuccessOverlay({super.key, required this.accent, required this.text, required this.onDone});

  final ComposerAccent accent;
  final String text;
  final VoidCallback onDone;

  @override
  State<SuccessOverlay> createState() => _SuccessOverlayState();
}

class _ConfettiPiece {
  _ConfettiPiece(Random r)
      : left = r.nextDouble(),
        width = 5 + r.nextDouble() * 5,
        color = _kConfettiColors[r.nextInt(_kConfettiColors.length)],
        durationMs = 1400 + r.nextInt(1200),
        delayMs = r.nextInt(400);

  final double left;
  final double width;
  final Color color;
  final int durationMs;
  final int delayMs;
}

class _SuccessOverlayState extends State<SuccessOverlay> with SingleTickerProviderStateMixin {
  late final List<_ConfettiPiece> _pieces;
  late final AnimationController _checkController;

  @override
  void initState() {
    super.initState();
    final r = Random();
    _pieces = List.generate(26, (_) => _ConfettiPiece(r));
    _checkController = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))..forward();
  }

  @override
  void dispose() {
    _checkController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(widget.accent.accentLight, AppColors.bg1, 0.45)!,
            AppColors.bg1,
            Color.lerp(widget.accent.accent, AppColors.bg1, 0.84)!,
          ],
        ),
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  clipBehavior: Clip.none,
                  children: _pieces.map((p) => _FallingConfetti(piece: p, areaSize: constraints.biggest)).toList(),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ScaleTransition(
                  scale: CurvedAnimation(parent: _checkController, curve: Curves.elasticOut),
                  child: Container(
                    width: 82,
                    height: 82,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        center: const Alignment(-0.36, -0.44),
                        colors: [widget.accent.accentLight, widget.accent.accent, widget.accent.accentDark],
                      ),
                      boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), offset: const Offset(0, 10), blurRadius: 20)],
                    ),
                    child: const Text('✓', style: TextStyle(fontSize: 36, color: Colors.white, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(height: 14),
                Text('Moodify sent!', style: AppTextStyles.baloo(size: 21)),
                const SizedBox(height: 8),
                Text(
                  widget.text,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
                ),
                const SizedBox(height: 10),
                TextButton(
                  onPressed: widget.onDone,
                  child: Text('Done', style: AppTextStyles.baloo(size: 14, color: AppColors.coralDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _FallingConfetti extends StatefulWidget {
  const _FallingConfetti({required this.piece, required this.areaSize});
  final _ConfettiPiece piece;
  final Size areaSize;

  @override
  State<_FallingConfetti> createState() => _FallingConfettiState();
}

class _FallingConfettiState extends State<_FallingConfetti> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: Duration(milliseconds: widget.piece.durationMs));
    Future.delayed(Duration(milliseconds: widget.piece.delayMs), () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeIn.transform(_controller.value);
        final dy = -0.1 * widget.areaSize.height + t * 1.3 * widget.areaSize.height;
        final opacity = t < 0.85 ? 1.0 : (1 - (t - 0.85) / 0.15) * 0.7 + 0.3;
        return Positioned(
          left: widget.piece.left * widget.areaSize.width,
          top: dy,
          child: Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Transform.rotate(
              angle: t * 2 * pi,
              child: Container(
                width: widget.piece.width,
                height: widget.piece.width * 0.6,
                decoration: BoxDecoration(color: widget.piece.color, borderRadius: BorderRadius.circular(1.5)),
              ),
            ),
          ),
        );
      },
    );
  }
}
