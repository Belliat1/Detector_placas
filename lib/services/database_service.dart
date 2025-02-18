import 'dart:io';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

class DatabaseService {
  Database? _database;

  Future<void> initDB() async {
    _database = await openDatabase(
      join(await getDatabasesPath(), 'plates.db'),
      onCreate: (db, version) {
        return db.execute(
          "CREATE TABLE plates(id INTEGER PRIMARY KEY, plate TEXT UNIQUE)",
        );
      },
      version: 1,
    );
  }

  Future<void> loadPlatesFromCSV(File file) async {
    final lines = await file.readAsLines();
    for (var line in lines) {
      await _database?.insert(
        'plates',
        {'plate': line.trim()},
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
  }

  Future<bool> checkPlateInDB(String plate) async {
    final result = await _database?.query(
      'plates',
      where: "plate = ?",
      whereArgs: [plate],
    );
    return result != null && result.isNotEmpty;
  }

  Future<List<String>> getPlatesFromDB() async {
    final List<Map<String, dynamic>> plates = await _database?.query('plates') ?? [];
    return plates.map((e) => e['plate'] as String).toList();
  }
}
