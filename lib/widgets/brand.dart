import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// App mark: a rounded "E" tile plus the eMedia wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({super.key, this.size = 30, this.showText = true});
  final double size;
  final bool showText;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(size * 0.28),
            gradient: const LinearGradient(
              colors: [Color(0xFF4C8DFF), Color(0xFF34C759)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            'E',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: size * 0.55,
              height: 1,
            ),
          ),
        ),
        if (showText) ...[
          SizedBox(width: size * 0.35),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: 'eMedia',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: context.scheme.onSurface,
                  ),
                ),
                TextSpan(
                  text: ' Data',
                  style: TextStyle(
                    fontWeight: FontWeight.w400,
                    color: context.colors.muted,
                  ),
                ),
              ],
            ),
            style: TextStyle(fontSize: size * 0.58, letterSpacing: -0.3),
          ),
        ],
      ],
    );
  }
}

/// Circular avatar with initials, or a network image.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = 30,
  });
  final String name;
  final String? imageUrl;
  final double size;

  @override
  Widget build(BuildContext context) {
    final initials = name.trim().isEmpty
        ? '?'
        : name
              .trim()
              .split(RegExp(r'[\s._]+'))
              .where((s) => s.isNotEmpty)
              .take(2)
              .map((s) => s[0].toUpperCase())
              .join();
    return CircleAvatar(
      radius: size / 2,
      backgroundColor: context.colors.accentSoft,
      foregroundImage: imageUrl == null ? null : NetworkImage(imageUrl!),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          color: context.scheme.primary,
        ),
      ),
    );
  }
}
