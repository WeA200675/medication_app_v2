import 'dart:convert';

import 'package:http/http.dart' as http;
import 'models.dart';

class DoctorSearchService {
  const DoctorSearchService._();

  static const _headers = {'User-Agent': 'MedicationAppV2/2.0 (https://github.com/WeA200675/medication_app_v2)'};
  static const _aliases = <String, List<String>>{
    'hausarzt': ['general', 'general_practice', 'allgemeinmedizin', 'hausarzt'],
    'allgemeinmedizin': ['general', 'general_practice', 'allgemeinmedizin', 'hausarzt'],
    'innere medizin': ['internal', 'internal_medicine', 'internist'],
    'kardiologie': ['cardiology', 'kardiologie', 'kardiolog'],
    'dermatologie': ['dermatology', 'dermatologie', 'hautarzt', 'haut'],
    'orthopädie': ['orthopaedics', 'orthopedics', 'orthopädie', 'rücken', 'gelenk'],
    'neurologie': ['neurology', 'neurologie', 'neurolog'],
    'psychiatrie': ['psychiatry', 'psychiatrie', 'psychiater'],
    'psychotherapie': ['psychotherapist', 'psychotherapy', 'psychotherapie'],
    'gynäkologie': ['gynaecology', 'gynecology', 'gynäkologie', 'frauenarzt'],
    'urologie': ['urology', 'urologie', 'urolog'],
    'pädiatrie': ['paediatrics', 'pediatrics', 'pädiatrie', 'kinderarzt'],
    'hno': ['otolaryngology', 'hno', 'hals', 'nase', 'ohr'],
    'augenheilkunde': ['ophthalmology', 'augenarzt', 'augenheilkunde'],
    'zahnmedizin': ['dentist', 'dental', 'zahnarzt', 'zahnmedizin'],
    'gastroenterologie': ['gastroenterology', 'gastroenterologie', 'magen', 'darm'],
    'diabetologie': ['diabetology', 'diabetologie', 'diabetes'],
  };

  static Future<List<Doctor>> search({required String query, required String location, required double radiusKm}) async {
    if (location.trim().length < 2) return const [];
    final center = await _geocode(location.trim());
    if (center == null) throw Exception('Der angegebene Ort wurde nicht gefunden.');
    final radiusMeters = (radiusKm * 1000).round();
    final overpassQuery = '''[out:json][timeout:25];
(
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="doctors"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["healthcare"="doctor"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="clinic"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["healthcare"="clinic"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="dentist"];
);
out center tags;''';
    final response = await http.post(
      Uri.parse('https://overpass-api.de/api/interpreter'),
      headers: {..._headers, 'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'data': overpassQuery},
    ).timeout(const Duration(seconds: 30));
    if (response.statusCode != 200) throw Exception('Die Umkreissuche ist derzeit ausgelastet. Bitte später erneut versuchen.');
    final body = jsonDecode(response.body) as Map<String, dynamic>;
    final elements = body['elements'] as List<dynamic>? ?? const [];
    return elements
        .whereType<Map<String, dynamic>>()
        .map(_fromOverpass)
        .where((doctor) => doctor.name.isNotEmpty && _matches(doctor, query))
        .toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
  }

  static bool _matches(Doctor doctor, String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty || normalized == 'alle fachrichtungen') return true;
    final terms = <String>{normalized};
    for (final entry in _aliases.entries) {
      if (normalized.contains(entry.key) || entry.value.any(normalized.contains)) {
        terms.addAll(entry.value);
      }
    }
    final haystack = '${doctor.name} ${doctor.specialty}'.toLowerCase();
    return terms.any(haystack.contains);
  }

  static Future<(double, double)?> _geocode(String location) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {'q': location, 'format': 'jsonv2', 'limit': '1', 'countrycodes': 'de'});
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty) return null;
    final item = body.first as Map<String, dynamic>;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    return lat == null || lon == null ? null : (lat, lon);
  }

  static Doctor _fromOverpass(Map<String, dynamic> item) {
    final tags = Map<String, dynamic>.from(item['tags'] as Map? ?? const {});
    final center = item['center'] as Map<String, dynamic>?;
    final lat = (item['lat'] as num?)?.toDouble() ?? (center?['lat'] as num?)?.toDouble();
    final lon = (item['lon'] as num?)?.toDouble() ?? (center?['lon'] as num?)?.toDouble();
    final street = tags['addr:street'] as String? ?? '';
    final number = tags['addr:housenumber'] as String? ?? '';
    final postcode = tags['addr:postcode'] as String? ?? '';
    final city = tags['addr:city'] as String? ?? '';
    final address = ['$street $number'.trim(), '$postcode $city'.trim()].where((value) => value.isNotEmpty).join(', ');
    return Doctor(
      id: 'osm-${item['type']}-${item['id']}',
      name: tags['name'] as String? ?? tags['operator'] as String? ?? '',
      specialty: tags['healthcare:speciality'] as String? ?? tags['speciality'] as String? ?? tags['amenity'] as String? ?? '',
      address: address,
      phone: _first(tags, ['contact:phone', 'phone', 'contact:mobile', 'mobile']),
      email: _first(tags, ['contact:email', 'email']),
      website: _first(tags, ['contact:website', 'website', 'url']),
      appointmentUrl: _first(tags, ['contact:appointment', 'appointment', 'booking', 'contact:booking']),
      openingHours: tags['opening_hours'] as String? ?? '',
      latitude: lat,
      longitude: lon,
    );
  }

  static String _first(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }
}
