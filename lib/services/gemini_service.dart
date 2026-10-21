import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_recognizer_app/core/app_config.dart';
import 'package:food_recognizer_app/core/app_exception.dart';
import 'package:food_recognizer_app/models/nutrition_info.dart';
import 'package:http/http.dart' as http;

class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const String _systemInstruction =
      'Saya adalah suatu mesin yang mampu mengidentifikasi nutrisi atau '
      'kandungan gizi pada makanan layaknya uji laboratorium makanan. Hal yang '
      'bisa diidentifikasi adalah kalori, karbohidrat, lemak, serat, dan '
      'protein pada makanan. Satuan dari indikator tersebut berupa gram.';

  static const Map<String, dynamic> _responseSchema = {
    'type': 'OBJECT',
    'properties': {
      'calories': {'type': 'NUMBER'},
      'carbohydrates': {'type': 'NUMBER'},
      'fat': {'type': 'NUMBER'},
      'fiber': {'type': 'NUMBER'},
      'protein': {'type': 'NUMBER'},
    },
    'required': ['calories', 'carbohydrates', 'fat', 'fiber', 'protein'],
  };

  Future<NutritionInfo> fetchNutrition(String foodName) async {
    final apiKey = AppConfig.geminiApiKey;
    if (apiKey.isEmpty) {
      throw const AppException(
        'API Key Gemini belum diatur. Jalankan aplikasi dengan '
        '--dart-define=GEMINI_API_KEY=KUNCI_ANDA.',
      );
    }

    try {
      http.Response? response;
      for (final model in AppConfig.geminiModels) {
        response = await _post(model, apiKey, foodName);
        if (response.statusCode != 404) break;
      }

      if (response == null || response.statusCode != 200) {
        throw AppException(_describeStatus(response?.statusCode ?? 0));
      }

      return NutritionInfo.fromJson(_extractJson(response.body));
    } on SocketException {
      throw const AppException('Tidak ada koneksi internet.');
    } on TimeoutException {
      throw const AppException('Permintaan ke Gemini melebihi batas waktu.');
    } on FormatException {
      throw const AppException('Respons Gemini tidak dapat dibaca.');
    }
  }

  Future<http.Response> _post(String model, String apiKey, String foodName) {
    final uri = Uri.https(
      'generativelanguage.googleapis.com',
      '/v1beta/models/$model:generateContent',
    );

    return _client
        .post(
          uri,
          headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          },
          body: jsonEncode({
            'systemInstruction': {
              'parts': [
                {'text': _systemInstruction},
              ],
            },
            'contents': [
              {
                'role': 'user',
                'parts': [
                  {'text': 'Nama makanannya adalah $foodName.'},
                ],
              },
            ],
            'generationConfig': {
              'responseMimeType': 'application/json',
              'responseSchema': _responseSchema,
            },
          }),
        )
        .timeout(const Duration(seconds: 60));
  }

  Map<String, dynamic> _extractJson(String body) {
    final decoded = jsonDecode(body) as Map<String, dynamic>;
    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) {
      throw const AppException('Gemini tidak mengembalikan hasil.');
    }

    final content = (candidates.first as Map<String, dynamic>)['content'];
    final parts = (content as Map<String, dynamic>?)?['parts'];
    if (parts is! List || parts.isEmpty) {
      throw const AppException('Gemini tidak mengembalikan hasil.');
    }

    final text = parts
        .whereType<Map<String, dynamic>>()
        .where((part) => part['thought'] != true)
        .map((part) => part['text'] ?? '')
        .join();
    return jsonDecode(text) as Map<String, dynamic>;
  }

  String _describeStatus(int status) {
    switch (status) {
      case 400:
        return 'Permintaan ke Gemini ditolak (400). Periksa API Key Anda.';
      case 403:
        return 'API Key Gemini tidak memiliki akses (403).';
      case 404:
        return 'Model Gemini tidak tersedia (404). Perbarui daftar '
            'geminiModels di lib/core/app_config.dart.';
      case 429:
        return 'Kuota Gemini habis atau terlalu banyak permintaan (429).';
      case 503:
        return 'Layanan Gemini sedang sibuk (503). Coba lagi nanti.';
      default:
        return 'Gemini gagal merespons ($status).';
    }
  }
}