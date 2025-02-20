import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart' as tfl;
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
  tfl.Interpreter? _interpreter;
  bool isDetecting = false;
  final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
  List<Map<String, dynamic>> _recognitions = [];
  String debugMessage = "📸 Iniciando...";
  int frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _loadModel();
  }

  Future<void> _initializeCamera() async {
    try {
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
        setState(() {
          debugMessage = "✅ Cámara lista";
        });
        _startDetection();
      }
    } catch (e) {
      setState(() {
        debugMessage = "❌ Error inicializando cámara: $e";
      });
      print("❌ Error inicializando cámara: $e");
    }
  }

  Future<void> _loadModel() async {
    try {
      _interpreter = await tfl.Interpreter.fromAsset("assets/models/yolov2_tiny.tflite");
      setState(() {
        debugMessage = "✅ Modelo cargado";
      });
      print("✅ Modelo cargado correctamente.");
    } catch (e) {
      setState(() {
        debugMessage = "❌ Error cargando modelo: $e";
      });
      print("❌ Error cargando modelo: $e");
    }
  }

  void _startDetection() {
    if (_cameraController == null || !_cameraController!.value.isInitialized) {
      setState(() {
        debugMessage = "❌ Cámara no lista";
      });
      print("❌ Cámara no está lista para detección.");
      return;
    }

    _cameraController?.startImageStream((CameraImage image) async {
      if (!isDetecting) {
        isDetecting = true;
        print("🖼️ Frame capturado: #$frameCount");

        await _processFrame(image);
        isDetecting = false;
      }
    });
  }

  Future<void> _processFrame(CameraImage image) async {
    if (_interpreter == null) {
      setState(() {
        debugMessage = "❌ Modelo no cargado";
      });
      print("❌ Modelo no cargado.");
      return;
    }

    try {
      setState(() {
        debugMessage = "📸 Procesando frame...";
      });

      img.Image inputImage = _convertCameraImage(image);
      Float32List input = _preprocessImage(inputImage);

      final output = List.generate(1, (_) => List.filled(13 * 13 * (5 * (20 + 5)), 0.0));

      await Future.delayed(const Duration(milliseconds: 50)); // 🔥 Evita bloqueos

      _interpreter?.run(input.buffer.asFloat32List(), output[0]);
      _processDetections(output[0], image.width, image.height, inputImage);
    } catch (e) {
      setState(() {
        debugMessage = "❌ Error procesando frame: $e";
      });
      print("❌ Error procesando frame: $e");
    }
  }

  img.Image _convertCameraImage(CameraImage image) {
    print("🔄 Convirtiendo imagen...");

    img.Image imgBuffer = img.Image.fromBytes(
      image.width,
      image.height,
      Uint8List.fromList(image.planes[0].bytes),
      format: img.Format.rgb,
    );

    img.Image rotatedImg = img.copyRotate(imgBuffer, 90);
    return img.copyResize(rotatedImg, width: 416, height: 416);
  }

  Float32List _preprocessImage(img.Image image) {
    print("🎨 Preprocesando imagen...");
    Float32List input = Float32List(416 * 416 * 3);
    int pixelIndex = 0;

    for (int y = 0; y < 416; y++) {
      for (int x = 0; x < 416; x++) {
        final pixel = image.getPixel(x, y);
        input[pixelIndex++] = img.getRed(pixel) / 255.0;
        input[pixelIndex++] = img.getGreen(pixel) / 255.0;
        input[pixelIndex++] = img.getBlue(pixel) / 255.0;
      }
    }
    return input;
  }

  void _processDetections(List<double> output, int imageWidth, int imageHeight, img.Image fullImage) async {
    print("🔍 Procesando detecciones...");
    List<Map<String, dynamic>> results = [];

    for (int i = 0; i < output.length; i += 25) {
      double confidence = _sigmoid(output[i + 4]);
      if (confidence > 0.1) { // 🔥 Detecta TODO
        int classId = output.sublist(i + 5, i + 25).indexOf(output.sublist(i + 5, i + 25).reduce(max));
        String label = "Objeto $classId";

        results.add({
          "x": output[i] * imageWidth,
          "y": output[i + 1] * imageHeight,
          "confidence": confidence,
          "label": label,
        });

        print("🛑 Objeto detectado: $label con confianza $confidence");
      }
    }

    setState(() {
      _recognitions = results;
      debugMessage = "🔍 Detecciones encontradas: ${_recognitions.length}";
    });
  }

  double _sigmoid(double x) => 1 / (1 + exp(-x));

  @override
  void dispose() {
    _interpreter?.close();
    _cameraController?.dispose();
    textRecognizer.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          _cameraController == null || !_cameraController!.value.isInitialized
              ? Center(child: CircularProgressIndicator())
              : Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.rotationZ(pi / 2), // 🔥 Corrige la rotación
                  child: CameraPreview(_cameraController!),
                ),
          Positioned(
            bottom: 20,
            left: 20,
            child: Container(
              padding: EdgeInsets.all(8),
              color: Colors.black54,
              child: Text(
                debugMessage,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
