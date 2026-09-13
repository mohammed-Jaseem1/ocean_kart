import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

/// A robust, cached image widget supporting both network URLs (via CachedNetworkImage)
/// and Base64 strings with in-memory Uint8List caching.
class CachedProductImage extends StatelessWidget {
  final String? imageSource;
  final double width;
  final double height;
  final BoxFit fit;
  final BorderRadius? borderRadius;
  final IconData defaultIcon;

  // In-memory cache for decoded base64 bytes to eliminate re-decoding lag
  static final Map<String, Uint8List> _base64Cache = {};

  const CachedProductImage({
    super.key,
    required this.imageSource,
    this.width = 76,
    this.height = 76,
    this.fit = BoxFit.cover,
    this.borderRadius,
    this.defaultIcon = Icons.set_meal_outlined,
  });

  static String _cleanBase64(String input) {
    return input.replaceAll(RegExp(r'\s+'), '');
  }

  static Uint8List? _getOrDecodeBase64(String rawStr) {
    if (_base64Cache.containsKey(rawStr)) {
      return _base64Cache[rawStr];
    }
    try {
      final cleanStr = rawStr.contains('base64,') ? rawStr.split('base64,').last : rawStr;
      final bytes = base64Decode(_cleanBase64(cleanStr));
      // Limit memory cache size to 100 items if needed
      if (_base64Cache.length > 100) {
        _base64Cache.remove(_base64Cache.keys.first);
      }
      _base64Cache[rawStr] = bytes;
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final effectiveRadius = borderRadius ?? BorderRadius.circular(14);
    final src = imageSource?.trim();

    Widget placeholderWidget = Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: const Color(0xFFF1F5F9),
        borderRadius: effectiveRadius,
      ),
      child: Center(
        child: Icon(defaultIcon, color: const Color(0xFF64748B), size: width * 0.4),
      ),
    );

    if (src == null || src.isEmpty) {
      return placeholderWidget;
    }

    Widget content;

    if (src.startsWith('http://') || src.startsWith('https://')) {
      content = CachedNetworkImage(
        imageUrl: src,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => Container(
          width: width,
          height: height,
          color: const Color(0xFFF1F5F9),
          child: const Center(
            child: SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Color(0xFF00B4D8)),
            ),
          ),
        ),
        errorWidget: (context, url, error) => placeholderWidget,
      );
    } else {
      final bytes = _getOrDecodeBase64(src);
      if (bytes != null && bytes.isNotEmpty) {
        content = Image.memory(
          bytes,
          width: width,
          height: height,
          fit: fit,
          gaplessPlayback: true, // Prevents flicker during re-renders
          errorBuilder: (context, error, stackTrace) => placeholderWidget,
        );
      } else {
        content = placeholderWidget;
      }
    }

    return ClipRRect(
      borderRadius: effectiveRadius,
      child: content,
    );
  }
}
