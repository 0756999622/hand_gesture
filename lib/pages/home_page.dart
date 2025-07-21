import 'package:flutter/material.dart';
import 'gesture_control_page.dart';
import 'screen_gestures_page.dart';
import 'settings_page.dart';
import 'about_page.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key, this.onThemeChanged});

  final ValueChanged<ThemeMode>? onThemeChanged;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // ======= AppBar with Gradient, Logo & Actions =======
      appBar: AppBar(
        elevation: 6,
        backgroundColor: Colors.transparent,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1E3C72), Color(0xFF2A5298)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: Border(
              bottom: BorderSide(color: Colors.white24, width: 1),
            ),
          ),
        ),
        centerTitle: true,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/logo.png', // Replace with your logo asset path
              height: 32,
              width: 32,
              fit: BoxFit.contain,
            ),
            const SizedBox(width: 8),
            Text(
              'EDUSENSE',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                    letterSpacing: 1.3,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.brightness_6),
            tooltip: 'Toggle Light/Dark Theme',
            onPressed: () {
              if (onThemeChanged != null) {
                final brightness = Theme.of(context).brightness;
                onThemeChanged!(brightness == Brightness.dark
                    ? ThemeMode.light
                    : ThemeMode.dark);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            tooltip: 'Open Settings',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => SettingsPage(onThemeChanged: onThemeChanged),
                ),
              );
            },
          ),
        ],
      ),

      // ======= Body with Background & Content =======
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.asset(
              'assets/images/mj2.webp', // Replace with your background image
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.5),
              colorBlendMode: BlendMode.darken,
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Row(
                children: [
                  // Left side: Welcome texts and footer in a column
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        const SizedBox(height: 24),
                        Text(
                          'Welcome to EduSense',
                          style: Theme.of(context)
                              .textTheme
                              .headlineMedium
                              ?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.7),
                                offset: const Offset(2, 2),
                                blurRadius: 4,
                              )
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Enhance your presentation experience with seamless gesture navigation.',
                          style:
                              Theme.of(context).textTheme.bodyLarge?.copyWith(
                            color: Colors.white70,
                            fontStyle: FontStyle.italic,
                            shadows: [
                              Shadow(
                                color: Colors.black.withOpacity(0.4),
                                offset: const Offset(1, 1),
                                blurRadius: 3,
                              )
                            ],
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const Spacer(),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            '© 2025 EduSense. All rights reserved.',
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: Colors.white54,
                                      fontStyle: FontStyle.italic,
                                    ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Right side: Vertical circular buttons
                  Align(
                    alignment: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildCircularButton(
                            context: context,
                            icon: Icons.camera_alt,
                            label: 'Gesture Control',
                            color: Colors.blue.shade700,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const GestureControlPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildCircularButton(
                            context: context,
                            icon: Icons.touch_app,
                            label: 'Screen Gestures',
                            color: Colors.green.shade700,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const ScreenGesturesPage(),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildCircularButton(
                            context: context,
                            icon: Icons.settings,
                            label: 'Settings',
                            color: Colors.orange.shade700,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => SettingsPage(
                                    onThemeChanged: onThemeChanged),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          _buildCircularButton(
                            context: context,
                            icon: Icons.info,
                            label: 'About',
                            color: Colors.purple.shade700,
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => const AboutPage(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCircularButton({
    required BuildContext context,
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          shape: const CircleBorder(),
          elevation: 8,
          shadowColor: color.withOpacity(0.6),
          color: color,
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Icon(icon, color: Colors.white, size: 32),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 14,
            color: Colors.white,
            shadows: [
              Shadow(
                color: Colors.black45,
                offset: Offset(1, 1),
                blurRadius: 2,
              )
            ],
          ),
        ),
      ],
    );
  }
}
