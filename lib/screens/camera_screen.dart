import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'package:google_ml_kit/google_ml_kit.dart';

class CameraScreen extends StatefulWidget {
  final List<String> plates;

  const CameraScreen({Key? key, required this.plates}) : super(key: key);

  @override
  _CameraScreenState createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  bool isDetecting = false;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  List<Map<String, dynamic>> _recognitions = [];
  int rotation = 90; // Mantener orientación correcta

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.high,
      enableAudio: false,
    );

    await _cameraController?.initialize();
    if (mounted) {
      setState(() {});
      _startDetection();
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset("assets/models/yolov8n_float32.tflite");
      print("✅ Modelo cargado correctamente");
    } catch (e) {
      print("❌ Error cargando modelo: $e");
    }
  }

  void _startDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (!isDetecting) {
        isDetecting = true;
        await _processFrame(image);
        isDetecting = false;
      }
    });
  }

  img.Image _convertCameraImage(CameraImage image) {
    img.Image imgBuffer = img.Image.fromBytes(
      image.width,
      image.height,
      image.planes[0].bytes,
      format: img.Format.rgb,
    );

    img.Image rotatedImg;
    if (rotation == 90) {
      rotatedImg = img.copyRotate(imgBuffer, -90);
    } else if (rotation == -90) {
      rotatedImg = img.copyRotate(imgBuffer, 90);
    } else {
      rotatedImg = imgBuffer;
    }

    return img.copyResize(rotatedImg, width: 640, height: 640);
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_interpreter == null) return;

    img.Image inputImage = _convertCameraImage(image);
    Uint8List inputBytes = Uint8List.fromList(img.encodeJpg(inputImage));

    final input = Float32List(640 * 640 * 3);
    for (var i = 0; i < inputBytes.length; i++) {
      input[i] = inputBytes[i] / 255.0; // Normalizar a [0, 1]
    }

    final output = List.generate(1, (_) => List.filled(25200, 0.0));

    _interpreter?.run(input.reshape([1, 640, 640, 3]), output);

    _processDetections(output[0], image.width, image.height, inputImage);
  }

  void _processDetections(
      List<double> output, int imageWidth, int imageHeight, img.Image fullImage) async {
    List<Map<String, dynamic>> results = [];

    for (var i = 0; i < output.length; i += 7) {
      double confidence = output[i + 4];
      int classId = output[i + 6].toInt();

      if (confidence > 0.5) {
        String label = _getLabel(classId);

        if (label == "car" || label == "motorcycle" || label == "truck") {
          double x = output[i] * imageWidth;
          double y = output[i + 1] * imageHeight;
          double w = output[i + 2] * imageWidth;
          double h = output[i + 3] * imageHeight;

          String plateText = "";
          try {
            plateText = await _performOCR(fullImage, x, y, w, h);
          } catch (e) {
            print("OCR Error: $e");
          }

          results.add({
            "x": x,
            "y": y,
            "width": w,
            "height": h,
            "confidence": confidence,
            "label": label,
            "plate": plateText,
          });
        }
      }
    }

    setState(() {
      _recognitions = results;
    });
  }

  String _getLabel(int classId) {
    switch (classId) {
      case 2:
        return "car";
      case 3:
        return "motorcycle";
      case 7:
        return "truck";
      default:
        return "unknown";
    }
  }

  Future<String> _performOCR(
      img.Image inputImage, double x, double y, double w, double h) async {
    int plateX = x.toInt() + (w * 0.1).toInt();
    int plateY = y.toInt() + (h * 0.6).toInt();
    int plateW = (w * 0.8).toInt();
    int plateH = (h * 0.3).toInt();

    plateX = plateX.clamp(0, inputImage.width - plateW);
    plateY = plateY.clamp(0, inputImage.height - plateH);
    plateW = plateW.clamp(0, inputImage.width - plateX);
    plateH = plateH.clamp(0, inputImage.height - plateY);

    final croppedPlate = img.copyCrop(inputImage, plateX, plateY, plateW, plateH);

    final inputImageForOCR = InputImage.fromBytes(
      bytes: Uint8List.fromList(img.encodeJpg(croppedPlate)),
      metadata: InputImageMetadata(
        size: Size(croppedPlate.width.toDouble(), croppedPlate.height.toDouble()),
        rotation: InputImageRotation.rotation90deg,
        format: InputImageFormat.yuv420, // Corregido de jpeg a yuv420
        bytesPerRow: croppedPlate.width, // Obligatorio
      ),
    );

    try {
      final RecognizedText recognizedText =
          await textRecognizer.processImage(inputImageForOCR);
      return recognizedText.text;
    } catch (e) {
      print("OCR Error: $e");
      return "";
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          RotatedBox(
            quarterTurns: rotation ~/ 90,
            child: CameraPreview(_cameraController!),
          ),
          ..._recognitions.map((detection) {
            return Positioned(
              left: detection["x"] - detection["width"] / 2,
              top: detection["y"] - detection["height"] / 2,
              child: Column(
                children: [
                  Container(
                    width: detection["width"],
                    height: detection["height"],
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.red, width: 3),
                    ),
                  ),
                  Text(
                    "${detection["label"]}: ${detection["plate"]}",
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
