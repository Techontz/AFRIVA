import 'package:afriva_app/core/video_source.dart';
import 'package:afriva_app/models/episode.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  group('isHlsUrl', () {
    test('detects plain and signed HLS playlists', () {
      expect(isHlsUrl('https://vz-abc.b-cdn.net/guid/playlist.m3u8'), isTrue);
      expect(isHlsUrl('https://vz-abc.b-cdn.net/guid/playlist.m3u8?token=x&expires=1'), isTrue);
      expect(isHlsUrl('https://vz-abc.b-cdn.net/bcdn_token=x&expires=1/guid/playlist.m3u8'), isTrue);
      expect(isHlsUrl('https://cdn.example.com/guid/playlist.M3U8#t=3'), isTrue);
      expect(isHlsUrl('https://cdn.example.com/hls/playlist.m3u8/sig/abc'), isTrue);
      // Bunny token authentication: token in the path, .m3u8 at the end.
      expect(
        isHlsUrl('https://vz-3ce5503c-a55.b-cdn.net/bcdn_token=HS256-abc_DEF&token_path=%2F0b1c%2F&expires=123/0b1c/playlist.m3u8'),
        isTrue,
      );
      expect(isHlsUrl('https://vz-3ce5503c-a55.b-cdn.net/0b1c/thumbnail.jpg?token=abc&expires=123'), isFalse);
    });

    test('leaves mp4 alone', () {
      expect(isHlsUrl('https://storage.googleapis.com/x/ForBiggerFun.mp4'), isFalse);
      expect(isHlsUrl('https://cdn.example.com/m3u8-guide.mp4'), isFalse);
    });

    test('controller gets the HLS format hint only for HLS', () {
      final hls = networkVideoController('https://vz-a.b-cdn.net/g/playlist.m3u8?token=1');
      final mp4 = networkVideoController('https://cdn.example.com/a.mp4');
      expect(hls.formatHint, VideoFormat.hls);
      expect(mp4.formatHint, isNull);
    });
  });

  test('PlayResult keeps a null video_url (coming soon)', () {
    final r = PlayResult.fromJson({
      'video_url': null,
      'episode': {'id': 1, 'number': 1},
    });
    expect(r.videoUrl, isNull);
  });
}
