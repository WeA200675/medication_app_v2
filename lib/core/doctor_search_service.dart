import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;
import 'models.dart';

class DoctorSearchService {
  const DoctorSearchService._();

  static const _headers = {'User-Agent': 'MedicationAppV2/2.0 (https://github.com/WeA200675/medication_app_v2)'};

  static Future<List<Doctor>> search({required String query, required String location, required double radiusKm}) async {
    if (query.trim().length < 2 || location.trim().length < 2) return const [];
    final center = await _geocode(location.trim());
    if (center == null) throw Exception('Der angegebene Ort wurde nicht gefunden.');
    final results = <Doctor>[];
    for (final term in _expandTopic(query.trim())) {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        'q': '$term, ${location.trim()}', 'format': 'jsonv2', 'addressdetails': '1',
        'extratags': '1', 'limit': '30', 'accept-language': 'de',
      });
      final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 10));
      if (response.statusCode != 200) throw Exception('Die Arztsuche ist derzeit nicht erreichbar.');
      final body = jsonDecode(response.body);
      if (body is! List) continue;
      for (final item in body.whereType<Map<String, dynamic>>()) {
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat == null || lon == null || _distanceKm(center.$1, center.$2, lat, lon) > radiusKm) continue;
        final doctor = _fromNominatim(item, query);
        if (!results.any((value) => value.id == doctor.id)) results.add(doctor);
      }
    }
    return results;
  }

  static List<String> _expandTopic(String query) {
    final value = query.toLowerCase();
    const topics = <String, String>{
      'haut': 'Hautarzt', 'allergie': 'Allergologe', 'herz': 'Kardiologe',
      'rücken': 'Orthopäde', 'gelenk': 'Orthopäde', 'auge': 'Augenarzt',
      'zahn': 'Zahnarzt', 'magen': 'Gastroenterologe', 'darm': 'Gastroenterologe',
      'nase': 'HNO Arzt', 'ohr': 'HNO Arzt', 'hals': 'HNO Arzt',
      'kind': 'Kinderarzt', 'neurologie': 'Neurologe', 'psyche': 'Psychiater',
      'diabetes': 'Diabetologe', 'frauen': 'Frauenarzt', 'urologie': 'Urologe',
    };
    for (final entry in topics.entries) {
      if (value.contains(entry.key)) return ['$query Arzt', entry.value];
    }
    return ['$query Arzt'];
  }

  static Future<(double, double)?> _geocode(String location) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': location, 'format': 'jsonv2', 'limit': '1', 'countrycodes': 'de',
    });
    final response = await http.get(uri, headers: _headers).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) return null;
    final body = jsonDecode(response.body);
    if (body is! List || body.isEmpty) return null;
    final item = body.first as Map<String, dynamic>;
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    return lat == null || lon == null ? null : (lat, lon);
  }

  static Doctor _fromNominatim(Map<String, dynamic> item, String fallbackSpecialty) {
    final extra = Map<String, dynamic>.from(item['extratags'] as Map? ?? const {});
    final displayName = item['display_name'] as String? ?? '';
    return Doctor(
      id: 'osm-${item['place_id']}',
      name: (item['name'] as String?)?.trim().isNotEmpty == true ? item['name'] as String : displayName.split(',').first,
      specialty: extra['healthcare:speciality'] as String? ?? extra['amenity'] as String? ?? fallbackSpecialty,
      address: displayName,
      phone: extra['contact:phone'] as String? ?? extra['phone'] as String? ?? '',
      email: extra['contact:email'] as String? ?? extra['email'] as String? ?? '',
      website: extra['contact:website'] as String? ?? extra['website'] as String? ?? '',
      appointmentUrl: extra['contact:appointment'] as String? ?? extra['appointment'] as String? ?? '',
      latitude: double.tryParse('${item['lat']}'), longitude: double.tryParse('${item['lon']}'),
    );
  }

  static double _distanceKm(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371.0;
    final dLat = _radians(lat2 - lat1);
    final dLon = _radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) + math.cos(_radians(lat1)) * math.cos(_radians(lat2)) * math.sin(dLon / 2) * math.sin(dLon / 2);
    return earthRadius * 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static double _radians(double value) => value * math.pi / 180;
}
