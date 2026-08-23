import 'package:cached_network_image/cached_network_image.dart';
import '../theme/theme_context.dart';
import 'package:flutter/material.dart';


/// Safe network image with placeholder for empty/failed URLs.
class NetworkImageView extends StatelessWidget {
  const NetworkImageView({
    super.key,
    required this.url,
    this.fit = BoxFit.cover,
    this.placeholderIcon = Icons.image_outlined,
  });

  final String url;
  final BoxFit fit;
  final IconData placeholderIcon;

  @override
  Widget build(BuildContext context) {
    if (url.isEmpty) {
      return ColoredBox(
        color: context.colors.primary.withValues(alpha: 0.08),
        child: Icon(placeholderIcon, color: context.colors.primary, size: 40),
      );
    }
    return CachedNetworkImage(
      imageUrl: url,
      fit: fit,
      placeholder: (_, __) => Center(child: CircularProgressIndicator(strokeWidth: 2)),
      errorWidget: (_, __, ___) => ColoredBox(
        color: context.colors.primary.withValues(alpha: 0.08),
        child: Icon(placeholderIcon, color: context.colors.primary, size: 40),
      ),
    );
  }
}
