import 'dart:ui' as ui;

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
            frame == null ? Container(color: AppColors.surface) : child,
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
      placeholder: (_, _) => Container(color: AppColors.surface),
      errorWidget: (_, _, _) => _fallback(),
    );
  }

  Widget _fallback() => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [AppColors.surface2, AppColors.surface],
          ),
        ),
        alignment: Alignment.center,
        child: Icon(Icons.movie_filter_rounded, color: AppColors.textDim, size: 28),
      );
}

/// Saturation matrix (CSS `saturate()`).
List<double> _saturate(double s) {
  const r = 0.2126, g = 0.7152, b = 0.0722;
  final k = 1 - s;
  return [
    r * k + s, g * k, b * k, 0, 0,
    r * k, g * k + s, b * k, 0, 0,
    r * k, g * k, b * k + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

final _saturate150 = ColorFilter.matrix(_saturate(1.5));

/// The poster blown up, blurred and saturated: the soft colour wash taken
/// from the artwork behind heroes and the player. Decodes a small image and
/// repaints on its own, so it stays cheap while the page scrolls.
class PosterWash extends StatelessWidget {
  const PosterWash(this.url, {super.key, this.opacity = 1, this.cacheWidth = 200});
  final String url;
  final double opacity;
  final int cacheWidth;

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
        child: RepaintBoundary(
          child: ClipRect(
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(
                scale: 1.25,
                child: ColorFiltered(
                  colorFilter: _saturate150,
                  child: ImageFiltered(
                    imageFilter: ui.ImageFilter.blur(sigmaX: 30, sigmaY: 30),
                    child: NetImage(url, memCacheWidth: cacheWidth),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
}
