import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:food_recognizer_app/core/app_config.dart';
import 'package:food_recognizer_app/core/app_exception.dart';
import 'package:food_recognizer_app/models/meal.dart';
import 'package:http/http.dart' as http;

class MealDbService {
  MealDbService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Future<List<Meal>> searchMeals(String foodName) async {
    try {
      for (final query in _buildQueries(foodName)) {
        final meals = await _searchByName(query);
        if (meals.isNotEmpty) return meals.take(10).toList();
      }
      return const [];
    } on SocketException {
      throw const AppException('Tidak ada koneksi internet.');
    } on TimeoutException {
      throw const AppException('Permintaan ke MealDB melebihi batas waktu.');
    } on FormatException {
      throw const AppException('Respons MealDB tidak dapat dibaca.');
    }
  }

  Future<List<Meal>> _searchByName(String query) async {
    final uri = Uri.parse('${AppConfig.mealDbBaseUrl}/search.php')
        .replace(queryParameters: {'s': query});
    final response = await _client.get(uri).timeout(const Duration(seconds: 20));

    if (response.statusCode != 200) {
      throw AppException('MealDB gagal merespons (${response.statusCode}).');
    }

    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final rawMeals = body['meals'];
    if (rawMeals is! List) return const [];

    return rawMeals
        .whereType<Map<String, dynamic>>()
        .map(Meal.fromJson)
        .toList();
  }

  List<String> _buildQueries(String foodName) {
    final full = foodName.trim();
    final words = full
        .split(RegExp(r'\s+'))
        .where((word) => word.length >= 4)
        .toList()
      ..sort((a, b) => b.length.compareTo(a.length));

    return <String>{full, ...words}.take(3).toList();
  }
}
