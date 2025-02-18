import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'dart:ui';
import 'dart:ffi' as ffi;


class PlateRecognition {
  final textRecognizer = TextRecognizer();

  Future<String> recognizePlate(Uint8List plateImage) async {
    final image = img.decodeImage(plateImage);
    if (image == null) return "Error al procesar la imagen";

    
    final inputImage = InputImage.fromBytes(
      bytes: plateImage,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: InputImageRotation.rotation0deg,
        format: InputImageFormat.nv21,
        bytesPerRow: image.width,
      ),
    );


    final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    return recognizedText.text;
  }
}
