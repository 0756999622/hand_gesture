import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

// Local page imports
import 'pages/auth_page.dart';
import 'pages/splash_screen.dart';
import 'pages/settings_page.dart';
import 'pages/about_page.dart';
import 'pages/gesture_control_page.dart';
import 'pages/screen_gestures_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    runApp(const GestureApp());
  } catch (e) {
    debugPrint('Error initializing app: $e');
    runApp(MaterialApp(
      home: Scaffold(
        body: Center(
          child: Text(
            'Failed to initialize app.\nError: $e',
            style: TextStyle(fontSize: 16),
          ),
        ),
      ),
    ));
  }
}

class GestureApp extends StatefulWidget {
  const GestureApp({super.key});

  @override
  State<GestureApp> createState() => _GestureAppState();
}

class _GestureAppState extends State<GestureApp> {
  final ValueNotifier<ThemeMode> _themeNotifier =
      ValueNotifier(ThemeMode.light);

  @override
  void initState() {
    super.initState();
    _loadThemeMode();
  }

  Future<void> _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    final themeStr = prefs.getString('themeMode') ?? 'ThemeMode.light';
    _themeNotifier.value =
        themeStr == 'ThemeMode.dark' ? ThemeMode.dark : ThemeMode.light;
  }

  void _toggleTheme(ThemeMode mode) async {
    _themeNotifier.value = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('themeMode', mode.toString());
  }

  @override
  void dispose() {
    _themeNotifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: _themeNotifier,
      builder: (context, themeMode, child) {
        return MaterialApp(
          title: 'Edusense Gesture Controller',
          debugShowCheckedModeBanner: false,
          themeMode: themeMode,
          theme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
            useMaterial3: true,
          ),
          darkTheme: ThemeData(
            fontFamily: 'Roboto',
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
            useMaterial3: true,
          ),
          initialRoute: '/splash',
          routes: {
            '/splash': (context) => const SplashScreen(),
            '/auth': (context) => const AuthPage(),
            '/gesture-control': (context) => const GestureControlPage(),
            '/screen-gestures': (context) => const ScreenGesturesPage(),
            '/settings': (context) =>
                SettingsPage(onThemeChanged: _toggleTheme),
            '/about': (context) => const AboutPage(),
          },
          onUnknownRoute: (settings) => MaterialPageRoute(
            builder: (context) => const Scaffold(
              body: Center(
                child: Text(
                  'Page not found',
                  style: TextStyle(fontSize: 18),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
