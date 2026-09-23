import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import 'models.dart';

class AppDatabase {
  AppDatabase._(this.db);
  final Database db;

  static Future<AppDatabase> open() async {
    final root = await getDatabasesPath();
    final db = await openDatabase(
      p.join(root, 'medication_v2.db'),
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        await db.execute('''CREATE TABLE medications(
          id TEXT PRIMARY KEY, name TEXT NOT NULL, dose REAL NOT NULL,
          unit TEXT NOT NULL, time TEXT NOT NULL, stock REAL NOT NULL,
          minimum_stock REAL NOT NULL, instructions TEXT NOT NULL,
          is_active INTEGER NOT NULL)''');
        await db.execute('''CREATE TABLE intake_events(
          id TEXT PRIMARY KEY, medication_id TEXT NOT NULL, occurred_at TEXT NOT NULL,
          status TEXT NOT NULL, quantity REAL NOT NULL,
          FOREIGN KEY(medication_id) REFERENCES medications(id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE inventory_transactions(
          id TEXT PRIMARY KEY, medication_id TEXT NOT NULL, occurred_at TEXT NOT NULL,
          quantity REAL NOT NULL, reason TEXT NOT NULL,
          FOREIGN KEY(medication_id) REFERENCES medications(id) ON DELETE CASCADE)''');
        await db.execute('''CREATE TABLE doctors(
          id TEXT PRIMARY KEY, name TEXT NOT NULL, specialty TEXT NOT NULL,
          address TEXT NOT NULL, phone TEXT NOT NULL, email TEXT NOT NULL,
          website TEXT NOT NULL)''');
        await db.execute('''CREATE TABLE documents(
          id TEXT PRIMARY KEY, title TEXT NOT NULL, path TEXT NOT NULL,
          created_at TEXT NOT NULL, ocr_text TEXT NOT NULL)''');
      },
    );
    return AppDatabase._(db);
  }

  Future<List<Medication>> medications() async =>
      (await db.query('medications', orderBy: 'time, name')).map(Medication.fromMap).toList();
  Future<void> saveMedication(Medication value) => db.insert('medications', value.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteMedication(String id) => db.delete('medications', where: 'id = ?', whereArgs: [id]);

  Future<void> recordIntake(IntakeEvent event) async {
    await db.transaction((txn) async {
      await txn.insert('intake_events', {
        'id': event.id,
        'medication_id': event.medicationId,
        'occurred_at': event.occurredAt.toIso8601String(),
        'status': event.status.name,
        'quantity': event.quantity,
      });
      if (event.status == IntakeStatus.taken) {
        await txn.rawUpdate('UPDATE medications SET stock = MAX(0, stock - ?) WHERE id = ?', [event.quantity, event.medicationId]);
        await txn.insert('inventory_transactions', {
          'id': '${event.id}-stock',
          'medication_id': event.medicationId,
          'occurred_at': event.occurredAt.toIso8601String(),
          'quantity': -event.quantity,
          'reason': 'intake',
        });
      }
    });
  }

  Future<void> refill(String id, double quantity, String transactionId) async {
    await db.transaction((txn) async {
      await txn.rawUpdate('UPDATE medications SET stock = stock + ? WHERE id = ?', [quantity, id]);
      await txn.insert('inventory_transactions', {
        'id': transactionId,
        'medication_id': id,
        'occurred_at': DateTime.now().toIso8601String(),
        'quantity': quantity,
        'reason': 'refill',
      });
    });
  }

  Future<List<Doctor>> doctors() async =>
      (await db.query('doctors', orderBy: 'name COLLATE NOCASE')).map(Doctor.fromMap).toList();
  Future<void> saveDoctor(Doctor value) => db.insert('doctors', value.toMap(), conflictAlgorithm: ConflictAlgorithm.replace);
  Future<void> deleteDoctor(String id) => db.delete('doctors', where: 'id = ?', whereArgs: [id]);

  Future<List<MedicalDocument>> documents() async => (await db.query('documents', orderBy: 'created_at DESC')).map((m) => MedicalDocument(
        id: m['id']! as String,
        title: m['title']! as String,
        path: m['path']! as String,
        createdAt: DateTime.parse(m['created_at']! as String),
        ocrText: m['ocr_text'] as String? ?? '',
      )).toList();
  Future<void> saveDocument(MedicalDocument value) => db.insert('documents', {
        'id': value.id,
        'title': value.title,
        'path': value.path,
        'created_at': value.createdAt.toIso8601String(),
        'ocr_text': value.ocrText,
      });

  Future<String> copyIntoAppFiles(String sourcePath) async {
    final dir = await getApplicationDocumentsDirectory();
    final targetDir = Directory(p.join(dir.path, 'medical_files'));
    await targetDir.create(recursive: true);
    final target = p.join(targetDir.path, '${DateTime.now().microsecondsSinceEpoch}_${p.basename(sourcePath)}');
    return (await File(sourcePath).copy(target)).path;
  }

  Future<int> importV1Backup(String sourcePath) async {
    final decoded = jsonDecode(await File(sourcePath).readAsString());
    if (decoded is! Map<String, dynamic>) throw const FormatException('Ungültiges Backup');
    final entries = (decoded['medPlan'] ?? decoded['med_plan']) as List<dynamic>? ?? const [];
    var count = 0;
    for (final raw in entries.whereType<Map<String, dynamic>>()) {
      final name = (raw['drugName'] as String? ?? '').trim();
      if (name.isEmpty) continue;
      final value = Medication(
        id: 'v1-${raw['id'] ?? count}-${name.hashCode}',
        name: name,
        dose: _doseFrom(raw['dosage']),
        unit: 'Tablette',
        time: raw['time'] as String? ?? '08:00',
        stock: (raw['stockCount'] as num? ?? 0).toDouble(),
        minimumStock: 7,
        instructions: raw['instructions'] as String? ?? '',
        isActive: (raw['isActive'] as int? ?? 1) == 1,
      );
      await saveMedication(value);
      count++;
    }
    return count;
  }

  Future<String> exportBackup() async {
    final root = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    final file = File(p.join(root.path, 'medication_v2_backup_$date.json'));
    final payload = {
      'version': 2,
      'createdAt': DateTime.now().toIso8601String(),
      'medications': await db.query('medications'),
      'doctors': await db.query('doctors'),
      'documents': await db.query('documents'),
      'intakeEvents': await db.query('intake_events'),
      'inventoryTransactions': await db.query('inventory_transactions'),
    };
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(payload), flush: true);
    return file.path;
  }

  static double _doseFrom(Object? raw) {
    final match = RegExp(r'\d+(?:[\.,]\d+)?').firstMatch('$raw');
    return double.tryParse((match?.group(0) ?? '1').replaceAll(',', '.')) ?? 1;
  }
}
