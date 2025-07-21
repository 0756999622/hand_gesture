import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';
import 'dart:io';

class SettingsPage extends StatefulWidget {
  final ValueChanged<ThemeMode>? onThemeChanged;
  final ValueChanged<bool>? onNotificationChanged;

  const SettingsPage({
    super.key,
    this.onThemeChanged,
    this.onNotificationChanged,
  });

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _darkMode = false;
  bool _notifications = true;
  double _sensitivity = 0.5;
  bool _isLoading = true;
  String _serverPort = '5000';
  String _connectionStatus = 'Unknown';
  String _appVersion = '1.0.0';

  String _userName = '';
  String _userEmail = '';

  late TextEditingController _ipController;
  late TextEditingController _portController;

  @override
  void initState() {
    super.initState();
    _ipController = TextEditingController();
    _portController = TextEditingController();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _darkMode = prefs.getBool('darkMode') ?? false;
      _notifications = prefs.getBool('notifications') ?? true;
      _sensitivity = prefs.getDouble('sensitivity') ?? 0.5;
      _ipController.text = prefs.getString('serverIp') ?? '';
      _serverPort = prefs.getString('serverPort') ?? '5000';
      _portController.text = _serverPort;
      _userName = prefs.getString('userName') ?? '';
      _userEmail = prefs.getString('userEmail') ?? '';
      _isLoading = false;
    });
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is bool) {
      await prefs.setBool(key, value);
      if (key == 'darkMode') {
        widget.onThemeChanged?.call(value ? ThemeMode.dark : ThemeMode.light);
      } else if (key == 'notifications') {
        widget.onNotificationChanged?.call(value);
      }
    } else if (value is double) {
      await prefs.setDouble(key, value);
    } else if (value is String) {
      await prefs.setString(key, value);
    }
  }

  Future<void> _saveServerURL() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isNotEmpty && port.isNotEmpty) {
      final url = 'http://$ip:$port/gesture';
      await prefs.setString('serverUrl', url);
      await prefs.setString('serverIp', ip);
      await prefs.setString('serverPort', port);
      _showSnackbar('Server URL saved: $url');
    } else {
      _showSnackbar('IP or Port cannot be empty');
    }
  }

  Future<void> _testWebSocketConnection() async {
    final ip = _ipController.text.trim();
    final port = _portController.text.trim();

    if (ip.isEmpty || port.isEmpty) {
      _showSnackbar('Please enter both IP and Port');
      return;
    }

    final uri = Uri.parse('ws://$ip:$port');

    try {
      final socket = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 3));
      _updateConnectionStatus('WebSocket Connected ✅');
      await socket.close();
    } on TimeoutException {
      _updateConnectionStatus('WebSocket connection timed out ❌');
    } on SocketException {
      _updateConnectionStatus('WebSocket network error ❌');
    } catch (e) {
      _updateConnectionStatus('WebSocket error: $e');
    }
  }

  void _updateConnectionStatus(String status) {
    setState(() {
      _connectionStatus = status;
    });
    _showSnackbar(status);
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
    );
  }

  Future<void> _logout() async {
    final confirmed = await showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Confirm Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Logout')),
        ],
      ),
    );

    if (confirmed == true) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
      Navigator.of(context).pushReplacementNamed('/auth');
    }
  }

  Future<void> _saveProfile(String name, String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('userName', name);
    await prefs.setString('userEmail', email);

    setState(() {
      _userName = name;
      _userEmail = email;
    });

    _showSnackbar('Profile updated successfully!');
  }

  void _showEditProfileDialog() {
    final _nameController = TextEditingController(text: _userName);
    final _emailController = TextEditingController(text: _userEmail);
    final _formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Edit Profile'),
          content: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _nameController,
                    decoration: const InputDecoration(
                      labelText: 'Name',
                      prefixIcon: Icon(Icons.person),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your name';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      prefixIcon: Icon(Icons.email),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Please enter your email';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value.trim())) {
                        return 'Please enter a valid email';
                      }
                      return null;
                    },
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Save'),
              onPressed: () {
                if (_formKey.currentState!.validate()) {
                  _saveProfile(
                    _nameController.text.trim(),
                    _emailController.text.trim(),
                  );
                  Navigator.of(context).pop();
                }
              },
            ),
          ],
        );
      },
    );
  }

  @override
  void dispose() {
    _ipController.dispose();
    _portController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        centerTitle: true,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blue, Colors.blueAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.white, Colors.grey],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: ListView(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          children: [
            // Editable Profile Info Card
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              child: ListTile(
                leading: CircleAvatar(
                  radius: 24,
                  backgroundColor: Colors.blueAccent,
                  child: Text(
                    _userName.isNotEmpty ? _userName[0] : '?',
                    style: const TextStyle(fontSize: 24, color: Colors.white),
                  ),
                ),
                title: Text(
                  _userName.isNotEmpty ? _userName : 'No Name Set',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
                subtitle:
                    Text(_userEmail.isNotEmpty ? _userEmail : 'No Email Set'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit),
                  tooltip: 'Edit Profile',
                  onPressed: _showEditProfileDialog,
                ),
              ),
            ),
            const SizedBox(height: 12),

            _buildCard(
              icon: Icons.router,
              color: Colors.blue,
              label: 'Server IP Address',
              controller: _ipController,
              onChanged: (value) async {
                await _saveSetting('serverIp', value.trim());
                await _saveServerURL();
              },
            ),
            const SizedBox(height: 12),

            _buildCard(
              icon: Icons.settings_ethernet,
              color: Colors.green,
              label: 'Server Port',
              controller: _portController,
              keyboardType: TextInputType.number,
              onChanged: (value) async {
                _serverPort = value.trim();
                await _saveSetting('serverPort', _serverPort);
                await _saveServerURL();
              },
            ),
            const SizedBox(height: 12),

            ElevatedButton.icon(
              onPressed: _testWebSocketConnection,
              icon: const Icon(Icons.wifi_tethering),
              label: const Text('Test WebSocket Connection'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 12),
                backgroundColor: Colors.blueAccent,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
            const SizedBox(height: 10),
            Center(
              child: Text(
                'Server Status: $_connectionStatus',
                style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87),
              ),
            ),

            const Divider(height: 40),

            SwitchListTile(
              title: const Text('Dark Mode'),
              secondary: const Icon(Icons.dark_mode),
              value: _darkMode,
              onChanged: (value) {
                setState(() => _darkMode = value);
                _saveSetting('darkMode', value);
              },
            ),
            const Divider(),

            SwitchListTile(
              title: const Text('Notifications'),
              secondary: const Icon(Icons.notifications),
              value: _notifications,
              onChanged: (value) {
                setState(() => _notifications = value);
                _saveSetting('notifications', value);
              },
            ),
            const Divider(),

            ListTile(
              leading: const Icon(Icons.touch_app, color: Colors.orange),
              title: const Text('Gesture Sensitivity'),
              subtitle: Slider(
                value: _sensitivity,
                min: 0.0,
                max: 1.0,
                divisions: 10,
                label: '${(_sensitivity * 100).round()}%',
                onChanged: (value) {
                  setState(() => _sensitivity = value);
                  _saveSetting('sensitivity', value);
                },
              ),
            ),

            const SizedBox(height: 20),
            ListTile(
              leading: const Icon(Icons.info_outline, color: Colors.grey),
              title: Text('Version $_appVersion'),
              subtitle: const Text('Last updated: July 2025'),
            ),

            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blueAccent,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({
    required IconData icon,
    required Color color,
    required String label,
    required TextEditingController controller,
    TextInputType keyboardType = TextInputType.text,
    required Function(String) onChanged,
  }) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: ListTile(
        leading: Icon(icon, color: color),
        title: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: label,
            border: InputBorder.none,
          ),
          keyboardType: keyboardType,
          onChanged: onChanged,
        ),
      ),
    );
  }
}
