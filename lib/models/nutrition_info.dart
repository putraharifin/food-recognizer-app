class NutritionInfo {
  const NutritionInfo({
    required this.calories,
    required this.carbohydrates,
    required this.fat,
    required this.fiber,
    required this.protein,
  });

  final double calories;
  final double carbohydrates;
  final double fat;
  final double fiber;
  final double protein;

  factory NutritionInfo.fromJson(Map<String, dynamic> json) {
    return NutritionInfo(
      calories: _toDouble(json['calories']),
      carbohydrates: _toDouble(json['carbohydrates']),
      fat: _toDouble(json['fat']),
      fiber: _toDouble(json['fiber']),
      protein: _toDouble(json['protein']),
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    return double.tryParse('$value') ?? 0;
  }
}
