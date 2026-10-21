import 'package:flutter/material.dart';
import 'package:food_recognizer_app/providers/camera_provider.dart';
import 'package:food_recognizer_app/providers/classifier_provider.dart';
import 'package:food_recognizer_app/ui/screens/camera_stream_screen.dart';
import 'package:food_recognizer_app/ui/screens/result_screen.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  Future<void> _showSourceSheet(BuildContext context) async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Pilih dari Galeri'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Ambil dari Kamera'),
              onTap: () => Navigator.pop(sheetContext, ImageSource.camera),
            ),
          ],
        ),
      ),
    );
    if (source == null || !context.mounted) return;

    final provider = context.read<CameraProvider>();
    await provider.pickImage(source);
    if (!context.mounted) return;
    _showMessage(context, provider.consumeError());
  }

  Future<void> _onCropAndAnalyze(BuildContext context) async {
    final provider = context.read<CameraProvider>();
    final cropped = await provider.cropSelectedImage();
    if (!context.mounted) return;

    if (!cropped) {
      _showMessage(context, provider.consumeError());
      return;
    }
    await _onAnalyze(context);
  }

  Future<void> _onAnalyze(BuildContext context) async {
    final file = context.read<CameraProvider>().imageFile;
    if (file == null) return;

    final classifier = context.read<ClassifierProvider>();
    final result = await classifier.classifyImageFile(file.path);
    if (!context.mounted) return;

    if (result == null) {
      _showMessage(
        context,
        classifier.consumeError() ?? 'Makanan tidak dapat dikenali.',
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(imagePath: file.path, result: result),
      ),
    );
  }

  void _showMessage(BuildContext context, String? message) {
    if (message == null) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final camera = context.watch<CameraProvider>();
    final classifier = context.watch<ClassifierProvider>();
    final imageFile = camera.imageFile;
    final canAnalyze = camera.hasImage && classifier.isReady && !classifier.isBusy;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Food Recognizer App'),
        actions: [
          IconButton(
            tooltip: 'Buka kamera',
            icon: const Icon(Icons.photo_camera),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const CameraStreamScreen()),
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _ModelStatusBanner(),
              Expanded(
                child: Center(
                  child: GestureDetector(
                    onTap: () => _showSourceSheet(context),
                    child: imageFile == null
                        ? _ImagePlaceholder(
                            color: Theme.of(context).colorScheme.primary,
                          )
                        : Image.file(
                            imageFile,
                            fit: BoxFit.contain,
                            errorBuilder: (_, _, _) => const _ImageError(),
                          ),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canAnalyze ? () => _onAnalyze(context) : null,
                child: classifier.isBusy
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Analyze'),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: canAnalyze ? () => _onCropAndAnalyze(context) : null,
                child: const Text('Crop & Analyze'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModelStatusBanner extends StatelessWidget {
  const _ModelStatusBanner();

  @override
  Widget build(BuildContext context) {
    final classifier = context.watch<ClassifierProvider>();

    switch (classifier.status) {
      case ModelStatus.ready:
        return const SizedBox.shrink();
      case ModelStatus.error:
        return Card(
          child: ListTile(
            leading: const Icon(Icons.error_outline, color: Colors.red),
            title: Text(
              classifier.errorMessage ?? 'Model gagal dimuat.',
              style: const TextStyle(fontSize: 13),
            ),
            trailing: TextButton(
              onPressed: classifier.prepare,
              child: const Text('Coba Lagi'),
            ),
          ),
        );
      case ModelStatus.idle:
      case ModelStatus.downloading:
      case ModelStatus.loading:
        final downloading = classifier.status == ModelStatus.downloading;
        final progress = classifier.downloadProgress;
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                downloading
                    ? 'Mengunduh model... ${(progress * 100).toStringAsFixed(0)}%'
                    : 'Memuat model...',
                style: const TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 6),
              LinearProgressIndicator(value: downloading ? progress : null),
            ],
          ),
        );
    }
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 240,
      decoration: BoxDecoration(
        border: Border.all(color: color.withAlpha(120), width: 1.5),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.add_photo_alternate_outlined, size: 56, color: color),
          const SizedBox(height: 8),
          Text(
            'Ketuk untuk memilih gambar makanan',
            style: TextStyle(color: color),
          ),
        ],
      ),
    );
  }
}

class _ImageError extends StatelessWidget {
  const _ImageError();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      height: 240,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.broken_image_outlined, size: 56),
          SizedBox(height: 8),
          Text('Gambar tidak dapat ditampilkan. Pilih gambar lain.'),
        ],
      ),
    );
  }
}
