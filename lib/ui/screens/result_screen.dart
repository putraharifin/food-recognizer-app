import 'dart:io';

import 'package:flutter/material.dart';
import 'package:food_recognizer_app/core/formatters.dart';
import 'package:food_recognizer_app/models/classification_result.dart';
import 'package:food_recognizer_app/models/meal.dart';
import 'package:food_recognizer_app/models/nutrition_info.dart';
import 'package:food_recognizer_app/providers/result_provider.dart';
import 'package:food_recognizer_app/ui/screens/detail_screen.dart';
import 'package:food_recognizer_app/ui/widgets/section_header.dart';
import 'package:provider/provider.dart';

class ResultScreen extends StatelessWidget {
  const ResultScreen({
    super.key,
    required this.imagePath,
    required this.result,
  });

  final String imagePath;
  final ClassificationResult result;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;

    return ChangeNotifierProvider<ResultProvider>(
      create: (_) => ResultProvider(foodName: result.label)..loadAll(),
      child: Scaffold(
        appBar: AppBar(title: const Text('Result Page')),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: 230,
                  child: Image.file(
                    File(imagePath),
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) =>
                        const Center(child: Icon(Icons.broken_image_outlined, size: 56)),
                  ),
                ),
                const SizedBox(height: 20),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        child: Text(
                          toTitleCase(result.label),
                          style: TextStyle(
                            color: primary,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(
                        formatPercent(result.confidence),
                        style: TextStyle(color: primary, fontSize: 14),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Divider(color: primary, thickness: 1.2),
                const SizedBox(height: 12),
                const SectionHeader(title: 'Nutrition Facts'),
                const _NutritionSection(),
                const SizedBox(height: 16),
                const SectionHeader(title: 'Reference'),
                const _ReferenceSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NutritionSection extends StatelessWidget {
  const _NutritionSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultProvider>();

    switch (provider.nutritionState) {
      case LoadState.idle:
      case LoadState.loading:
        return const _LoadingBox();
      case LoadState.error:
        return _ErrorBox(
          message: provider.nutritionError ?? 'Gagal memuat nutrisi.',
          onRetry: provider.loadNutrition,
        );
      case LoadState.success:
        final NutritionInfo info = provider.nutrition!;
        return Column(
          children: [
            InfoRow(label: 'Calories', value: formatGram(info.calories)),
            InfoRow(label: 'Carbs', value: formatGram(info.carbohydrates)),
            InfoRow(label: 'Fat', value: formatGram(info.fat)),
            InfoRow(label: 'Fiber', value: formatGram(info.fiber)),
            InfoRow(label: 'Protein', value: formatGram(info.protein)),
          ],
        );
    }
  }
}

class _ReferenceSection extends StatelessWidget {
  const _ReferenceSection();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ResultProvider>();

    switch (provider.mealsState) {
      case LoadState.idle:
      case LoadState.loading:
        return const _LoadingBox();
      case LoadState.error:
        return _ErrorBox(
          message: provider.mealsError ?? 'Gagal memuat referensi resep.',
          onRetry: provider.loadMeals,
        );
      case LoadState.success:
        if (provider.meals.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(8),
            child: Text('Tidak ada resep terkait yang ditemukan di MealDB.'),
          );
        }
        return Column(
          children: provider.meals
              .map((meal) => _MealTile(meal: meal))
              .toList(growable: false),
        );
    }
  }
}

class _MealTile extends StatelessWidget {
  const _MealTile({required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => DetailScreen(meal: meal)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: Image.network(
                meal.thumbnail,
                width: 56,
                height: 56,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const SizedBox(
                  width: 56,
                  height: 56,
                  child: Icon(Icons.restaurant_outlined),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                meal.name,
                style: TextStyle(color: color, fontSize: 16),
              ),
            ),
            Icon(Icons.chevron_right, color: color),
          ],
        ),
      ),
    );
  }
}

class _LoadingBox extends StatelessWidget {
  const _LoadingBox();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.all(16),
      child: Center(child: CircularProgressIndicator()),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message, style: const TextStyle(color: Colors.red)),
          TextButton(onPressed: onRetry, child: const Text('Coba Lagi')),
        ],
      ),
    );
  }
}
