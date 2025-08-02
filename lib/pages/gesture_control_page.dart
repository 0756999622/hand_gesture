import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math';
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
        ResolutionPreset.high,
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

  // Future<void> _onFrame(CameraImage frame) async {
  //   if (_isDetecting ||
  //       _detectionSendPort == null ||
  //       _cameraController == null ||
  //       _isPaused) {
  //     return;
  //   }

    final now = DateTime.now();
    if (now.difference(_lastProcessed).inMilliseconds < 200) return;
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

      // Fingers landmarks indexes
      const int thumbTip = 4;
      const int thumbIP = 3;
      const int indexTip = 8;
      const int indexPIP = 6;
      const int middleTip = 12;
      const int middlePIP = 10;
      const int ringTip = 16;
      const int ringPIP = 14;
      const int pinkyTip = 20;
      const int pinkyPIP = 18;

      // Fist: all fingers folded
      bool isFist = isFingerFolded(thumbTip, thumbIP) &&
          isFingerFolded(indexTip, indexPIP) &&
          isFingerFolded(middleTip, middlePIP) &&
          isFingerFolded(ringTip, ringPIP) &&
          isFingerFolded(pinkyTip, pinkyPIP);

      // Open Palm: all fingers up
      bool isOpenPalm = isFingerUp(thumbTip, thumbIP) &&
          isFingerUp(indexTip, indexPIP) &&
          isFingerUp(middleTip, middlePIP) &&
          isFingerUp(ringTip, ringPIP) &&
          isFingerUp(pinkyTip, pinkyPIP);

      // Peace Sign: index & middle up, others folded, fingers apart, thumb folded
      bool isThumbFolded = isFingerFolded(thumbTip, thumbIP);
      bool isIndexUp = isFingerUp(indexTip, indexPIP);
      bool isMiddleUp = isFingerUp(middleTip, middlePIP);
      bool isRingFolded = isFingerFolded(ringTip, ringPIP);
      bool isPinkyFolded = isFingerFolded(pinkyTip, pinkyPIP);

      double dx = (lm[indexTip].x - lm[middleTip].x).abs();
      double dy = (lm[indexTip].y - lm[middleTip].y).abs();
      bool fingersApart = dx > 0.03 && dy > 0.03;

      bool isPeace = isThumbFolded &&
          isIndexUp &&
          isMiddleUp &&
          isRingFolded &&
          isPinkyFolded &&
          fingersApart;

      String? cmd;
      IconData? icon;
      String label = 'No Gesture';

      if (isFist) {
        cmd = 'next_slide';
        icon = Icons.skip_next;
        label = 'Next Slide';
      } else if (isOpenPalm) {
        cmd = 'previous_slide';
        icon = Icons.arrow_back;
        label = 'Previous Slide';
      } else if (isPeace) {
        cmd = 'exit_fullscreen';
        icon = Icons.close_fullscreen;
        label = 'Exit Fullscreen';
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
          : Column(
              children: [
                // Camera preview with rounded bottom corners filling upper half
                ClipRRect(
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(24),
                    bottomRight: Radius.circular(24),
                  ),
                  child: SizedBox(
                    height: MediaQuery.of(context).size.height / 2,
                    width: double.infinity,
                    child: CameraPreview(_cameraController!),
                  ),
                ),

                // Info section below
                Expanded(
                  child: Container(
                    color: Colors.black87,
                    width: double.infinity,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        if (_gestureIcon != null) ...[
                          Icon(_gestureIcon, color: Colors.white, size: 60),
                          const SizedBox(height: 20),
                        ],
                        Text(
                          _gestureLabel,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          _status,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        // Additional info: connection status
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.circle,
                              color: _isConnected ? Colors.green : Colors.red,
                              size: 14,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _isConnected ? 'Connected' : 'Disconnected',
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        // Gesture tips
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 32),
                          child: Text(
                            'Use Fist for Next Slide, Open Palm for Previous Slide, Peace Sign to Exit Fullscreen.',
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
      floatingActionButton: Padding(
        padding: const EdgeInsets.only(bottom: 24, right: 16),
        child: FloatingActionButton(
          backgroundColor: Colors.blue,
          child: Icon(_isPaused ? Icons.play_arrow : Icons.pause),
          onPressed: _togglePause,
        ),
      ),
    );
  }
}
