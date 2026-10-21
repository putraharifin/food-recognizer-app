import 'package:flutter_test/flutter_test.dart';
import 'package:food_recognizer_app/core/formatters.dart';

void main() {
  test('formatPercent menampilkan dua desimal', () {
    expect(formatPercent(0.6192), '61.92%');
  });

  test('toTitleCase mengubah huruf awal tiap kata', () {
    expect(toTitleCase('nasi lemak'), 'Nasi Lemak');
  });
}
