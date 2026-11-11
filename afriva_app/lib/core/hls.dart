import 'package:dio/dio.dart';

import 'video_source.dart';

/// One rendition listed in an HLS master playlist.
class HlsVariant {
  const HlsVariant({required this.height, required this.uri, this.bandwidth = 0});

  /// Quality in "p" (e.g. 720), from the rendition path or the shorter side
  /// of its RESOLUTION.
  final int height;
  final String uri;
  final int bandwidth;

  String get label => '${height}p';
}

final _resolution = RegExp(r'RESOLUTION=(\d+)x(\d+)', caseSensitive: false);
final _bandwidth = RegExp(r'(?:^|[:,])BANDWIDTH=(\d+)', caseSensitive: false);
final _pathQuality = RegExp(r'(?:^|/)(\d{3,4})p(?:/|\.|$)', caseSensitive: false);

/// Parses `#EXT-X-STREAM-INF` entries, highest quality first. Duplicate
/// heights keep the higher bandwidth entry.
List<HlsVariant> parseHlsMaster(String body) {
  final lines = body.split(RegExp(r'\r?\n')).map((l) => l.trim()).toList();
  final byHeight = <int, HlsVariant>{};
  for (var i = 0; i < lines.length; i++) {
    final line = lines[i];
    if (!line.toUpperCase().startsWith('#EXT-X-STREAM-INF')) continue;
    var j = i + 1;
    while (j < lines.length && (lines[j].isEmpty || lines[j].startsWith('#'))) {
      j++;
    }
    if (j >= lines.length) break;
    final uri = lines[j];
    final res = _resolution.firstMatch(line);
    final fromPath = _pathQuality.firstMatch(uri);
    final height = fromPath != null
        ? int.parse(fromPath.group(1)!)
        : res != null
            ? [int.parse(res.group(1)!), int.parse(res.group(2)!)].reduce((a, b) => a < b ? a : b)
            : 0;
    if (height <= 0) continue;
    final v = HlsVariant(
      height: height,
      uri: uri,
      bandwidth: int.tryParse(_bandwidth.firstMatch(line)?.group(1) ?? '') ?? 0,
    );
    final prev = byHeight[height];
    if (prev == null || v.bandwidth > prev.bandwidth) byHeight[height] = v;
  }
  return byHeight.values.toList()..sort((a, b) => b.height.compareTo(a.height));
}

/// Resolves a variant [uri] against the signed [masterUrl] by plain string
/// surgery, so path-embedded tokens (e.g. `bcdn_token=...&token_path=%2F...`)
/// are kept byte for byte. A query on the master is carried over.
String resolveVariantUrl(String masterUrl, String uri) {
  if (uri.startsWith('http://') || uri.startsWith('https://')) return uri;
  final q = masterUrl.indexOf('?');
  final path = q < 0 ? masterUrl : masterUrl.substring(0, q);
  final query = q < 0 ? '' : masterUrl.substring(q);
  final base = uri.startsWith('/') ? Uri.parse(path).origin : path.substring(0, path.lastIndexOf('/') + 1);
  final joined = '$base$uri';
  return uri.contains('?') || query.isEmpty ? joined : '$joined$query';
}

/// Picks the rendition for a preferred [quality] (0 = Auto): the exact
/// height, else the closest lower one, else the lowest available.
HlsVariant? pickVariant(List<HlsVariant> variants, int quality) {
  if (quality <= 0 || variants.isEmpty) return null;
  for (final v in variants) {
    if (v.height <= quality) return v;
  }
  return variants.last;
}

final _cache = <String, List<HlsVariant>>{};
final _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 8),
  receiveTimeout: const Duration(seconds: 8),
  responseType: ResponseType.plain,
));

/// Renditions of an HLS master [url]; empty for non-HLS URLs or on errors.
Future<List<HlsVariant>> fetchHlsVariants(String url) async {
  if (!isHlsUrl(url)) return const [];
  final hit = _cache[url];
  if (hit != null) return hit;
  try {
    final res = await _dio.get<String>(url);
    final variants = parseHlsMaster(res.data ?? '');
    if (_cache.length > 40) _cache.clear();
    _cache[url] = variants;
    return variants;
  } catch (_) {
    return const [];
  }
}

/// The URL to play for a preferred [quality]: the matching variant, or the
/// master itself for Auto / non-HLS / unknown renditions.
Future<String> urlForQuality(String masterUrl, int quality) async {
  if (quality <= 0) return masterUrl;
  final v = pickVariant(await fetchHlsVariants(masterUrl), quality);
  return v == null ? masterUrl : resolveVariantUrl(masterUrl, v.uri);
}
