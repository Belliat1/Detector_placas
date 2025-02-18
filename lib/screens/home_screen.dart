import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import '../services/database_service.dart';
import 'camera_screen.dart'; // 🔹 Importa correctamente CameraScreen

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final DatabaseService dbService = DatabaseService();
  bool csvLoaded = false;

  @override
  void initState() {
    super.initState();
    dbService.initDB();
  }

  Future<void> _loadCSV() async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(type: FileType.any);

    if (result != null) {
      File file = File(result.files.single.path!);
      await dbService.loadPlatesFromCSV(file);
      setState(() {
        csvLoaded = true;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("CSV cargado correctamente.")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Cargar Placas")),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: _loadCSV,
              child: Text("Cargar CSV de Placas"),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: csvLoaded
                  ? () async {
                      List<String> listaDePlacas = await dbService.getPlatesFromDB();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CameraScreen(plates: listaDePlacas), // 🔹 Corrección aquí
                        ),
                      );
                    }
                  : null,
              child: Text("Iniciar Escaneo"),
            ),
          ],
        ),
      ),
    );
  }
}
