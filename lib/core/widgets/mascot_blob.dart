import 'package:flutter/material.dart';

/// `.mascot` / `.avatar-big` — a soft asymmetric blob that gently
/// bobs/wiggles/sways forever:
/// ```css
/// border-radius: 42% 58% 65% 35% / 45% 45% 55% 55%;
/// animation: bob 4.5s ease-in-out infinite; /* or wiggle / sway */
/// ```
/// True organic asymmetric border-radius isn't directly expressible with
/// [BorderRadius] (Flutter radii are symmetric per-corner but CSS's
/// slash syntax varies horizontal/vertical radius independently); this
/// widget approximates it with a [BorderRadius] built from the same eight
/// percentages, which is visually very close for a shape this size.
///
/// [motion] selects which of the three source keyframe animations to use.
class MascotBlob extends StatefulWidget {
  const MascotBlob({
    super.key,
    required this.emoji,
    required this.size,
    required this.gradientColors,
    this.motion = MascotMotion.bob,
  });

  final String emoji;
  final double size;
  final List<Color> gradientColors;
  final MascotMotion motion;

  @override
  State<MascotBlob> createState() => _MascotBlobState();
}

enum MascotMotion { bob, wiggle, sway }

class _MascotBlobState extends State<MascotBlob> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration => switch (widget.motion) {
        MascotMotion.bob => const Duration(milliseconds: 4500),
        MascotMotion.wiggle => const Duration(milliseconds: 3200),
        MascotMotion.sway => const Duration(milliseconds: 5000),
      };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)..repeat(reverse: true);
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
        final t = Curves.easeInOut.transform(_controller.value); // 0 -> 1
        double angle;
        Offset offset;
        switch (widget.motion) {
          case MascotMotion.bob:
            angle = (-2 + 4 * t) * (3.14159 / 180);
            offset = Offset(0, -8 * t);
          case MascotMotion.wiggle:
            angle = (-4 + 8 * t) * (3.14159 / 180);
            offset = Offset.zero;
          case MascotMotion.sway:
            angle = (-3 + 6 * t) * (3.14159 / 180);
            offset = Offset.zero;
        }
        return Transform.translate(
          offset: offset,
          child: Transform.rotate(angle: angle, child: child),
        );
      },
      child: Container(
        width: widget.size,
        height: widget.size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.only(
            topLeft: Radius.elliptical(widget.size * 0.42, widget.size * 0.45),
            topRight: Radius.elliptical(widget.size * 0.58, widget.size * 0.45),
            bottomRight: Radius.elliptical(widget.size * 0.65, widget.size * 0.55),
            bottomLeft: Radius.elliptical(widget.size * 0.35, widget.size * 0.55),
          ),
          gradient: RadialGradient(
            center: const Alignment(-0.36, -0.44), // circle at 32% 28%
            colors: widget.gradientColors,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.18),
              offset: const Offset(0, 10),
              blurRadius: 20,
            ),
          ],
        ),
        child: Text(widget.emoji, style: TextStyle(fontSize: widget.size * 0.4)),
      ),
    );
  }
}
