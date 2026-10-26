import 'package:file_picker/file_picker.dart';

import '../models/studio.dart';

/// The only place that touches the `file_picker` plugin, so it can be swapped or faked.
class FilePickerService {
  const FilePickerService();

  Future<PickedUpload?> pickVideo() => _pick(FileType.video);

  Future<PickedUpload?> pickImage() => _pick(FileType.image);

  /// WebVTT / SRT subtitles.
  Future<PickedUpload?> pickSubtitle() => _pick(FileType.custom, extensions: const ['vtt', 'srt']);

  Future<PickedUpload?> _pick(FileType type, {List<String>? extensions}) async {
    final result = await FilePicker.platform.pickFiles(
      type: type,
      allowedExtensions: extensions,
      withData: false,
    );
    final file = result?.files.firstOrNull;
    final path = file?.path;
    if (file == null || path == null) return null;
    return PickedUpload(path: path, name: file.name, size: file.size);
  }
}
