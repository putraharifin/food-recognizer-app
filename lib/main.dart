import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:food_recognizer_app/firebase_options.dart';
import 'package:food_recognizer_app/providers/camera_provider.dart';
import 'package:food_recognizer_app/providers/classifier_provider.dart';
import 'package:food_recognizer_app/ui/screens/home_screen.dart';
import 'package:provider/provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider<CameraProvider>(create: (_) => CameraProvider()),
        ChangeNotifierProvider<ClassifierProvider>(
          create: (_) => ClassifierProvider()..prepare(),
        ),
      ],
      child: const FoodRecognizerApp(),
    ),
  );
}

class FoodRecognizerApp extends StatelessWidget {
  const FoodRecognizerApp({super.key});

  static const Color _navy = Color(0xFF2D3E50);
  static const Color _background = Color(0xFFEFF6FA);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Food Recognizer App',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: _navy,
          primary: _navy,
          surface: _background,
        ),
        scaffoldBackgroundColor: _background,
        appBarTheme: const AppBarTheme(
          backgroundColor: _navy,
          foregroundColor: Colors.white,
          centerTitle: false,
          titleTextStyle: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w600,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: _navy,
            foregroundColor: Colors.white,
            disabledBackgroundColor: _navy.withAlpha(90),
            disabledForegroundColor: Colors.white70,
            minimumSize: const Size.fromHeight(48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
