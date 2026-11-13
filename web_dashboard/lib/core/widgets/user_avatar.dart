import 'dart:convert';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class UserAvatar extends StatelessWidget {
  final String? photoUrl;
  final String initials;
  final double radius;
  final Color? backgroundColor;
  final Color textColor;
  final double? fontSize;

  const UserAvatar({
    super.key,
    required this.photoUrl,
    required this.initials,
    this.radius = 18,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.fontSize,
  });

  static final Map<String, ImageProvider> _providerCache = {};

  ImageProvider? _resolveImageProvider() {
    if (photoUrl == null || photoUrl!.trim().isEmpty) return null;
    final url = photoUrl!.trim();
    if (_providerCache.containsKey(url)) {
      return _providerCache[url];
    }

    try {
      if (url.startsWith('data:image')) {
        final commaIndex = url.indexOf(',');
        if (commaIndex != -1) {
          final base64Str = url.substring(commaIndex + 1);
          final bytes = base64Decode(base64Str);
          if (bytes.isNotEmpty) {
            final provider = MemoryImage(bytes);
            if (_providerCache.length > 200) {
              _providerCache.remove(_providerCache.keys.first);
            }
            _providerCache[url] = provider;
            return provider;
          }
        }
      } else if (url.startsWith('http://') || url.startsWith('https://')) {
        final provider = NetworkImage(url);
        if (_providerCache.length > 200) {
          _providerCache.remove(_providerCache.keys.first);
        }
        _providerCache[url] = provider;
        return provider;
      }
    } catch (_) {}

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final imageProvider = _resolveImageProvider();
    final effectiveBgColor = backgroundColor ?? AppColors.primaryNavy;
    final effectiveFontSize = fontSize ?? (radius * 0.75);
    final diameter = radius * 2;

    Widget fallbackText() => Center(
          child: Text(
            initials.isNotEmpty ? initials : '?',
            style: TextStyle(
              fontSize: effectiveFontSize,
              fontWeight: FontWeight.bold,
              color: textColor,
            ),
          ),
        );

    if (imageProvider != null) {
      return Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: effectiveBgColor,
        ),
        clipBehavior: Clip.antiAlias,
        child: Image(
          image: imageProvider,
          fit: BoxFit.cover,
          gaplessPlayback: true,
          errorBuilder: (context, error, stackTrace) => fallbackText(),
        ),
      );
    }

    return Container(
      width: diameter,
      height: diameter,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: effectiveBgColor,
      ),
      child: fallbackText(),
    );
  }
}
