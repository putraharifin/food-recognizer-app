import 'dart:convert';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:food_recognizer_app/core/app_config.dart';
import 'package:food_recognizer_app/core/app_exception.dart';
import 'package:food_recognizer_app/models/classification_result.dart';
import 'package:food_recognizer_app/services/isolate_classifier.dart';
import 'package:food_recognizer_app/services/model_download_service.dart';

enum ModelStatus { idle, downloading, loading, ready, error }

class ClassifierProvider extends ChangeNotifier {
  ClassifierProvider({ModelDownloadService? downloadService})
      : _downloadService = downloadService ?? ModelDownloadService();

  final ModelDownloadService _downloadService;

  IsolateClassifier? _classifier;
  ModelStatus _status = ModelStatus.idle;
  double _downloadProgress = 0;
  bool _isBusy = false;
  bool _isDisposed = false;
  String? _errorMessage;

  ModelStatus get status => _status;
  double get downloadProgress => _downloadProgress;
  bool get isReady => _status == ModelStatus.ready;
  bool get isBusy => _isBusy;
  String? get errorMessage => _errorMessage;

  String? consumeError() {
    final message = _errorMessage;
    _errorMessage = null;
    return message;
  }

  Future<void> prepare() async {
    if (_status == ModelStatus.downloading ||
        _status == ModelStatus.loading ||
        _status == ModelStatus.ready) {
      return;
    }

    _status = ModelStatus.downloading;
    _downloadProgress = 0;
    _errorMessage = null;
    _notify();

    try {
      final labels = await _loadLabels();
      final modelPath = await _downloadService.ensureModel(
        onProgress: (progress) {
          _downloadProgress = progress;
          _notify();
        },
      );

      _status = ModelStatus.loading;
      _notify();

      _classifier = await IsolateClassifier.spawn(
        modelPath: modelPath,
        labels: labels,
      );
      _status = ModelStatus.ready;
    } catch (e) {
      _status = ModelStatus.error;
      _errorMessage = e is AppException ? e.message : '$e';
    }
    _notify();
  }

  Future<ClassificationResult?> classifyImageFile(String imagePath) async {
    final classifier = _classifier;
    if (classifier == null || !isReady) {
      _errorMessage = 'Model belum siap. Tunggu hingga model selesai dimuat.';
      return null;
    }

    _isBusy = true;
    _notify();
    try {
      return await classifier.classifyFile(imagePath);
    } catch (e) {
      _errorMessage = 'Gagal mengenali makanan: $e';
      return null;
    } finally {
      _isBusy = false;
      _notify();
    }
  }

  Future<ClassificationResult?> classifyCameraImage(
    CameraImage image, {
    required int rotationDegrees,
  }) async {
    final classifier = _classifier;
    if (classifier == null || !isReady) return null;

    try {
      return await classifier.classifyFrame(
        CameraFramePayload.fromCameraImage(
          image,
          rotationDegrees: rotationDegrees,
        ),
      );
    } catch (e) {
      debugPrint('Inferensi frame gagal: $e');
      return null;
    }
  }

  Future<List<String>> _loadLabels() async {
    final String raw;
    try {
      raw = await rootBundle.loadString(AppConfig.labelsAsset);
    } catch (_) {
      throw const AppException(
        'Berkas label tidak ditemukan. Letakkan labelmap model pada '
        '"assets/labels.csv".',
      );
    }

    final labels = <String>[];
    for (final line in const LineSplitter().convert(raw)) {
      var value = line.trim();
      if (value.isEmpty) continue;

      if (value.contains(',')) {
        final parts = value.split(',');
        if (int.tryParse(parts.first.trim()) != null) {
          value = parts.sublist(1).join(',');
        }
      }
      labels.add(value.replaceAll('"', '').trim());
    }

    const headers = {'name', 'label', 'labels', 'index,name'};
    if (labels.isNotEmpty && headers.contains(labels.first.toLowerCase())) {
      labels.removeAt(0);
    }

    if (labels.isEmpty) {
      throw const AppException('Berkas label kosong.');
    }
    return labels;
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    _classifier?.dispose();
    super.dispose();
  }
}
