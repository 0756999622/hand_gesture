import 'package:flutter/material.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

class ScreenGesturesPage extends StatefulWidget {
  const ScreenGesturesPage({super.key});

  @override
  State<ScreenGesturesPage> createState() => _ScreenGesturesPageState();
}

class _ScreenGesturesPageState extends State<ScreenGesturesPage> {
  String? _serverIp;
  int _serverPort = 5000; // default value, will be updated dynamically
  String _status = 'No action yet';

  WebSocketChannel? _channel;

  @override
  void initState() {
    super.initState();
    _loadServerConfig();
  }

  Future<void> _loadServerConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final ip = prefs.getString('serverIp');
    final portStr = prefs.getString('serverPort') ?? '5000';
    final port = int.tryParse(portStr) ?? 5000;
    setState(() {
      _serverIp = ip;
      _serverPort = port;
      _connectWebSocket();
    });
  }

  void _connectWebSocket() {
    if (_serverIp == null || _serverIp!.isEmpty) {
      setState(() => _status = 'Server IP not set');
      return;
    }

    final url = 'ws://$_serverIp:$_serverPort';

    try {
      _channel?.sink.close();
      _channel = WebSocketChannel.connect(Uri.parse(url));
      setState(() => _status = 'WebSocket connected');
      _channel!.stream.listen(
        (message) {
          print('Server says: $message');
        },
        onError: (error) {
          print('WebSocket error: $error');
          setState(() => _status = 'WebSocket error');
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        },
        onDone: () {
          print('WebSocket closed');
          setState(() => _status = 'WebSocket disconnected');
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        },
      );
    } catch (e) {
      print('WebSocket connection failed: $e');
      setState(() => _status = 'WebSocket connection failed');
    }
  }

  void sendCommand(String cmd) {
    if (_channel == null) {
      _updateStatus('WebSocket not connected');
      return;
    }

    Map<String, String> commandMap = {
      'next': 'next_slide',
      'previous': 'previous_slide',
      'swipe_up': 'start_slide',
      'start': 'start_slide',
      'swipe_down': 'end_slide',
      'end': 'end_slide',
      'tap': 'pause_slide',
      'pause': 'pause_slide',
      'blackout': 'blackout',
    };

    String? serverCommand = commandMap[cmd.toLowerCase()];
    if (serverCommand == null) {
      _updateStatus('Unknown command "$cmd"');
      return;
    }

    final data = '{"command": "$serverCommand"}';
    _channel!.sink.add(data);
    _updateStatus('Sent command: $serverCommand');
  }

  void _updateStatus(String action) {
    setState(() {
      _status = 'Last action: $action';
    });
    debugPrint(action);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Screen Gestures',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () async {
              await Navigator.pushNamed(context, '/settings');
              await _loadServerConfig(); // Reload IP and Port after returning
            },
          ),
        ],
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
        child: Column(
          children: [
            Expanded(child: _buildGestureArea()),
            Container(
              margin: const EdgeInsets.all(16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.white, Colors.grey[50]!],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
                border: Border.all(
                  color: Colors.grey[300]!,
                  width: 1,
                ),
              ),
              child: Text(
                _status,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[800],
                ),
                textAlign: TextAlign.center,
              ),
            ),
            _buildControlButtons(),
          ],
        ),
      ),
    );
  }

  Widget _buildGestureArea() {
    return GestureDetector(
      onPanEnd: (details) {
        final velocity = details.velocity.pixelsPerSecond;
        if (velocity.dx.abs() > velocity.dy.abs()) {
          if (velocity.dx > 0) {
            sendCommand('previous');
          } else {
            sendCommand('next');
          }
        } else {
          if (velocity.dy > 0) {
            sendCommand('end');
          } else {
            sendCommand('start');
          }
        }
      },
      onTap: () => sendCommand('pause'),
      onDoubleTap: () => sendCommand('blackout'),
      child: Container(
        margin: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.blue.shade600, Colors.blue.shade400],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'Try gestures:\n'
            'Swipe Left → Next Slide\n'
            'Swipe Right → Previous Slide\n'
            'Swipe Up → Start Presentation\n'
            'Swipe Down → End Presentation\n'
            'Tap → Pause/Resume\n'
            'Double Tap → Blackout Screen',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              color: Colors.white,
              fontWeight: FontWeight.w600,
              shadows: [
                Shadow(
                  blurRadius: 8,
                  color: Colors.black26,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildControlButtons() {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: GridView.count(
        crossAxisCount: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
        children: [
          _buildControlButton(
            icon: Icons.play_arrow,
            colors: [Colors.green.shade600, Colors.green.shade400],
            onPressed: () => sendCommand('start'),
          ),
          _buildControlButton(
            icon: Icons.stop,
            colors: [Colors.red.shade600, Colors.red.shade400],
            onPressed: () => sendCommand('end'),
          ),
          _buildControlButton(
            icon: Icons.visibility_off,
            colors: [Colors.grey.shade800, Colors.grey.shade600],
            onPressed: () => sendCommand('blackout'),
          ),
          _buildControlButton(
            icon: Icons.pause,
            colors: [Colors.orange.shade600, Colors.orange.shade400],
            onPressed: () => sendCommand('pause'),
          ),
        ],
      ),
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required List<Color> colors,
    required VoidCallback onPressed,
  }) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          boxShadow: [
            BoxShadow(
              color: colors.first.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(icon, color: Colors.white, size: 32),
      ),
    );
  }

  @override
  void dispose() {
    _channel?.sink.close();
    super.dispose();
  }
}
