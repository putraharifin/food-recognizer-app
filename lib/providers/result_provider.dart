import 'package:flutter/foundation.dart';
import 'package:food_recognizer_app/core/app_exception.dart';
import 'package:food_recognizer_app/models/meal.dart';
import 'package:food_recognizer_app/models/nutrition_info.dart';
import 'package:food_recognizer_app/services/gemini_service.dart';
import 'package:food_recognizer_app/services/meal_db_service.dart';

enum LoadState { idle, loading, success, error }

class ResultProvider extends ChangeNotifier {
  ResultProvider({
    required this.foodName,
    MealDbService? mealDbService,
    GeminiService? geminiService,
  })  : _mealDbService = mealDbService ?? MealDbService(),
        _geminiService = geminiService ?? GeminiService();

  final String foodName;
  final MealDbService _mealDbService;
  final GeminiService _geminiService;

  LoadState _nutritionState = LoadState.idle;
  NutritionInfo? _nutrition;
  String? _nutritionError;

  LoadState _mealsState = LoadState.idle;
  List<Meal> _meals = const [];
  String? _mealsError;

  bool _isDisposed = false;

  LoadState get nutritionState => _nutritionState;
  NutritionInfo? get nutrition => _nutrition;
  String? get nutritionError => _nutritionError;

  LoadState get mealsState => _mealsState;
  List<Meal> get meals => _meals;
  String? get mealsError => _mealsError;

  Future<void> loadAll() => Future.wait([loadNutrition(), loadMeals()]);

  Future<void> loadNutrition() async {
    _nutritionState = LoadState.loading;
    _nutritionError = null;
    _notify();

    try {
      _nutrition = await _geminiService.fetchNutrition(foodName);
      _nutritionState = LoadState.success;
    } catch (e) {
      _nutritionState = LoadState.error;
      _nutritionError =
          e is AppException ? e.message : 'Gagal memuat informasi nutrisi.';
    }
    _notify();
  }

  Future<void> loadMeals() async {
    _mealsState = LoadState.loading;
    _mealsError = null;
    _notify();

    try {
      _meals = await _mealDbService.searchMeals(foodName);
      _mealsState = LoadState.success;
    } catch (e) {
      _mealsState = LoadState.error;
      _mealsError =
          e is AppException ? e.message : 'Gagal memuat referensi resep.';
    }
    _notify();
  }

  void _notify() {
    if (!_isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }
}
