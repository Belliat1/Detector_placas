import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;
import 'dart:math' as math;

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
  List<dynamic> _recognitions = [];
  int _imageHeight = 0;
  int _imageWidth = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  /// 📌 Inicializar la cámara
  Future<void> _initializeCamera() async {
    final cameras = await availableCameras();
    final backCamera = cameras.firstWhere(
      (cam) => cam.lensDirection == CameraLensDirection.back,
      orElse: () => cameras.first,
    );

    _cameraController = CameraController(
      backCamera,
      ResolutionPreset.medium, // 🔹 Resolución optimizada
      enableAudio: false,
    );

    await _cameraController?.initialize();

    if (mounted) {
      setState(() {});
      _startDetection();
    }
  }

  /// 📌 Cargar el modelo YOLO
  Future<void> _loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset("assets/models/yolov8n_float32.tflite");
      print("Modelo cargado correctamente");
    } catch (e) {
      print("Error cargando modelo: $e");
    }
  }

  /// 📌 Iniciar la detección en tiempo real
  void _startDetection() {
    _cameraController?.startImageStream((CameraImage image) async {
      if (!isDetecting) {
        isDetecting = true;
        await _processFrame(image);
        isDetecting = false;
      }
    });
  }

  /// 📌 Convertir CameraImage a Uint8List con `image`
  Uint8List _convertCameraImage(CameraImage image) {
    img.Image convertedImage = img.Image(image.width, image.height);

    for (int y = 0; y < image.height; y++) {
      for (int x = 0; x < image.width; x++) {
        int pixel = image.planes[0].bytes[y * image.width + x];
        convertedImage.setPixel(x, y, img.getColor(pixel, pixel, pixel));
      }
    }

    return Uint8List.fromList(img.encodePng(convertedImage));
  }

  /// 📌 Procesar cada frame y pasarlo al modelo YOLO
  Future<void> _processFrame(CameraImage image) async {
    if (_interpreter == null) return;

    Uint8List inputImage = _convertCameraImage(image);

    final output = List.generate(1, (_) => List<double>.filled(10, 0.0));

    _interpreter?.run(inputImage, output);

    _processDetections(output);
  }

  /// 📌 Interpretar las detecciones de YOLO
  void _processDetections(List<List<double>> output) {
    List<dynamic> results = [];

    for (var i = 0; i < output[0].length; i += 6) {
      if (output[0][i + 4] > 0.5) {
        results.add({
          "x": output[0][i],
          "y": output[0][i + 1],
          "width": output[0][i + 2],
          "height": output[0][i + 3],
          "confidence": output[0][i + 4],
          "label": "Placa",
        });
      }
    }

    setState(() {
      _recognitions = results;
    });
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    Size screen = MediaQuery.of(context).size;

    return Scaffold(
      body: _cameraController?.value.isInitialized == true
          ? Stack(
              children: [
                /// 📌 Mostrar la vista previa de la cámara en pantalla completa
                Positioned.fill(
                  child: CameraPreview(_cameraController!),
                ),

                /// 📌 Dibujar las detecciones en la pantalla
                ..._recognitions.map((detection) {
                  return Positioned(
                    left: detection["x"] * screen.width,
                    top: detection["y"] * screen.height,
                    child: Container(
                      width: detection["width"] * screen.width,
                      height: detection["height"] * screen.height,
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.red, width: 3),
                      ),
                    ),
                  );
                }).toList(),
              ],
            )
          : Center(child: CircularProgressIndicator()),
    );
  }
}
