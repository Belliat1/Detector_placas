import 'dart:typed_data';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:ffi' as ffi;


class MLModel {
  late Interpreter _yoloInterpreter;

  Future<void> loadModels() async {
    _yoloInterpreter = await Interpreter.fromAsset('assets/models/yolov5su_float32.tflite');
  }

  Future<List<Map<String, dynamic>>> detectObjects(Uint8List imageBytes) async {
    var input = [imageBytes.map((e) => e / 255.0).toList()];
    var output = List.generate(1, (_) => List.filled(25200, 0.0));

    _yoloInterpreter.run(input, output);
    return _parseDetections(output);
  }

    List<Map<String, dynamic>> _parseDetections(List<List<double>> output) {
      List<Map<String, dynamic>> detections = [];

      for (var detection in output[0]) {
        if (detection is double && detection > 0.5) {
          detections.add({"label": "Placa", "confidence": detection});
        }
      }

      return detections;
    }



}
