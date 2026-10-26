import 'package:dio/dio.dart';

import '../core/api_client.dart';
import '../models/drama.dart';
import '../models/json.dart';
import '../models/studio.dart';
import '../models/user.dart';

/// Creator Studio ("Wasilisha Kazi Yako", SPEC §8.5). Uploading never publishes:
/// work is reviewed by AFRIVA, then staff set the date, price and free episodes.
class CreatorService {
  CreatorService(this._api);
  final ApiClient _api;

  /// Viewer → creator (account pending until AFRIVA approves it).
  Future<User> apply({
    required String name,
    String? phone,
    String? email,
    String? description,
    String country = 'TZ',
  }) async {
    final data = asMap(await _api.post('/creator/apply', body: {
      'name': name.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
      if (description != null && description.trim().isNotEmpty) 'description': description.trim(),
      'country': country,
    }));
    return User.fromJson(asMap(data['user']));
  }

  Future<CreatorAgreement> agreement() async => CreatorAgreement.fromJson(asMap(await _api.get('/studio/agreement')));

  Future<CreatorAgreement> acceptAgreement() async =>
      CreatorAgreement.fromJson(asMap(await _api.post('/studio/agreement', body: {'accept': true})));

  Future<List<Drama>> dramas() async => asList(await _api.get('/studio/dramas', query: {'per_page': 100}), Drama.fromJson);

  Future<StudioDrama> drama(int id) async => StudioDrama.fromJson(asMap(await _api.get('/studio/dramas/$id')));

  Future<List<Category>> categories() async => asList(await _api.get('/categories'), Category.fromJson);

  /// Create (id == null) or update a series. Publishing rules are not sent: staff set them.
  Future<Drama> saveDrama({
    int? id,
    required String title,
    required String synopsis,
    required List<int> categoryIds,
    String? ageRating,
    PickedUpload? poster,
    PickedUpload? trailer,
    void Function(int sent, int total)? onProgress,
  }) async {
    final form = FormData.fromMap({
      if (id != null) '_method': 'PUT',
      'title': title.trim(),
      'synopsis': synopsis.trim(),
      'category_ids': categoryIds.join(','),
      if (ageRating != null) 'age_rating': ageRating,
      if (poster != null) 'poster': await MultipartFile.fromFile(poster.path, filename: poster.name),
      if (trailer != null) 'trailer': await MultipartFile.fromFile(trailer.path, filename: trailer.name),
    });
    final body = await _api.postMultipart(id == null ? '/studio/dramas' : '/studio/dramas/$id', form, onSendProgress: onProgress);
    return Drama.fromJson(asMap(body['data']));
  }

  Future<void> deleteDrama(int id) => _api.deleteJson('/studio/dramas/$id');

  /// Add (episodeId == null) or update an episode, uploading the video with progress.
  Future<void> saveEpisode({
    required int dramaId,
    int? episodeId,
    String? title,
    int? number,
    PickedUpload? video,
    PickedUpload? subtitle,
    void Function(int sent, int total)? onProgress,
    CancelToken? cancelToken,
  }) async {
    final form = FormData.fromMap({
      if (episodeId != null) '_method': 'PUT',
      if (title != null && title.trim().isNotEmpty) 'title': title.trim(),
      'number': ?number,
      if (video != null) 'video': await MultipartFile.fromFile(video.path, filename: video.name),
      if (subtitle != null) 'subtitle': await MultipartFile.fromFile(subtitle.path, filename: subtitle.name),
    });
    final path = episodeId == null ? '/studio/dramas/$dramaId/episodes' : '/studio/dramas/$dramaId/episodes/$episodeId';
    await _api.postMultipart(path, form, onSendProgress: onProgress, cancelToken: cancelToken);
  }

  Future<void> deleteEpisode(int dramaId, int episodeId) => _api.deleteJson('/studio/dramas/$dramaId/episodes/$episodeId');

  /// Send the series / its new episodes for review, with the rights declaration.
  Future<StudioDrama> submit(int dramaId) async => StudioDrama.fromJson(
        asMap(await _api.post('/studio/dramas/$dramaId/submit', body: {'rights_declaration': true})),
      );
}
