import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:food_recognizer_app/models/classification_result.dart';
import 'package:image/image.dart' as img;
import 'package:tflite_flutter/tflite_flutter.dart';

/// Data satu frame kamera yang aman dikirim antar-isolate.
class CameraFramePayload {
  const CameraFramePayload({
    required this.width,
    required this.height,
    required this.planes,
    required this.rowStrides,
    required this.pixelStrides,
    required this.rotationDegrees,
  });

  final int width;
  final int height;
  final List<Uint8List> planes;
  final List<int> rowStrides;
  final List<int> pixelStrides;
  final int rotationDegrees;

  factory CameraFramePayload.fromCameraImage(
    CameraImage image, {
    required int rotationDegrees,
  }) {
    return CameraFramePayload(
      width: image.width,
      height: image.height,
      planes: image.planes.map((plane) => plane.bytes).toList(),
      rowStrides: image.planes.map((plane) => plane.bytesPerRow).toList(),
      pixelStrides:
          image.planes.map((plane) => plane.bytesPerPixel ?? 1).toList(),
      rotationDegrees: rotationDegrees,
    );
  }
}

/// Menjalankan seluruh pipeline (decode, resize, inferensi LiteRT) pada
/// isolate terpisah agar UI thread tidak freeze.
class IsolateClassifier {
      IsolateClassifier._(this._commandPort);

  final SendPort _commandPort;

  static Future<IsolateClassifier> spawn({
    required String modelPath,
    required List<String> labels,
  }) async {
    final readyPort = ReceivePort();
    final isolate = await Isolate.spawn<_InitMessage>(
      _workerMain,
      _InitMessage(modelPath, labels, readyPort.sendPort),
    );

    final response = await readyPort.first;
    readyPort.close();

    if (response is SendPort) return IsolateClassifier._(response);

    isolate.kill(priority: Isolate.immediate);
    throw StateError('$response');
  }

  Future<ClassificationResult> classifyFile(String imagePath) {
    return _request(_FileJob(imagePath));
  }

  Future<ClassificationResult> classifyFrame(CameraFramePayload payload) {
    return _request(payload);
  }

  Future<ClassificationResult> _request(Object job) async {
    final replyPort = ReceivePort();
    _commandPort.send(_Envelope(job, replyPort.sendPort));
    final reply = await replyPort.first;
    replyPort.close();

    if (reply is ClassificationResult) return reply;
    throw StateError(reply is _WorkerError ? reply.message : 'Respons tidak valid.');
  }

  void dispose() {
    _commandPort.send(const _Shutdown());
  }
}

class _InitMessage {
  const _InitMessage(this.modelPath, this.labels, this.readyPort);

  final String modelPath;
  final List<String> labels;
  final SendPort readyPort;
}

class _Envelope {
  const _Envelope(this.job, this.replyPort);

  final Object job;
  final SendPort replyPort;
}

class _FileJob {
  const _FileJob(this.path);

  final String path;
}

class _Shutdown {
  const _Shutdown();
}

class _WorkerError {
  const _WorkerError(this.message);

  final String message;
}

void _workerMain(_InitMessage init) {
  final commandPort = ReceivePort();
  _InferenceEngine? created;

  try {
    created = _InferenceEngine(init.modelPath, init.labels);
  } catch (e) {
    init.readyPort.send('Gagal memuat model LiteRT: $e');
    return;
  }
  final engine = created;

  init.readyPort.send(commandPort.sendPort);

  commandPort.listen((message) {
    if (message is _Shutdown) {
      engine.close();
      commandPort.close();
      return;
    }

    if (message is! _Envelope) return;

    try {
      final job = message.job;
      final image = job is _FileJob
          ? engine.decodeFile(job.path)
          : engine.decodeFrame(job as CameraFramePayload);
      message.replyPort.send(engine.classify(image));
    } catch (e) {
      message.replyPort.send(_WorkerError('$e'));
    }
  });
}

class _InferenceEngine {
  _InferenceEngine(String modelPath, List<String> rawLabels)
      : _interpreter = Interpreter.fromFile(File(modelPath)) {
    final inputTensor = _interpreter.getInputTensor(0);
    final outputTensor = _interpreter.getOutputTensor(0);

    _inputSize = inputTensor.shape[1];
    _isFloatInput = inputTensor.type.toString().toLowerCase().contains('float');
    _isFloatOutput =
        outputTensor.type.toString().toLowerCase().contains('float');
    _classCount = outputTensor.shape.last;

    _labels = rawLabels.length + 1 == _classCount
        ? ['__background__', ...rawLabels]
        : rawLabels;
  }

  final Interpreter _interpreter;
  late final int _inputSize;
  late final bool _isFloatInput;
  late final bool _isFloatOutput;
  late final int _classCount;
  late final List<String> _labels;

  void close() => _interpreter.close();

  img.Image decodeFile(String path) {
    final decoded = img.decodeImage(File(path).readAsBytesSync());
    if (decoded == null) {
      throw StateError('Gambar tidak valid atau rusak.');
    }
    return img.bakeOrientation(decoded);
  }

  img.Image decodeFrame(CameraFramePayload frame) {
    final size = _inputSize;
    final output = img.Image(width: size, height: size);

    if (frame.planes.length == 1) {
      final bytes = frame.planes[0];
      final rowStride = frame.rowStrides[0];

      for (var oy = 0; oy < size; oy++) {
        final sy = oy * frame.height ~/ size;
        for (var ox = 0; ox < size; ox++) {
          final sx = ox * frame.width ~/ size;
          final index = sy * rowStride + sx * 4;
          output.setPixelRgb(ox, oy, bytes[index + 2], bytes[index + 1], bytes[index]);
        }
      }
    } else if (frame.planes.length == 3) {
      final yPlane = frame.planes[0];
      final uPlane = frame.planes[1];
      final vPlane = frame.planes[2];

      for (var oy = 0; oy < size; oy++) {
        final sy = oy * frame.height ~/ size;
        for (var ox = 0; ox < size; ox++) {
          final sx = ox * frame.width ~/ size;

          final y = yPlane[sy * frame.rowStrides[0] + sx];
          final uIndex = (sy ~/ 2) * frame.rowStrides[1] +
              (sx ~/ 2) * frame.pixelStrides[1];
          final vIndex = (sy ~/ 2) * frame.rowStrides[2] +
              (sx ~/ 2) * frame.pixelStrides[2];
          final u = uPlane[uIndex] - 128;
          final v = vPlane[vIndex] - 128;

          output.setPixelRgb(
            ox,
            oy,
            _clamp(y + 1.402 * v),
            _clamp(y - 0.344136 * u - 0.714136 * v),
            _clamp(y + 1.772 * u),
          );
        }
      }
    } else {
      throw StateError('Format frame kamera tidak didukung.');
    }

    if (frame.rotationDegrees % 360 == 0) return output;
    return img.copyRotate(output, angle: frame.rotationDegrees);
  }

  ClassificationResult classify(img.Image source) {
    final resized = img.copyResize(
      source,
      width: _inputSize,
      height: _inputSize,
      interpolation: img.Interpolation.average,
    );

    final Object output = _isFloatOutput
        ? [List<double>.filled(_classCount, 0)]
        : [List<int>.filled(_classCount, 0)];

    _interpreter.run(_buildInput(resized), output);

    final scores = (output as List).first as List;
    var bestIndex = -1;
    var bestScore = -1.0;

    for (var i = 0; i < scores.length; i++) {
      if (i < _labels.length && _labels[i].startsWith('__')) continue;

      final raw = scores[i] as num;
      final score = _isFloatOutput ? raw.toDouble() : raw / 255.0;
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    if (bestIndex < 0) throw StateError('Model tidak menghasilkan prediksi.');

    return ClassificationResult(
      label: bestIndex < _labels.length ? _labels[bestIndex] : 'Kelas $bestIndex',
      confidence: bestScore.clamp(0.0, 1.0),
    );
  }

  Object _buildInput(img.Image image) {
    return [
      List.generate(_inputSize, (y) {
        return List.generate(_inputSize, (x) {
          final pixel = image.getPixel(x, y);
          if (_isFloatInput) {
            return [
              (pixel.r - 127.5) / 127.5,
              (pixel.g - 127.5) / 127.5,
              (pixel.b - 127.5) / 127.5,
            ];
          }
          return [pixel.r.toInt(), pixel.g.toInt(), pixel.b.toInt()];
        });
      }),
    ];
  }

  int _clamp(double value) => value.clamp(0, 255).toInt();
}
