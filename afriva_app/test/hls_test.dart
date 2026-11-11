import 'package:afriva_app/core/hls.dart';
import 'package:afriva_app/models/episode.dart';
import 'package:flutter_test/flutter_test.dart';

// Shape of the master playlist the CDN serves for an episode.
const _master = '''#EXTM3U
#EXT-X-VERSION:3

#EXT-X-STREAM-INF:BANDWIDTH=913304,AVERAGE-BANDWIDTH=801406,CODECS="avc1.64001e,mp4a.40.2",RESOLUTION=360x640,CLOSED-CAPTIONS=NONE
360p/video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=1376536,AVERAGE-BANDWIDTH=1203576,CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=480x854,CLOSED-CAPTIONS=NONE
480p/video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=2488368,AVERAGE-BANDWIDTH=2145155,CODECS="avc1.64001f,mp4a.40.2",RESOLUTION=720x1280,CLOSED-CAPTIONS=NONE
720p/video.m3u8
#EXT-X-STREAM-INF:BANDWIDTH=445560,AVERAGE-BANDWIDTH=394348,CODECS="avc1.64000d,mp4a.40.2",RESOLUTION=198x352,CLOSED-CAPTIONS=NONE
240p/video.m3u8
''';

const _signed = 'https://vz-1.b-cdn.net/bcdn_token=HS256-abc&token_path=%2Fguid%2F&expires=1793412264/guid/playlist.m3u8';

void main() {
  test('parses renditions highest first with path labels', () {
    final v = parseHlsMaster(_master);
    expect(v.map((e) => e.label), ['720p', '480p', '360p', '240p']);
    expect(v.first.uri, '720p/video.m3u8');
    expect(v.first.bandwidth, 2488368);
  });

  test('falls back to the shorter side of RESOLUTION', () {
    final v = parseHlsMaster('#EXTM3U\n#EXT-X-STREAM-INF:BANDWIDTH=5000000,RESOLUTION=1920x1080\nhd/index.m3u8\n'
        '#EXT-X-STREAM-INF:BANDWIDTH=900000,RESOLUTION=1080x1920\r\nlow.m3u8\n#EXT-X-ENDLIST');
    expect(v.single.height, 1080);
    expect(v.single.uri, 'hd/index.m3u8');
    expect(parseHlsMaster('#EXTM3U\n#EXTINF:4,\nseg0.ts\n'), isEmpty);
  });

  test('variant URL keeps the path token byte for byte', () {
    expect(
      resolveVariantUrl(_signed, '720p/video.m3u8'),
      'https://vz-1.b-cdn.net/bcdn_token=HS256-abc&token_path=%2Fguid%2F&expires=1793412264/guid/720p/video.m3u8',
    );
    expect(resolveVariantUrl('https://cdn.test/a/master.m3u8?token=x', '480p/v.m3u8'),
        'https://cdn.test/a/480p/v.m3u8?token=x');
    expect(resolveVariantUrl('https://cdn.test/a/master.m3u8', '/abs/v.m3u8'), 'https://cdn.test/abs/v.m3u8');
  });

  test('picks exact, else closest lower, else lowest; Auto picks none', () {
    final v = parseHlsMaster(_master);
    expect(pickVariant(v, 0), isNull);
    expect(pickVariant(v, 480)!.height, 480);
    expect(pickVariant(v, 1080)!.height, 720);
    expect(pickVariant(v, 100)!.height, 240);
  });

  test('episode orientation defaults to portrait', () {
    expect(Episode.fromJson({'id': 1, 'number': 1}).isLandscape, isFalse);
    expect(Episode.fromJson({'id': 1, 'number': 1, 'orientation': 'landscape'}).isLandscape, isTrue);
  });
}
