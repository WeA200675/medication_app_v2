import 'dart:convert';

import 'package:http/http.dart' as http;

import 'models.dart';

class DoctorSearchService {
  const DoctorSearchService._();

  static Future<List<Doctor>> search(String query) async {
    final trimmed = query.trim();
    if (trimmed.length < 3) return const [];
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': trimmed,
      'format': 'jsonv2',
      'addressdetails': '1',
      'extratags': '1',
      'limit': '10',
      'accept-language': 'de',
    });
    final response = await http.get(uri, headers: const {
      'User-Agent': 'MedicationAppV2/2.0 (https://github.com/WeA200675/medication_app_v2)',
    }).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) throw Exception('Arztsuche derzeit nicht erreichbar.');
    final body = jsonDecode(response.body);
    if (body is! List) return const [];
    return body.whereType<Map<String, dynamic>>().map((item) {
      final extra = Map<String, dynamic>.from(item['extratags'] as Map? ?? const {});
      return Doctor(
        id: 'osm-${item['place_id']}',
        name: (item['name'] as String?)?.trim().isNotEmpty == true ? item['name'] as String : (item['display_name'] as String? ?? trimmed).split(',').first,
        specialty: extra['healthcare:speciality'] as String? ?? extra['amenity'] as String? ?? '',
        address: item['display_name'] as String? ?? '',
        phone: extra['contact:phone'] as String? ?? extra['phone'] as String? ?? '',
        email: extra['contact:email'] as String? ?? extra['email'] as String? ?? '',
        website: extra['contact:website'] as String? ?? extra['website'] as String? ?? '',
      );
    }).toList();
  }
}
