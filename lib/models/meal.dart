class Ingredient {
  const Ingredient({required this.name, required this.measure});

  final String name;
  final String measure;
}

class Meal {
  const Meal({
    required this.id,
    required this.name,
    required this.thumbnail,
    required this.instructions,
    required this.ingredients,
  });

  final String id;
  final String name;
  final String thumbnail;
  final String instructions;
  final List<Ingredient> ingredients;

  factory Meal.fromJson(Map<String, dynamic> json) {
    final ingredients = <Ingredient>[];
    for (var i = 1; i <= 20; i++) {
      final name = _clean(json['strIngredient$i']);
      if (name.isEmpty) continue;
      ingredients.add(
        Ingredient(name: name, measure: _clean(json['strMeasure$i'])),
      );
    }

    return Meal(
      id: _clean(json['idMeal']),
      name: _clean(json['strMeal']),
      thumbnail: _clean(json['strMealThumb']),
      instructions: _clean(json['strInstructions']),
      ingredients: ingredients,
    );
  }

  static String _clean(Object? value) => value == null ? '' : '$value'.trim();
}
