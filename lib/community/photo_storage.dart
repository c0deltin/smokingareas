import 'dart:io';

import 'package:uuid/uuid.dart';

/// Adapter for photo files. Locally a key is a file name in the app's
/// support directory; a server implementation would upload the file and
/// return a URL as key.
abstract class PhotoStorage {
  /// Stores a copy of [source] and returns its key.
  Future<String> save(File source);

  /// Local file for [key] (null if it is not available on this device).
  Future<File?> resolve(String key);
}

class LocalPhotoStorage implements PhotoStorage {
  LocalPhotoStorage(this._directory);

  final Future<Directory> Function() _directory;
  static const _uuid = Uuid();

  Future<Directory> _photosDir() async {
    final dir = Directory('${(await _directory()).path}/community/photos');
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  @override
  Future<String> save(File source) async {
    final ext = source.path.contains('.')
        ? source.path.substring(source.path.lastIndexOf('.')).toLowerCase()
        : '.jpg';
    final key = '${_uuid.v4()}$ext';
    await source.copy('${(await _photosDir()).path}/$key');
    return key;
  }

  @override
  Future<File?> resolve(String key) async {
    // Keys are plain file names – never let them escape the photo folder.
    if (key.contains('/') || key.contains('\\') || key.contains('..')) {
      return null;
    }
    final file = File('${(await _photosDir()).path}/$key');
    return await file.exists() ? file : null;
  }
}
