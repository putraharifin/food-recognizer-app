import 'package:flutter/material.dart';
import 'package:food_recognizer_app/models/meal.dart';
import 'package:food_recognizer_app/ui/widgets/section_header.dart';

class DetailScreen extends StatelessWidget {
  const DetailScreen({super.key, required this.meal});

  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(title: Text(meal.name)),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: double.infinity,
                height: 230,
                child: Image.network(
                  meal.thumbnail,
                  fit: BoxFit.cover,
                  loadingBuilder: (context, child, progress) => progress == null
                      ? child
                      : const Center(child: CircularProgressIndicator()),
                  errorBuilder: (_, _, _) =>
                      const Center(child: Icon(Icons.broken_image_outlined, size: 56)),
                ),
              ),
              const SizedBox(height: 20),
              const SectionHeader(title: 'Ingredients'),
              if (meal.ingredients.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(4),
                  child: Text('Daftar bahan tidak tersedia.'),
                )
              else
                ...meal.ingredients.map(
                  (item) => InfoRow(label: item.name, value: item.measure),
                ),
              const SizedBox(height: 16),
              const SectionHeader(title: 'Instructions'),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  meal.instructions.isEmpty
                      ? 'Langkah pembuatan tidak tersedia.'
                      : meal.instructions,
                  style: TextStyle(color: color, fontSize: 14, height: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
