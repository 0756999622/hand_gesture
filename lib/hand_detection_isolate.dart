//import 'dart:isolate';
import 'package:hand_landmarker/hand_landmarker.dart';

void handDetectionEntryPoint(SendPort sendPort) {
  final plugin = HandLandmarkerPlugin.create();

  final port = ReceivePort();
  sendPort.send(port.sendPort);

  port.listen((message) {
    final data = message[0] as Map;
    final SendPort replyTo = message[1];

    try {
      final frame = data['frame'];
      final orientation = data['sensorOrientation'];

      final hands = plugin.detect(frame, orientation);
      replyTo.send(hands);
    } catch (e) {
      replyTo.send([]);
    }
  });
}
