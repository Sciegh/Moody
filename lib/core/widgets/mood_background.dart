import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Reproduces:
/// ```css
/// background:
///   radial-gradient(circle at top center,    <spot1>, transparent 45%),
///   radial-gradient(circle at bottom center, <spot2>, transparent 45%),
///   var(--bg-1);
/// ```
///
/// This is meant to read as a *background* — an atmospheric wash that
/// tints the top and bottom of the screen — not as a floating colored
/// shape. Two things make it look like a blob if you're not careful:
///
/// 1. **Containing the gradient inside the screen.** If the circle's
///    center and radius both sit within the visible frame, you see its
///    entire silhouette — a soft-edged disk — which reads as an object
///    sitting on the background rather than as the background itself.
///    The fix (and what the source CSS actually does): put the circle's
///    *center* exactly on the top/bottom edge, and make it wide enough
///    that its left/right curvature falls off-screen. What's left inside
///    the frame is only the gradient's fade — a dome-shaped wash with no
///    visible left/right/top edge, only a fade at the bottom of the wash.
/// 2. **A visible plateau or hard stop.** A single smooth fade, held
///    strong near the origin edge and tapering out — no ring, no ledge.
///
/// Colors are additively blended (`BlendMode.plus`) where the top and
/// bottom washes overlap in the middle of the screen, so they merge into
/// a third color there instead of one flatly covering the other.
class MoodBackground extends StatelessWidget {
  const MoodBackground({
    super.key,
    required this.child,
    this.baseColor = AppColors.bg1,
    Color? spot1,
    Color? spot2,
    this.animate = false,
  })  : spot1 = spot1 ?? AppColors.bodyGradientSpot1,
        spot2 = spot2 ?? AppColors.bodyGradientSpot2;

  final Widget child;
  final Color baseColor;
  final Color spot1;
  final Color spot2;

  /// Profile/moodify-create (and now the whole app shell, since the mood
  /// accent is app-wide) animate the background over 0.7s whenever the
  /// accent changes (`transition: background 0.7s ease`). Login/Register
  /// have a static background, so leave this false there.
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final wash = _AnimatedWash(
      baseColor: baseColor,
      spot1: spot1,
      spot2: spot2,
      duration: animate ? const Duration(milliseconds: 700) : Duration.zero,
    );

    return Stack(
      fit: StackFit.expand,
      children: [wash, child],
    );
  }
}

/// Tweens both spot colors together so the wash cross-fades smoothly
/// whenever the mood accent changes, instead of snapping.
class _AnimatedWash extends ImplicitlyAnimatedWidget {
  const _AnimatedWash({
    required this.baseColor,
    required this.spot1,
    required this.spot2,
    required super.duration,
  }) : super(curve: Curves.easeInOut);

  final Color baseColor;
  final Color spot1;
  final Color spot2;

  @override
  ImplicitlyAnimatedWidgetState<_AnimatedWash> createState() => _AnimatedWashState();
}

class _AnimatedWashState extends ImplicitlyAnimatedWidgetState<_AnimatedWash> {
  ColorTween? _base;
  ColorTween? _spot1;
  ColorTween? _spot2;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _base = visitor(_base, widget.baseColor, (v) => ColorTween(begin: v as Color)) as ColorTween?;
    _spot1 = visitor(_spot1, widget.spot1, (v) => ColorTween(begin: v as Color)) as ColorTween?;
    _spot2 = visitor(_spot2, widget.spot2, (v) => ColorTween(begin: v as Color)) as ColorTween?;
  }

  @override
  Widget build(BuildContext context) {
    // RepaintBoundary matters here specifically because this painter uses
    // `saveLayer` + `BlendMode.plus` (see _WashPainter.paint) to blend the
    // two washes together. Without its own compositing layer, that
    // saveLayer gets folded into whatever layer the *parent* is currently
    // compositing — and a paywall/audience bottom sheet opening or
    // closing (or its drag-to-dismiss) puts this widget's ancestor
    // through exactly that kind of transient re-compositing. That's the
    // likely source of the black-screen-on-dismiss: a saveLayer with a
    // non-default blend mode momentarily composited against an
    // unexpected backdrop renders black instead of the intended wash for
    // a frame or two. Giving this its own boundary/layer means the sheet
    // opening or closing never touches how this paints.
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) => CustomPaint(
          painter: _WashPainter(
            baseColor: _base!.evaluate(animation)!,
            spot1: _spot1!.evaluate(animation)!,
            spot2: _spot2!.evaluate(animation)!,
          ),
        ),
      ),
    );
  }
}

class _WashPainter extends CustomPainter {
  _WashPainter({required this.baseColor, required this.spot1, required this.spot2});

  final Color baseColor;
  final Color spot1;
  final Color spot2;

  void _paintWash(Canvas canvas, Size size, Offset edgeCenter, Color color) {
    // Oversized relative to the screen and centered ON the edge, so only
    // the fade is ever visible — no curved silhouette, no floating shape.
    final radius = size.width * 1.1;
    final rect = Rect.fromCircle(center: edgeCenter, radius: radius);

    final shader = RadialGradient(
      // Held strong through the first third of the radius, then a long
      // smooth taper — reads as a deep wash of color, not a thin ring.
      colors: [color, color, color.withOpacity(0)],
      stops: const [0.0, 0.3, 1.0],
    ).createShader(rect);

    final paint = Paint()
      ..shader = shader
      ..blendMode = BlendMode.plus; // overlap merges rather than covers

    canvas.drawRect(Offset.zero & size, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = baseColor);

    // saveLayer scopes the additive blending to just these two washes
    // (against each other), not the base color or anything painted later.
    canvas.saveLayer(Offset.zero & size, Paint());
    _paintWash(canvas, size, Offset(size.width / 2, 0), spot1);
    _paintWash(canvas, size, Offset(size.width / 2, size.height), spot2);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WashPainter oldDelegate) {
    return oldDelegate.baseColor != baseColor || oldDelegate.spot1 != spot1 || oldDelegate.spot2 != spot2;
  }
}