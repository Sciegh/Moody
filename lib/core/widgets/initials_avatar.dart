import 'package:flutter/material.dart';

const kAvatarColors = <Color>[
  Color(0xFFFF6F91),
  Color(0xFF4FB9E8),
  Color(0xFF3FCE9A),
  Color(0xFFB084E0),
  Color(0xFFFFA65C),
  Color(0xFFFFC24B),
  Color(0xFF6FA8DC),
  Color(0xFFF4845F),
];

String initialsFor(String name) =>
    name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).map((p) => p[0]).join();

/// `.avatar` — a solid-color circle with the person's initials, cycling
/// through `AVATAR_COLORS` by index the same way the source script does.
class InitialsAvatar extends StatelessWidget {
  const InitialsAvatar({super.key, required this.name, required this.colorIndex, this.size = 44});

  final String name;
  final int colorIndex;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kAvatarColors[colorIndex % kAvatarColors.length],
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.12), blurRadius: 6, offset: const Offset(0, 2))],
      ),
      child: Text(
        initialsFor(name),
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: size * 0.32),
      ),
    );
  }
}
