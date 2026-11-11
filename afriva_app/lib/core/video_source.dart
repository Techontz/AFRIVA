import 'package:video_player/video_player.dart';

final _hlsPattern = RegExp(r'\.m3u8(?:$|[?#/&])', caseSensitive: false);

/// True for HLS playlists, including signed CDN URLs where `.m3u8` is not at
/// the end (e.g. `.../playlist.m3u8?token=...` or `.../playlist.m3u8/token`).
bool isHlsUrl(String url) => _hlsPattern.hasMatch(url);

/// Builds a network controller for [url], hinting HLS explicitly so
/// ExoPlayer (Android) picks its HLS source even when the URL does not end in
/// `.m3u8`. AVPlayer (iOS) plays HLS natively either way.
VideoPlayerController networkVideoController(
  String url, {
  VideoPlayerOptions? options,
}) =>
    VideoPlayerController.networkUrl(
      Uri.parse(url),
      formatHint: isHlsUrl(url) ? VideoFormat.hls : null,
      videoPlayerOptions: options,
    );
