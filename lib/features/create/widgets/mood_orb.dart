import 'package:flutter/material.dart';

/// `.orb` + `.orb.family-*` — a soft blob whose motion style changes by
/// mood family (`blobCalm`/`blobEnergetic`/`blobHeavy`/`blobAnxious`/`blobSocial`).
///
/// The source additionally morphs the blob's asymmetric `border-radius`
/// through several keyframe states per family. That per-family radius
/// morphing isn't reproduced here — only the scale/rotate/translate motion
/// is — since Flutter's `BorderRadius` can't tween between independent
/// per-corner elliptical values as cheaply as CSS custom easing can. The
/// base asymmetric shape (from `MascotBlob`'s approach) is kept static.
/// Documented as an approximation in MIGRATION_NOTES.md.
class MoodOrb extends StatefulWidget {
  const MoodOrb({super.key, required this.emoji, required this.family, required this.gradientColors});

  final String emoji;
  final String family; // 'calm' | 'energetic' | 'heavy' | 'anxious' | 'social'
  final List<Color> gradientColors;

  @override
  State<MoodOrb> createState() => _MoodOrbState();
}

class _MoodOrbState extends State<MoodOrb> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  Duration get _duration => switch (widget.family) {
        'energetic' => const Duration(milliseconds: 2200),
        'heavy' => const Duration(milliseconds: 5500),
        'anxious' => const Duration(milliseconds: 2600),
        'social' => const Duration(milliseconds: 2800),
        _ => const Duration(milliseconds: 5000), // calm
      };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duration)..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant MoodOrb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.family != widget.family) {
      _controller.duration = _duration;
      _controller
        ..reset()
        ..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 208,
      height: 208,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // `.orb-wrap::after` — the soft blurred halo behind the orb.
          Container(
            width: 190,
            height: 190,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [widget.gradientColors.first.withValues(alpha: 0.55), Colors.transparent]),
            ),
          ),
          AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              final t = Curves.easeInOut.transform(_controller.value);
              double scale = 1;
              double angle = 0;
              Offset offset = Offset.zero;
              switch (widget.family) {
                case 'energetic':
                  scale = 1 + 0.12 * t;
                  angle = (7 - 13 * t) * (3.14159 / 180);
                case 'heavy':
                  scale = 1 - 0.02 * t;
                  offset = Offset(0, 6 * t);
                case 'anxious':
                  scale = 1 + 0.02 * (t - 0.5);
                  offset = Offset(4 * (0.5 - t), 3 * (t - 0.5));
                  angle = (3 - 6 * t) * (3.14159 / 180);
                case 'social':
                  offset = Offset(0, -10 * t);
                  angle = (6 * t) * (3.14159 / 180);
                default: // calm
                  scale = 1 + 0.05 * t;
              }
              return Transform.translate(
                offset: offset,
                child: Transform.rotate(
                  angle: angle,
                  child: Transform.scale(scale: scale, child: child),
                ),
              );
            },
            child: Container(
              width: 176,
              height: 176,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.elliptical(176 * 0.42, 176 * 0.45),
                  topRight: Radius.elliptical(176 * 0.58, 176 * 0.45),
                  bottomRight: Radius.elliptical(176 * 0.65, 176 * 0.55),
                  bottomLeft: Radius.elliptical(176 * 0.35, 176 * 0.55),
                ),
                gradient: RadialGradient(
                  center: const Alignment(-0.36, -0.44),
                  colors: widget.gradientColors,
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.22), offset: const Offset(0, 12), blurRadius: 24),
                ],
              ),
              child: Text(widget.emoji, style: const TextStyle(fontSize: 62)),
            ),
          ),
        ],
      ),
    );
  }
}
