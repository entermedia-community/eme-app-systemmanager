import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';

import '../theme/app_theme.dart';

/// App mark: a rounded "E" tile plus the eMedia wordmark.
class BrandMark extends StatelessWidget {
  const BrandMark({
    super.key,
    this.size = 20,
    this.fontSize,
    this.showText = true,
    this.vertical = false,
  });
  final double size;
  final double? fontSize;
  final bool showText;
  final bool vertical;

  @override
  Widget build(BuildContext context) {
    return Flex(
      direction: vertical ? Axis.vertical : Axis.horizontal,
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(
          width: size * 4.7,
          height: size,
          child: SvgPicture.asset(
            'assets/icon/logo_dark.svg',
            width: size * 4.7,
            height: size,
          ),
        ),
        if (showText) ...[
          SizedBox(width: 6),
          Text(
            'Data Manager',
            style: TextStyle(
              fontWeight: FontWeight.w400,
              color: context.colors.muted,
              fontSize: fontSize ?? size * 1.2,
              letterSpacing: -0.3,
            ),
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
