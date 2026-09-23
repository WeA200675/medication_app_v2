import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'app_database.dart';
import 'models.dart';

final appControllerProvider = ChangeNotifierProvider<AppController>((ref) => throw UnimplementedError());

class AppController extends ChangeNotifier {
  AppController._(this._database, this._prefs);

  final AppDatabase _database;
  final SharedPreferences _prefs;
  final _uuid = const Uuid();
  List<Medication> medications = const [];
  List<Doctor> doctors = const [];
  List<MedicalDocument> documents = const [];
  UserProfile profile = const UserProfile();
  AppearanceSettings settings = const AppearanceSettings();
  bool loading = true;

  static Future<AppController> create() async {
    final controller = AppController._(await AppDatabase.open(), await SharedPreferences.getInstance());
    await controller._hydrate();
    return controller;
  }

  Future<void> _hydrate() async {
    profile = UserProfile(
      name: _prefs.getString('profile.name') ?? '',
      email: _prefs.getString('profile.email') ?? '',
      phone: _prefs.getString('profile.phone') ?? '',
      avatarPath: _prefs.getString('profile.avatar'),
    );
    settings = AppearanceSettings(
      themeMode: ThemeMode.values[_prefs.getInt('appearance.mode') ?? 0],
      accent: Color(_prefs.getInt('appearance.accent') ?? 0xff006b5f),
      backgroundPath: _prefs.getString('appearance.background'),
      backgroundOverlay: _prefs.getDouble('appearance.overlay') ?? .72,
    );
    await refresh();
    loading = false;
    notifyListeners();
  }

  Future<void> refresh() async {
    medications = await _database.medications();
    doctors = await _database.doctors();
    documents = await _database.documents();
    notifyListeners();
  }

  Future<void> saveProfile(UserProfile value) async {
    profile = value;
    await _prefs.setString('profile.name', value.name);
    await _prefs.setString('profile.email', value.email);
    await _prefs.setString('profile.phone', value.phone);
    if (value.avatarPath != null) await _prefs.setString('profile.avatar', value.avatarPath!);
    notifyListeners();
  }

  Future<String> persistAsset(String sourcePath) => _database.copyIntoAppFiles(sourcePath);

  Future<void> updateAppearance(AppearanceSettings value) async {
    settings = value;
    await _prefs.setInt('appearance.mode', value.themeMode.index);
    await _prefs.setInt('appearance.accent', value.accent.toARGB32());
    await _prefs.setDouble('appearance.overlay', value.backgroundOverlay);
    if (value.backgroundPath != null) await _prefs.setString('appearance.background', value.backgroundPath!);
    notifyListeners();
  }

  Future<void> addMedication({required String name, required double dose, required String unit, required String time, required double stock, required double minimumStock, String instructions = ''}) async {
    await _database.saveMedication(Medication(
      id: _uuid.v4(), name: name, dose: dose, unit: unit, time: time,
      stock: stock, minimumStock: minimumStock, instructions: instructions,
    ));
    await refresh();
  }

  Future<void> takeMedication(Medication value) async {
    await _database.recordIntake(IntakeEvent(
      id: _uuid.v4(), medicationId: value.id, occurredAt: DateTime.now(),
      status: IntakeStatus.taken, quantity: value.dose,
    ));
    await refresh();
  }

  Future<void> refillMedication(Medication value, double quantity) async {
    await _database.refill(value.id, quantity, _uuid.v4());
    await refresh();
  }

  Future<void> removeMedication(String id) async {
    await _database.deleteMedication(id);
    await refresh();
  }

  Future<void> addDoctor(Doctor value) async {
    await _database.saveDoctor(Doctor(
      id: value.id.isEmpty ? _uuid.v4() : value.id,
      name: value.name, specialty: value.specialty, address: value.address,
      phone: value.phone, email: value.email, website: value.website,
    ));
    await refresh();
  }

  Future<void> removeDoctor(String id) async {
    await _database.deleteDoctor(id);
    await refresh();
  }

  Future<void> addDocument(String sourcePath, String title, {String ocrText = ''}) async {
    final storedPath = await _database.copyIntoAppFiles(sourcePath);
    await _database.saveDocument(MedicalDocument(id: _uuid.v4(), title: title, path: storedPath, createdAt: DateTime.now(), ocrText: ocrText));
    await refresh();
  }

  Future<int> importV1(String path) async {
    final result = await _database.importV1Backup(path);
    await refresh();
    return result;
  }

  Future<String> exportBackup() => _database.exportBackup();
}
