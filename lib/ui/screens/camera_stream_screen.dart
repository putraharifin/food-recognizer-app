import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:food_recognizer_app/core/formatters.dart';
import 'package:food_recognizer_app/providers/camera_provider.dart';
import 'package:food_recognizer_app/providers/classifier_provider.dart';
import 'package:provider/provider.dart';

class CameraStreamScreen extends StatefulWidget {
  const CameraStreamScreen({super.key});

  @override
  State<CameraStreamScreen> createState() => _CameraStreamScreenState();
}

class _CameraStreamScreenState extends State<CameraStreamScreen>
    with WidgetsBindingObserver {
  static const Color _previewBackground = Color(0xFF0A1128);

  late final CameraProvider _provider;
  late final ClassifierProvider _classifier;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _provider = context.read<CameraProvider>();
    _classifier = context.read<ClassifierProvider>();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startCamera());
  }

  Future<void> _startCamera() async {
    await _provider.initializeCamera();
    if (!mounted) return;
    _provider.frameHandler = _onFrame;
    await _provider.startImageStream();
  }

  Future<void> _onFrame(CameraImage image) async {
    if (!_classifier.isReady) return;

    final result = await _classifier.classifyCameraImage(
      image,
      rotationDegrees: _provider.frameRotation,
    );
    if (result == null || !mounted) return;

    _provider.updateLiveResult(result.label, result.confidence);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive) {
      _provider.releaseCamera(notify: true);
    } else if (state == AppLifecycleState.resumed) {
      _startCamera();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _provider.frameHandler = null;
    _provider.releaseCamera();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera Page')),
      body: Consumer2<CameraProvider, ClassifierProvider>(
        builder: (context, provider, classifier, _) {
          return Column(
            children: [
              Expanded(
                child: Container(
                  width: double.infinity,
                  color: _previewBackground,
                  child: _buildPreview(provider),
                ),
              ),
              _ResultOverlay(
                label: provider.liveLabel,
                confidence: provider.liveConfidence,
                modelReady: classifier.isReady,
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPreview(CameraProvider provider) {
    final error = provider.errorMessage;
    if (error != null && !provider.isCameraReady) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.no_photography_outlined,
                size: 56,
                color: Colors.white70,
              ),
              const SizedBox(height: 12),
              Text(
                error,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(160, 44),
                ),
                onPressed: _startCamera,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    final controller = provider.controller;
    if (!provider.isCameraReady || controller == null) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    return Center(
      child: AspectRatio(
        aspectRatio: 1 / controller.value.aspectRatio,
        child: CameraPreview(controller),
      ),
    );
  }
}

class _ResultOverlay extends StatelessWidget {
  const _ResultOverlay({
    required this.label,
    required this.confidence,
    required this.modelReady,
  });

  final String? label;
  final double? confidence;
  final bool modelReady;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final hasResult = label != null && confidence != null;

    return Container(
      width: double.infinity,
      color: Theme.of(context).scaffoldBackgroundColor,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 28),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  hasResult
                      ? toTitleCase(label!)
                      : (modelReady
                          ? 'Arahkan kamera ke makanan...'
                          : 'Menyiapkan model...'),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primary,
                    fontSize: hasResult ? 24 : 16,
                    fontWeight: hasResult ? FontWeight.bold : FontWeight.w500,
                  ),
                ),
              ),
              if (hasResult)
                Text(
                  formatPercent(confidence!),
                  style: TextStyle(color: primary, fontSize: 14),
                ),
            ],
          ),
        ),
      ),
    );
  }
}