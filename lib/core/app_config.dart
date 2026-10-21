class AppConfig {
  const AppConfig._();

  /// Lokasi berkas model di Firebase Cloud Storage.
  static const String modelStoragePath = 'models/food_classifier.tflite';

  /// Nama berkas model setelah diunduh ke penyimpanan lokal perangkat.
  static const String modelFileName = 'food_classifier.tflite';

  /// Opsional: URL model di Firebase Hosting (dipakai bila Storage gagal).
  /// Contoh: https://food-recognizer-app-8eb6f.web.app/food_classifier.tflite
  static const String modelHostingUrl =
      'https://food-recognizer-app-8eb6f.web.app/food_classifier.tflite';

  /// Berkas label yang diletakkan di folder assets/.
  static const String labelsAsset = 'assets/labels.csv';

  static const String mealDbBaseUrl = 'https://www.themealdb.com/api/json/v1/1';

  static const List<String> geminiModels = [
    'gemini-3.8-flash',
    'gemini-3.5-flash-lite',
  ];

  /// API Key tidak disematkan di kode.
  /// Jalankan: flutter run --dart-define=GEMINI_API_KEY=KUNCI_ANDA
  static const String geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');
}
