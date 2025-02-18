import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:detector_placas/main.dart';

void main() {
  testWidgets('Prueba de inicialización de la aplicación', (WidgetTester tester) async {
    // Construir la aplicación y desencadenar un frame
    await tester.pumpWidget(const VTrack360App());

    // Verificar que la pantalla inicial es la pantalla de login
    expect(find.text('Login'), findsOneWidget); // Ajusta 'Login' al texto que se muestra en LoginScreen
    expect(find.text('Home'), findsNothing); // Asegúrate de que no aparece contenido de HomeScreen
  });
}
