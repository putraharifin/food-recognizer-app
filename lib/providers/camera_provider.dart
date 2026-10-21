import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';

typedef CameraFrameHandler = Future<void> Function(CameraImage image);

class CameraProvider extends ChangeNotifier {
  static const Duration frameInterval = Duration(milliseconds: 700);

  final ImagePicker _picker = ImagePicker();
  final ImageCropper _cropper = ImageCropper();

  File? _imageFile;
  String? _errorMessage;

  CameraController? _controller;
  bool _isInitializing = false;
  bool _isStreaming = false;
  bool _isProcessingFrame = false;
  DateTime? _lastFrameTime;
  int _session = 0;

  String? _liveLabel;
  double? _liveConfidence;

  /// Diisi pada Tahap 2 untuk menjalankan inferensi pada setiap frame kamera.
  CameraFrameHandler? frameHandler;

  File? get imageFile => _imageFile;
  bool get hasImage => _imageFile != null;
  String? get errorMessage => _errorMessage;

  CameraController? get controller => _controller;
  bool get isInitializing => _isInitializing;
  bool get isStreaming => _isStreaming;
  bool get isCameraReady =>
      _controller != null && _controller!.value.isInitialized;

  int get frameRotation => Platform.isAndroid
      ? (_controller?.description.sensorOrientation ?? 0)
      : 0;

  String? get liveLabel => _liveLabel;
  double? get liveConfidence => _liveConfidence;

  String? consumeError() {
    final message = _errorMessage;
    _errorMessage = null;
    return message;
  }

  Future<bool> pickImage(ImageSource source) async {
    try {
      final picked = await _picker.pickImage(source: source);
      if (picked == null) return false;

      _imageFile = File(picked.path);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = source == ImageSource.camera
          ? 'Gagal membuka kamera. Pastikan izin kamera telah diberikan.'
          : 'Gagal membuka galeri. Pastikan izin akses galeri telah diberikan.';
      notifyListeners();
      return false;
    }
  }

  Future<bool> cropSelectedImage() async {
    final file = _imageFile;
    if (file == null) return false;

    try {
      final cropped = await _cropper.cropImage(
        sourcePath: file.path,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Cropper',
            toolbarColor: const Color(0xFFE31E48),
            toolbarWidgetColor: Colors.white,
            activeControlsWidgetColor: const Color(0xFFE31E48),
            initAspectRatio: CropAspectRatioPreset.original,
            lockAspectRatio: false,
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Cropper',
            aspectRatioPresets: const [
              CropAspectRatioPreset.original,
              CropAspectRatioPreset.square,
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
        ],
      );
      if (cropped == null) return false;

      _imageFile = File(cropped.path);
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = 'Gagal memotong gambar. Silakan coba lagi.';
      notifyListeners();
      return false;
    }
  }

  void clearImage() {
    _imageFile = null;
    notifyListeners();
  }

  Future<void> initializeCamera() async {
    if (_isInitializing || _controller != null) return;

    final session = _session;
    CameraController? controller;

    _isInitializing = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        throw CameraException('noCamera', 'Tidak ada kamera pada perangkat.');
      }

      final description = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      controller = CameraController(
        description,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.yuv420
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();

      if (session != _session) {
        await controller.dispose();
        return;
      }
      _controller = controller;
    } on CameraException catch (e) {
      await controller?.dispose();
      if (session == _session) {
        _errorMessage = _mapCameraError(e);
      }
    } catch (e) {
      await controller?.dispose();
      if (session == _session) {
        _errorMessage = 'Terjadi kesalahan saat menginisialisasi kamera.';
      }
    } finally {
      if (session == _session) {
        _isInitializing = false;
        notifyListeners();
      }
    }
  }

  Future<void> startImageStream() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isStreamingImages) {
      return;
    }

    try {
      await controller.startImageStream(_onCameraFrame);
      _isStreaming = true;
      notifyListeners();
    } on CameraException catch (e) {
      _errorMessage = _mapCameraError(e);
      notifyListeners();
    }
  }

  Future<void> stopImageStream() async {
    final controller = _controller;
    if (controller == null || !controller.value.isStreamingImages) return;

    try {
      await controller.stopImageStream();
    } on CameraException catch (e) {
      debugPrint('Gagal menghentikan stream kamera: ${e.description}');
    }
    _isStreaming = false;
    _isProcessingFrame = false;
    notifyListeners();
  }

  Future<void> releaseCamera({bool notify = false}) async {
    final controller = _controller;

    _session++;
    _controller = null;
    _isInitializing = false;
    _isStreaming = false;
    _isProcessingFrame = false;
    _lastFrameTime = null;
    _liveLabel = null;
    _liveConfidence = null;
    if (notify) notifyListeners();

    if (controller == null) return;

    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream();
      }
    } catch (e) {
      debugPrint('Gagal menghentikan stream kamera: $e');
    }
    await controller.dispose();
  }

  void updateLiveResult(String label, double confidence) {
    if (_controller == null) return;
    _liveLabel = label;
    _liveConfidence = confidence;
    notifyListeners();
  }

  void clearLiveResult() {
    _liveLabel = null;
    _liveConfidence = null;
    notifyListeners();
  }

  Future<void> _onCameraFrame(CameraImage image) async {
    final handler = frameHandler;
    if (handler == null || _isProcessingFrame) return;

    final now = DateTime.now();
    final last = _lastFrameTime;
    if (last != null && now.difference(last) < frameInterval) return;

    _lastFrameTime = now;
    _isProcessingFrame = true;
    try {
      await handler(image);
    } catch (e) {
      debugPrint('Gagal memproses frame kamera: $e');
    } finally {
      _isProcessingFrame = false;
    }
  }

  String _mapCameraError(CameraException e) {
    switch (e.code) {
      case 'CameraAccessDenied':
      case 'CameraAccessDeniedWithoutPrompt':
      case 'CameraAccessRestricted':
        return 'Izin kamera ditolak. Aktifkan izin kamera melalui pengaturan perangkat.';
      case 'noCamera':
        return 'Tidak ada kamera pada perangkat.';
      default:
        return e.description ?? 'Terjadi kesalahan pada kamera.';
    }
  }

  @override
  void dispose() {
    unawaited(releaseCamera());
    super.dispose();
  }
}
