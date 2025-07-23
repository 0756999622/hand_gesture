import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutPage extends StatelessWidget {
  const AboutPage({super.key});

  // Constants
  static const String _appName = 'Edusense';
  static const String _appDescription =
      'Edusense is a gesture-controlled mobile app that lets you effortlessly control your presentation slides using simple swipes and taps. Designed to keep presenters mobile and engaged, it empowers you to move freely while seamlessly navigating your slides projected on any screen.';
  static const String _developerName = 'GROUP 32 MAKERERE UNIVERSITY';
  static const String _supportEmail = 'mwesigway2001@gmail.com';
  static const String _websiteUrl = 'https://okwirfrances.github.io/';
  static const String _twitterUrl = 'https://twitter.com/EdusenseApp';
  static const String _linkedinUrl = 'https://linkedin.com/company/edusense';
  static const String _privacyPolicyUrl = 'https://www.edusense.com/privacy';
  static const String _termsUrl = 'https://www.edusense.com/terms';
  static const String _copyright = '© 2025 Edusense\nAll rights reserved';

  Future<PackageInfo> _getPackageInfo() async {
    return await PackageInfo.fromPlatform();
  }

  void _launchUrl(BuildContext context, String url) async {
    try {
      if (await canLaunchUrl(Uri.parse(url))) {
        await launchUrl(Uri.parse(url));
      } else {
        throw 'Could not launch $url';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'About Edusense',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue.shade800, Colors.blue.shade600],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.grey[200]!, Colors.grey[300]!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: FutureBuilder<PackageInfo>(
          future: _getPackageInfo(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }

            final version = snapshot.data?.version ?? '1.0.0';
            final buildNumber = snapshot.data?.buildNumber ?? '1';

            return SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Icon and Name
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [Colors.white, Colors.grey[50]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 12,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: LinearGradient(
                              colors: [
                                Colors.blue.shade700,
                                Colors.blue.shade500
                              ],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.blue.withOpacity(0.3),
                                blurRadius: 10,
                                spreadRadius: 2,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.gesture,
                            size: 48,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _appName,
                          style: TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Version $version (Build $buildNumber)',
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Description
                  _buildSectionCard(
                    title: 'Description',
                    child: const Text(
                      _appDescription,
                      style: TextStyle(fontSize: 16),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Developer Info
                  _buildSectionCard(
                    title: 'Developer / Company Info',
                    child: Column(
                      children: [
                        _infoTile('Developer', _developerName),
                        _linkTile(
                          context,
                          'Email',
                          _supportEmail,
                          'mailto:$_supportEmail',
                        ),
                        _linkTile(
                          context,
                          'Website',
                          'https://okwirfrances.github.io/',
                          _websiteUrl,
                        ),
                        _linkTile(
                          context,
                          'Twitter',
                          '@EdusenseApp',
                          _twitterUrl,
                        ),
                        _linkTile(
                          context,
                          'LinkedIn',
                          'Edusense Company',
                          _linkedinUrl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Features Summary
                  _buildSectionCard(
                    title: 'App Features Summary',
                    child: Column(
                      children: [
                        _bulletPoint('Swipe left/right to navigate slides'),
                        _bulletPoint('Swipe up to start the presentation'),
                        _bulletPoint('Swipe down to end the presentation'),
                        _bulletPoint('Tap to pause or resume slides'),
                        _bulletPoint(
                            'Double tap to blackout/unblackout screen'),
                        _bulletPoint(
                            'Promotes presenter mobility and engagement'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Privacy Policy
                  _buildSectionCard(
                    title: 'Privacy Policy / Terms of Use',
                    child: Column(
                      children: [
                        const Text(
                          'We respect your privacy. Edusense collects minimal data necessary for app functionality.',
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        _linkTile(
                          context,
                          'Privacy Policy',
                          'View here',
                          _privacyPolicyUrl,
                        ),
                        _linkTile(
                          context,
                          'Terms & Conditions',
                          'View here',
                          _termsUrl,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Licenses
                  ElevatedButton(
                    onPressed: () {
                      showLicensePage(
                        context: context,
                        applicationName: _appName,
                        applicationVersion: version,
                      );
                    },
                    child: const Text('View Licenses'),
                  ),

                  const SizedBox(height: 24),

                  // Copyright
                  Text(
                    _copyright,
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildSectionCard({required String title, required Widget child}) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }

  // Helper widget for bullet points
  Widget _bulletPoint(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          const Icon(Icons.check_circle, size: 20, color: Colors.blueAccent),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Helper widget for info tiles
  Widget _infoTile(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Text(
            '$title: ',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
          ),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 16))),
        ],
      ),
    );
  }

  // Helper widget for link tiles
  Widget _linkTile(
      BuildContext context, String title, String display, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(context, url),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Text(
              '$title: ',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            Expanded(
              child: Text(
                display,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.blueAccent,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
