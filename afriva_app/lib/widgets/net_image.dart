import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:material_ui/material_ui.dart';

import '../core/config.dart';
import '../core/theme.dart';

/// Cached network image with an on-brand placeholder and error fallback.
class NetImage extends StatelessWidget {
  const NetImage(
    this.url, {
    super.key,
    this.fit = BoxFit.cover,
    this.width,
    this.height,
    this.memCacheWidth,
    this.alignment = Alignment.center,
  });

  final String? url;
  final BoxFit fit;
  final double? width;
  final double? height;
  final int? memCacheWidth;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final resolved = AppConfig.resolveUrl(url);
    if (resolved.isEmpty) return _fallback();
    // On web, hosts without CORS headers can't be decoded by CanvasKit, so let
    // Flutter fall back to a plain <img> element for those.
    if (kIsWeb) {
      return Image.network(
        resolved,
        fit: fit,
        width: width,
        height: height,
        alignment: alignment,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
        frameBuilder: (_, child, frame, _) =>
            frame == null ? Container(color: AppColors.surface2) : child,
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    return CachedNetworkImage(
      imageUrl: resolved,
      fit: fit,
      width: width,
      height: height,
      alignment: alignment,
      memCacheWidth: memCacheWidth,
      fadeInDuration: AppMotion.slow,
      fadeOutDuration: AppMotion.fast,
      placeholder: (_, _) => Container(color: AppColors.surface2),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface2, AppColors.surface],
          ),
        ),
        alignment: Alignment.center,
        child: const Icon(Icons.movie_filter_rounded, color: AppColors.textDim, size: 28),
      );
}
