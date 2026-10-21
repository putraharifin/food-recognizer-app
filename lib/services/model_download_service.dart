import 'dart:async';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:food_recognizer_app/core/app_config.dart';
import 'package:food_recognizer_app/core/app_exception.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

typedef DownloadProgressCallback = void Function(double progress);

class ModelDownloadService {
  ModelDownloadService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  /// Mengembalikan path model lokal. Model diunduh dari Firebase Cloud Storage
  /// hanya bila belum ada atau versi di cloud berubah.
  Future<String> ensureModel({DownloadProgressCallback? onProgress}) async {
    final directory = await getApplicationSupportDirectory();
    final modelFile = File('${directory.path}/${AppConfig.modelFileName}');
    final stampFile = File('${modelFile.path}.stamp');
    final tempFile = File('${modelFile.path}.download');

    final hasCache = await modelFile.exists() && await modelFile.length() > 0;

    try {
      final ref = FirebaseStorage.instance.ref(AppConfig.modelStoragePath);
      final metadata = await ref.getMetadata();
      final remoteStamp =
          '${metadata.md5Hash ?? metadata.updated?.millisecondsSinceEpoch}';

      if (hasCache && await _readStamp(stampFile) == remoteStamp) {
        onProgress?.call(1);
        return modelFile.path;
      }

      await _downloadFromStorage(ref, tempFile, onProgress);
      await _commit(tempFile, modelFile);
      await stampFile.writeAsString(remoteStamp);
      return modelFile.path;
    } catch (storageError) {
      if (await tempFile.exists()) await tempFile.delete();
      if (hasCache) return modelFile.path;

      if (AppConfig.modelHostingUrl.isNotEmpty) {
        try {
          await _downloadFromHosting(tempFile, onProgress);
          await _commit(tempFile, modelFile);
          return modelFile.path;
        } catch (hostingError) {
          if (await tempFile.exists()) await tempFile.delete();
          throw AppException(
            'Gagal mengunduh model dari Firebase Hosting: $hostingError',
          );
        }
      }

      throw AppException(
        'Gagal mengunduh model dari Firebase Storage. Pastikan berkas '
        '"${AppConfig.modelStoragePath}" sudah diunggah dan koneksi internet '
        'aktif. ($storageError)',
      );
    }
  }

  Future<void> _downloadFromStorage(
    Reference ref,
    File target,
    DownloadProgressCallback? onProgress,
  ) async {
    final task = ref.writeToFile(target);
    final subscription = task.snapshotEvents.listen((snapshot) {
      if (snapshot.totalBytes > 0) {
        onProgress?.call(snapshot.bytesTransferred / snapshot.totalBytes);
      }
    });

    try {
      await task;
    } finally {
      await subscription.cancel();
    }
  }

  Future<void> _downloadFromHosting(
    File target,
    DownloadProgressCallback? onProgress,
  ) async {
    final request = http.Request('GET', Uri.parse(AppConfig.modelHostingUrl));
    final response = await _client.send(request);
    if (response.statusCode != 200) {
      throw AppException('Server merespons ${response.statusCode}.');
    }

    final total = response.contentLength ?? 0;
    var received = 0;
    final sink = target.openWrite();
    try {
      await for (final chunk in response.stream) {
        sink.add(chunk);
        received += chunk.length;
        if (total > 0) onProgress?.call(received / total);
      }
    } finally {
      await sink.close();
    }
  }

  Future<void> _commit(File tempFile, File modelFile) async {
    if (await modelFile.exists()) await modelFile.delete();
    await tempFile.rename(modelFile.path);
  }

  Future<String?> _readStamp(File stampFile) async {
    if (!await stampFile.exists()) return null;
    return stampFile.readAsString();
  }
}
