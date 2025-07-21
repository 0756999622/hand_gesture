import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:web_socket_channel/status.dart' as status;

import '../hand_detection_isolate.dart';

class GestureControlPage extends StatefulWidget {
  const GestureControlPage({super.key});

  @override
  State<GestureControlPage> createState() => _GestureControlPageState();
}

class _GestureControlPageState extends State<GestureControlPage> {
  CameraController? _cameraController;
  bool _isDetecting = false;
  bool _isPaused = false;

  String _status = 'Loading camera…';
  String _gestureLabel = 'No Gesture';
  IconData? _gestureIcon;

  String? _serverIp;
  String _serverPort = '5000';
  DateTime _lastProcessed = DateTime.now();

  WebSocketChannel? _channel;
  StreamSubscription? _channelSubscription;
  bool _isConnected = false;

  Isolate? _detectionIsolate;
  SendPort? _detectionSendPort;

  @override
  void initState() {
    super.initState();
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    await _loadServerSettings();
    _connectWebSocket();
    await _initializeCamera();
    await _startDetectionIsolate();
  }

  Future<void> _loadServerSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _serverIp = prefs.getString('serverIp');
      _serverPort = prefs.getString('serverPort') ?? '5000';

      if (_serverIp == null || _serverIp!.isEmpty) {
        _status = 'No Server IP set';
      }
    });
  }

  void _connectWebSocket() {
    if (_serverIp == null || _serverIp!.isEmpty) {
      setState(() {
        _status = 'No Server IP for WebSocket';
        _isConnected = false;
      });
      return;
    }

    final url = 'ws://$_serverIp:$_serverPort';
    try {
      _channel?.sink.close(status.goingAway);
      _channel = WebSocketChannel.connect(Uri.parse(url));
      setState(() {
        _status = 'Connected to $url';
        _isConnected = true;
      });

      _channelSubscription = _channel!.stream.listen(
        (message) {
          debugPrint('Received: $message');
        },
        onError: (error) {
          debugPrint('WebSocket error: $error');
          setState(() {
            _status = 'WebSocket error, reconnecting...';
            _isConnected = false;
          });
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        },
        onDone: () {
          debugPrint('WebSocket closed');
          setState(() {
            _status = 'WebSocket disconnected, reconnecting...';
            _isConnected = false;
          });
          Future.delayed(const Duration(seconds: 5), _connectWebSocket);
        },
      );
    } catch (e) {
      debugPrint('Connection failed: $e');
      setState(() {
        _status = 'Connection failed';
        _isConnected = false;
      });
    }
  }

  Future<void> _initializeCamera() async {
    try {
      final cameras = await availableCameras();
      final frontCamera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.front,
        orElse: () => cameras.first,
      );

      _cameraController = CameraController(
        frontCamera,
        ResolutionPreset.high, // Use high resolution for better view
        enableAudio: false,
      );

      await _cameraController!.initialize();
      await _cameraController!.startImageStream(_onFrame);

      if (mounted) setState(() => _status = 'Ready');
    } catch (e) {
      setState(() => _status = 'Camera error: $e');
    }
  }

  Future<void> _startDetectionIsolate() async {
    final receivePort = ReceivePort();
    _detectionIsolate = await Isolate.spawn(
      handDetectionEntryPoint,
      receivePort.sendPort,
    );
    _detectionSendPort = await receivePort.first as SendPort;
  }

  Future<void> _onFrame(CameraImage frame) async {
    if (_isDetecting ||
        _detectionSendPort == null ||
        _cameraController == null ||
        _isPaused) return;

    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 100) return;
    _lastProcessed = now;

    _isDetecting = true;

    final responsePort = ReceivePort();

    _detectionSendPort!.send([
      {
        'frame': frame,
        'sensorOrientation': _cameraController!.description.sensorOrientation,
      },
      responsePort.sendPort,
    ]);

    final hands = await responsePort.first;

    if (hands.isNotEmpty) {
      final lm = hands.first.landmarks;

      bool isFingerUp(int tip, int pip) => lm[tip].y < lm[pip].y;
      bool isFingerFolded(int tip, int pip) => lm[tip].y > lm[pip].y;

      bool isOpenPalm = isFingerUp(4, 3) &&
          isFingerUp(8, 6) &&
          isFingerUp(12, 10) &&
          isFingerUp(16, 14) &&
          isFingerUp(20, 18);

      bool isVictory = isFingerUp(8, 6) &&
          isFingerUp(12, 10) &&
          isFingerFolded(16, 14) &&
          isFingerFolded(20, 18);

      double dx = (lm[4].x - lm[8].x).abs();
      double dy = (lm[4].y - lm[8].y).abs();
      bool isOK = dx < 0.12 && dy < 0.12;

      bool isFist = isFingerFolded(4, 3) &&
          isFingerFolded(8, 6) &&
          isFingerFolded(12, 10) &&
          isFingerFolded(16, 14) &&
          isFingerFolded(20, 18);

      String? cmd;
      IconData? icon;
      String label = 'No Gesture';

      if (isOpenPalm) {
        cmd = 'start_slide';
        icon = Icons.play_circle_fill;
        label = 'Start Slide';
      } else if (isVictory) {
        cmd = 'next_slide';
        icon = Icons.arrow_forward;
        label = 'Next Slide';
      } else if (isOK) {
        cmd = 'previous_slide';
        icon = Icons.arrow_back;
        label = 'Previous Slide';
      } else if (isFist) {
        cmd = 'stop_slide';
        icon = Icons.stop_circle;
        label = 'Stop Slide';
      }

      if (cmd != null) {
        _sendCommand(cmd);
        if (mounted) {
          setState(() {
            _gestureLabel = label;
            _gestureIcon = icon;
            _status = 'Gesture: $cmd';
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _gestureLabel = 'No Gesture';
            _gestureIcon = null;
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _gestureLabel = 'No Gesture';
          _gestureIcon = null;
        });
      }
    }

    _isDetecting = false;
  }

  void _sendCommand(String command) {
    if (_channel == null) {
      debugPrint('WebSocket not connected');
      return;
    }
    final data = jsonEncode({'command': command});
    _channel!.sink.add(data);
  }

  void _togglePause() {
    setState(() {
      _isPaused = !_isPaused;
      _status = _isPaused ? 'Detection Paused' : 'Ready';
      if (_isPaused) {
        _gestureLabel = 'Paused';
        _gestureIcon = Icons.pause_circle_filled;
      } else {
        _gestureLabel = 'No Gesture';
        _gestureIcon = null;
      }
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _channelSubscription?.cancel();
    _channel?.sink.close(status.goingAway);
    _detectionIsolate?.kill(priority: Isolate.immediate);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: _cameraController == null || !_cameraController!.value.isInitialized
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Make camera preview fill the entire screen
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),

                // Connection status top left
                Positioned(
                  top: 40,
                  left: 20,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.circle,
                            color: _isConnected ? Colors.green : Colors.red,
                            size: 14),
                        const SizedBox(width: 6),
                        Text(
                          _isConnected ? 'Connected' : 'Disconnected',
                          style: const TextStyle(
                              color: Colors.white, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),

                // Pause/Resume button and settings top right
                Positioned(
                  top: 40,
                  right: 20,
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(_isPaused ? Icons.play_arrow : Icons.pause,
                            color: Colors.white, size: 28),
                        onPressed: _togglePause,
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.settings,
                            color: Colors.white, size: 28),
                        onPressed: () async {
                          await Navigator.pushNamed(context, '/settings');
                          await _loadServerSettings();
                          _connectWebSocket();
                        },
                      ),
                    ],
                  ),
                ),

                // Gesture label bottom left
                Positioned(
                  bottom: 30,
                  left: 20,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_gestureIcon != null) ...[
                          Icon(_gestureIcon, color: Colors.white, size: 28),
                          const SizedBox(width: 10),
                        ],
                        Text(
                          _gestureLabel,
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 20,
                              fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                  ),
                ),

                // Bottom status bar center
                Positioned(
                  bottom: 10,
                  left: 0,
                  right: 0,
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _status,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 14),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
