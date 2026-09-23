import 'package:flutter/material.dart';

enum IntakeStatus { taken, skipped }

@immutable
class Medication {
  const Medication({
    required this.id,
    required this.name,
    required this.dose,
    required this.unit,
    required this.time,
    required this.stock,
    required this.minimumStock,
    this.instructions = '',
    this.isActive = true,
  });

  final String id;
  final String name;
  final double dose;
  final String unit;
  final String time;
  final double stock;
  final double minimumStock;
  final String instructions;
  final bool isActive;

  int get estimatedDays => dose <= 0 ? 0 : (stock / dose).floor();
  bool get needsRefill => stock <= minimumStock;

  Medication copyWith({double? stock, bool? isActive}) => Medication(
        id: id,
        name: name,
        dose: dose,
        unit: unit,
        time: time,
        stock: stock ?? this.stock,
        minimumStock: minimumStock,
        instructions: instructions,
        isActive: isActive ?? this.isActive,
      );

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'dose': dose,
        'unit': unit,
        'time': time,
        'stock': stock,
        'minimum_stock': minimumStock,
        'instructions': instructions,
        'is_active': isActive ? 1 : 0,
      };

  factory Medication.fromMap(Map<String, Object?> map) => Medication(
        id: map['id']! as String,
        name: map['name']! as String,
        dose: (map['dose']! as num).toDouble(),
        unit: map['unit']! as String,
        time: map['time']! as String,
        stock: (map['stock']! as num).toDouble(),
        minimumStock: (map['minimum_stock']! as num).toDouble(),
        instructions: map['instructions'] as String? ?? '',
        isActive: (map['is_active'] as int? ?? 1) == 1,
      );
}

@immutable
class IntakeEvent {
  const IntakeEvent({
    required this.id,
    required this.medicationId,
    required this.occurredAt,
    required this.status,
    required this.quantity,
  });
  final String id;
  final String medicationId;
  final DateTime occurredAt;
  final IntakeStatus status;
  final double quantity;
}

@immutable
class Doctor {
  const Doctor({
    required this.id,
    required this.name,
    this.specialty = '',
    this.address = '',
    this.phone = '',
    this.email = '',
    this.website = '',
    this.appointmentUrl = '',
    this.openingHours = '',
    this.latitude,
    this.longitude,
  });
  final String id;
  final String name;
  final String specialty;
  final String address;
  final String phone;
  final String email;
  final String website;
  final String appointmentUrl;
  final String openingHours;
  final double? latitude;
  final double? longitude;

  Map<String, Object?> toMap() => {
        'id': id,
        'name': name,
        'specialty': specialty,
        'address': address,
        'phone': phone,
        'email': email,
        'website': website,
        'appointment_url': appointmentUrl,
        'opening_hours': openingHours,
        'latitude': latitude,
        'longitude': longitude,
      };
  factory Doctor.fromMap(Map<String, Object?> map) => Doctor(
        id: map['id']! as String,
        name: map['name']! as String,
        specialty: map['specialty'] as String? ?? '',
        address: map['address'] as String? ?? '',
        phone: map['phone'] as String? ?? '',
        email: map['email'] as String? ?? '',
        website: map['website'] as String? ?? '',
        appointmentUrl: map['appointment_url'] as String? ?? '',
        openingHours: map['opening_hours'] as String? ?? '',
        latitude: (map['latitude'] as num?)?.toDouble(),
        longitude: (map['longitude'] as num?)?.toDouble(),
      );
}

@immutable
class MedicalDocument {
  const MedicalDocument({required this.id, required this.title, required this.path, required this.createdAt, this.ocrText = ''});
  final String id;
  final String title;
  final String path;
  final DateTime createdAt;
  final String ocrText;
}

@immutable
class UserProfile {
  const UserProfile({this.name = '', this.email = '', this.phone = '', this.avatarPath});
  final String name;
  final String email;
  final String phone;
  final String? avatarPath;

  UserProfile copyWith({String? name, String? email, String? phone, String? avatarPath}) => UserProfile(
        name: name ?? this.name,
        email: email ?? this.email,
        phone: phone ?? this.phone,
        avatarPath: avatarPath ?? this.avatarPath,
      );
}

@immutable
class AppearanceSettings {
  const AppearanceSettings({
    this.themeMode = ThemeMode.system,
    this.accent = const Color(0xff006b5f),
    this.backgroundPath,
    this.backgroundOverlay = .72,
  });
  final ThemeMode themeMode;
  final Color accent;
  final String? backgroundPath;
  final double backgroundOverlay;

  AppearanceSettings copyWith({ThemeMode? themeMode, Color? accent, String? backgroundPath, double? backgroundOverlay}) => AppearanceSettings(
        themeMode: themeMode ?? this.themeMode,
        accent: accent ?? this.accent,
        backgroundPath: backgroundPath ?? this.backgroundPath,
        backgroundOverlay: backgroundOverlay ?? this.backgroundOverlay,
      );
}
