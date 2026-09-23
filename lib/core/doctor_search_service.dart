import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import 'models.dart';

class DoctorSearchResult {
  const DoctorSearchResult({
    required this.doctors,
    this.notices = const [],
    this.usedFallback = false,
  });

  final List<Doctor> doctors;
  final List<String> notices;
  final bool usedFallback;
}

class DoctorSearchException implements Exception {
  const DoctorSearchException(this.message);
  final String message;

  @override
  String toString() => message;
}

/// Searches exclusively in freely accessible OpenStreetMap data.
class DoctorSearchService {
  DoctorSearchService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  static const _headers = {
    'User-Agent':
        'MedicationAppV2/2.0 (https://github.com/WeA200675/medication_app_v2)',
    'Accept-Language': 'de,en;q=0.7',
  };
  static const _overpassEndpoints = [
    'https://overpass.private.coffee/api/interpreter',
    'https://maps.mail.ru/osm/tools/overpass/api/interpreter',
    'https://overpass-api.de/api/interpreter',
  ];
  static const _aliases = <String, List<String>>{
    'hausarzt': [
      'general',
      'general_practice',
      'allgemeinmedizin',
      'hausarzt',
      'praktischer arzt',
    ],
    'allgemeinmedizin': [
      'general',
      'general_practice',
      'allgemeinmedizin',
      'hausarzt',
    ],
    'innere medizin': ['internal', 'internal_medicine', 'internist'],
    'kardiologie': ['cardiology', 'kardiologie', 'kardiolog', 'herz'],
    'dermatologie': [
      'dermatology',
      'dermatologie',
      'hautarzt',
      'haut',
    ],
    'orthopädie': [
      'orthopaedics',
      'orthopedics',
      'orthopädie',
      'orthopadie',
      'rücken',
      'gelenk',
    ],
    'neurologie': ['neurology', 'neurologie', 'neurolog', 'nerven'],
    'psychiatrie': ['psychiatry', 'psychiatrie', 'psychiater'],
    'psychotherapie': [
      'psychotherapist',
      'psychotherapy',
      'psychotherapie',
    ],
    'gynäkologie': [
      'gynaecology',
      'gynecology',
      'gynäkologie',
      'gynakologie',
      'frauenarzt',
    ],
    'urologie': ['urology', 'urologie', 'urolog'],
    'pädiatrie': [
      'paediatrics',
      'pediatrics',
      'pädiatrie',
      'padiatrie',
      'kinderarzt',
    ],
    'hno': ['otolaryngology', 'hno', 'hals', 'nase', 'ohr'],
    'augenheilkunde': ['ophthalmology', 'augenarzt', 'augenheilkunde'],
    'zahnmedizin': ['dentist', 'dental', 'zahnarzt', 'zahnmedizin'],
    'gastroenterologie': [
      'gastroenterology',
      'gastroenterologie',
      'magen',
      'darm',
    ],
    'diabetologie': ['diabetology', 'diabetologie', 'diabetes'],
    'onkologie': ['oncology', 'onkologie', 'onkolog', 'krebs'],
    'pneumologie': [
      'pulmonology',
      'pneumologie',
      'lungenarzt',
      'lunge',
    ],
    'radiologie': ['radiology', 'radiologie', 'röntgen', 'roentgen'],
  };

  Future<DoctorSearchResult> search({
    required String query,
    required String location,
    required double radiusKm,
  }) async {
    final place = location.trim();
    if (place.length < 2) {
      throw const DoctorSearchException(
        'Bitte Ort oder Postleitzahl eingeben.',
      );
    }
    final center = await _geocode(place);
    if (center == null) {
      throw const DoctorSearchException(
        'Der angegebene Ort wurde nicht gefunden. '
        'Bitte Schreibweise oder Postleitzahl prüfen.',
      );
    }

    for (final endpoint in _overpassEndpoints) {
      try {
        final overpass = await _searchOverpass(
          endpoint,
          center,
          radiusKm,
          query,
        );
        return DoctorSearchResult(
          doctors: overpass.doctors,
          usedFallback: overpass.relaxed,
          notices: overpass.doctors.isEmpty
              ? const [
                  'OpenStreetMap enthält in diesem Gebiet möglicherweise '
                      'noch keine passenden Fachdaten.',
                ]
              : overpass.relaxed
                  ? const [
                      'Zu diesem Suchbegriff fehlen genaue Fachangaben. '
                          'Deshalb werden alle Arztpraxen im gewählten '
                          'Umkreis angezeigt.',
                    ]
              : const [],
        );
      } on Object {
        // Try the next independently operated public instance.
      }
    }

    final fallback = await _searchNominatimFallback(
      query,
      place,
      center,
      radiusKm,
    );
    if (fallback.isNotEmpty) {
      return DoctorSearchResult(
        doctors: fallback,
        usedFallback: true,
        notices: const [
          'Die Overpass-Dienste waren nicht erreichbar. Ergebnisse stammen '
              'aus der eingeschränkten OpenStreetMap-Ortssuche.',
        ],
      );
    }
    throw DoctorSearchException(
      'Die freien Kartendienste sind derzeit nicht erreichbar. '
      'Bitte Internetverbindung prüfen oder später erneut versuchen.',
    );
  }

  Future<Doctor> enrichFromWebsite(Doctor doctor) async {
    if (doctor.website.trim().isEmpty) {
      throw const DoctorSearchException(
        'Für diesen Eintrag ist keine Praxiswebseite hinterlegt.',
      );
    }
    final uri = _safePublicUri(doctor.website);
    final response = await _client
        .get(uri, headers: _headers)
        .timeout(const Duration(seconds: 12));
    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw const DoctorSearchException(
        'Die Praxiswebseite konnte nicht geladen werden.',
      );
    }
    if (response.bodyBytes.length > 2500000) {
      throw const DoctorSearchException(
        'Die Praxiswebseite ist zu groß für die sichere Auswertung.',
      );
    }
    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    final phone =
        doctor.phone.isNotEmpty ? doctor.phone : _firstLink(html, 'tel');
    final email =
        doctor.email.isNotEmpty ? doctor.email : _firstLink(html, 'mailto');
    final appointment = doctor.appointmentUrl.isNotEmpty
        ? doctor.appointmentUrl
        : _appointmentLink(html, response.request?.url ?? uri);
    return doctor.copyWith(
      phone: phone,
      email: email,
      appointmentUrl: appointment,
      sourceName: '${doctor.sourceName} + Praxiswebseite',
      sourceUrl: uri.toString(),
      lastVerifiedAt: DateTime.now(),
    );
  }

  Future<({List<Doctor> doctors, bool relaxed})> _searchOverpass(
    String endpoint,
    (double, double) center,
    double radiusKm,
    String query,
  ) async {
    final radiusMeters = (radiusKm.clamp(1, 100) * 1000).round();
    final overpassQuery = '''[out:json][timeout:12];
(
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="doctors"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["healthcare"="doctor"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="clinic"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["healthcare"="clinic"];
  nwr(around:$radiusMeters,${center.$1},${center.$2})["amenity"="dentist"];
);
out center tags;''';
    final response = await _client
        .post(
          Uri.parse(endpoint),
          headers: {
            ..._headers,
            'Content-Type': 'application/x-www-form-urlencoded',
          },
          body: {'data': overpassQuery},
        )
        .timeout(const Duration(seconds: 18));
    if (response.statusCode != 200) {
      throw DoctorSearchException('Overpass HTTP ${response.statusCode}');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatException('Ungültige Overpass-Antwort');
    }
    final matching = parseOverpass(decoded, query, center);
    if (matching.isNotEmpty || _normalize(query).isEmpty) {
      return (doctors: matching, relaxed: false);
    }

    // Many useful OSM doctor entries have no healthcare:speciality tag.
    // Never turn that missing metadata into a misleading empty result.
    final nearby = parseOverpass(decoded, '', center);
    return (doctors: nearby, relaxed: nearby.isNotEmpty);
  }

  static List<Doctor> parseOverpass(
    Map<String, dynamic> body,
    String query,
    (double, double) center,
  ) {
    final elements = body['elements'] as List<dynamic>? ?? const [];
    final byIdentity = <String, Doctor>{};
    for (final item in elements.whereType<Map<String, dynamic>>()) {
      final doctor = _fromOverpass(item, center);
      if (doctor.name.isEmpty || !_matches(doctor, query)) continue;
      final identity =
          '${_normalize(doctor.name)}|${_normalize(doctor.address)}';
      final previous = byIdentity[identity];
      byIdentity[identity] =
          previous == null ? doctor : _merge(previous, doctor);
    }
    final result = byIdentity.values.toList();
    result.sort((a, b) {
      final distance = (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity);
      return distance != 0
          ? distance
          : a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return result;
  }

  Future<(double, double)?> _geocode(String location) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': location,
      'format': 'jsonv2',
      'limit': '1',
      'countrycodes': 'de',
    });
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        final response = await _client
            .get(uri, headers: _headers)
            .timeout(const Duration(seconds: 10));
        if (response.statusCode != 200) continue;
        final body = jsonDecode(response.body);
        if (body is! List || body.isEmpty || body.first is! Map) return null;
        final item = Map<String, dynamic>.from(body.first as Map);
        final lat = double.tryParse('${item['lat']}');
        final lon = double.tryParse('${item['lon']}');
        if (lat != null && lon != null) return (lat, lon);
      } on Object {
        if (attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      }
    }
    return null;
  }

  Future<List<Doctor>> _searchNominatimFallback(
    String query,
    String location,
    (double, double) center,
    double radiusKm,
  ) async {
    try {
      final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
        // A generic search remains useful when specialty metadata is absent.
        // Filtering happens locally; if it finds nothing, nearby practices are
        // still returned with a visible fallback notice.
        'q': 'Arzt, $location',
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '30',
        'countrycodes': 'de',
      });
      final response = await _client
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 12));
      if (response.statusCode != 200) return const [];
      final decoded = jsonDecode(response.body);
      if (decoded is! List) return const [];
      final nearby = decoded
          .whereType<Map<String, dynamic>>()
          .map((item) => _fromNominatim(item, center))
          .where((doctor) =>
              doctor.name.isNotEmpty &&
              (doctor.distanceKm ?? double.infinity) <= radiusKm)
          .toList();
      nearby.sort((a, b) => (a.distanceKm ?? double.infinity)
          .compareTo(b.distanceKm ?? double.infinity));
      final matching =
          nearby.where((doctor) => _matches(doctor, query)).toList();
      return matching.isNotEmpty ? matching : nearby;
    } on Object {
      return const [];
    }
  }

  static bool _matches(Doctor doctor, String query) {
    final normalized = _normalize(query);
    if (normalized.isEmpty || normalized == 'alle fachrichtungen') return true;
    final words =
        normalized.split(' ').where((word) => word.length > 2).toSet();
    final terms = <String>{normalized, ...words};
    for (final entry in _aliases.entries) {
      final key = _normalize(entry.key);
      final aliases = entry.value.map(_normalize);
      if (normalized.contains(key) ||
          aliases.any((alias) => normalized.contains(alias))) {
        terms.add(key);
        terms.addAll(aliases);
      }
    }
    final haystack = _normalize('${doctor.name} ${doctor.specialty}');
    return terms.any((term) => term.length > 2 && haystack.contains(term));
  }

  static Doctor _fromOverpass(
    Map<String, dynamic> item,
    (double, double) centerPoint,
  ) {
    final tags =
        Map<String, dynamic>.from(item['tags'] as Map? ?? const {});
    final center = item['center'] as Map<String, dynamic>?;
    final lat = (item['lat'] as num?)?.toDouble() ??
        (center?['lat'] as num?)?.toDouble();
    final lon = (item['lon'] as num?)?.toDouble() ??
        (center?['lon'] as num?)?.toDouble();
    final type = '${item['type'] ?? 'element'}';
    final id = '${item['id'] ?? ''}';
    return Doctor(
      id: 'osm-$type-$id',
      name: _first(tags, ['name', 'operator']),
      specialty: _specialty(tags),
      address: _address(tags),
      phone: _first(
        tags,
        ['contact:phone', 'phone', 'contact:mobile', 'mobile'],
      ),
      email: _first(tags, ['contact:email', 'email']),
      website: _first(tags, ['contact:website', 'website', 'url']),
      appointmentUrl: _first(
        tags,
        ['contact:appointment', 'appointment', 'booking', 'contact:booking'],
      ),
      openingHours: _first(tags, ['opening_hours']),
      latitude: lat,
      longitude: lon,
      distanceKm: lat == null || lon == null
          ? null
          : _distance(centerPoint.$1, centerPoint.$2, lat, lon),
      sourceName: 'OpenStreetMap',
      sourceUrl: 'https://www.openstreetmap.org/$type/$id',
      lastVerifiedAt: DateTime.now(),
    );
  }

  static Doctor _fromNominatim(
    Map<String, dynamic> item,
    (double, double) center,
  ) {
    final lat = double.tryParse('${item['lat']}');
    final lon = double.tryParse('${item['lon']}');
    final display = '${item['display_name'] ?? ''}';
    return Doctor(
      id:
          'osm-${item['osm_type'] ?? 'element'}-${item['osm_id'] ?? display.hashCode}',
      name: '${item['name'] ?? display.split(',').first}'.trim(),
      specialty: '${item['type'] ?? item['category'] ?? ''}',
      address: display,
      latitude: lat,
      longitude: lon,
      distanceKm: lat == null || lon == null
          ? null
          : _distance(center.$1, center.$2, lat, lon),
      sourceName: 'OpenStreetMap (Ortssuche)',
      sourceUrl: 'https://www.openstreetmap.org/',
      lastVerifiedAt: DateTime.now(),
    );
  }

  static String _specialty(Map<String, dynamic> tags) {
    final raw = _first(tags, ['healthcare:speciality', 'speciality']);
    if (raw.isNotEmpty) return raw.replaceAll(';', ', ');
    final amenity = '${tags['amenity'] ?? tags['healthcare'] ?? ''}';
    return const {
          'doctors': 'Arztpraxis',
          'doctor': 'Arztpraxis',
          'clinic': 'Klinik',
          'dentist': 'Zahnmedizin',
        }[amenity] ??
        amenity;
  }

  static String _address(Map<String, dynamic> tags) {
    final street = _first(tags, ['addr:street', 'addr:place']);
    final number = '${tags['addr:housenumber'] ?? ''}'.trim();
    final postcode = '${tags['addr:postcode'] ?? ''}'.trim();
    final city = _first(tags, ['addr:city', 'addr:town', 'addr:village']);
    return [
      '$street $number'.trim(),
      '$postcode $city'.trim(),
    ].where((value) => value.isNotEmpty).join(', ');
  }

  static Doctor _merge(Doctor a, Doctor b) => a.copyWith(
        specialty: a.specialty.isNotEmpty ? a.specialty : b.specialty,
        address: a.address.isNotEmpty ? a.address : b.address,
        phone: a.phone.isNotEmpty ? a.phone : b.phone,
        email: a.email.isNotEmpty ? a.email : b.email,
        website: a.website.isNotEmpty ? a.website : b.website,
        appointmentUrl:
            a.appointmentUrl.isNotEmpty ? a.appointmentUrl : b.appointmentUrl,
        openingHours:
            a.openingHours.isNotEmpty ? a.openingHours : b.openingHours,
      );

  static String _first(Map<String, dynamic> tags, List<String> keys) {
    for (final key in keys) {
      final value = tags[key]?.toString().trim() ?? '';
      if (value.isNotEmpty) return value;
    }
    return '';
  }

  static String _firstLink(String html, String scheme) {
    final match = RegExp(
      '$scheme\\s*:\\s*([^"\\\'<>\\s]+)',
      caseSensitive: false,
    ).firstMatch(html);
    return Uri.decodeComponent(match?.group(1)?.trim() ?? '')
        .replaceAll('&amp;', '&');
  }

  static String _appointmentLink(String html, Uri base) {
    final linkPattern = RegExp(
      r'''href\s*=\s*["']([^"']+)["']''',
      caseSensitive: false,
    );
    final keywords = RegExp(
      r'(termin|appointment|booking|doctolib|samedi|jameda)',
      caseSensitive: false,
    );
    for (final match in linkPattern.allMatches(html)) {
      final raw =
          (match.group(1) ?? '').replaceAll('&amp;', '&').trim();
      if (!keywords.hasMatch(raw)) continue;
      final uri = Uri.tryParse(raw);
      if (uri == null) continue;
      return (uri.hasScheme ? uri : base.resolveUri(uri)).toString();
    }
    return '';
  }

  static Uri _safePublicUri(String value) {
    final cleaned = value.trim();
    final uri = Uri.tryParse(
      cleaned.contains('://') ? cleaned : 'https://$cleaned',
    );
    if (uri == null ||
        !{'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty) {
      throw const DoctorSearchException(
        'Die hinterlegte Webseitenadresse ist ungültig.',
      );
    }
    final host = uri.host.toLowerCase();
    final isLocal = host == 'localhost' ||
        host.endsWith('.local') ||
        host == '127.0.0.1' ||
        host == '::1' ||
        RegExp(r'^10\.|^192\.168\.|^172\.(1[6-9]|2\d|3[01])\.')
            .hasMatch(host);
    if (isLocal) {
      throw const DoctorSearchException(
        'Lokale oder private Webadressen werden nicht automatisch ausgelesen.',
      );
    }
    return uri;
  }

  static double _distance(
    double lat1,
    double lon1,
    double lat2,
    double lon2,
  ) {
    const earthRadius = 6371.0;
    double radians(double value) => value * math.pi / 180;
    final dLat = radians(lat2 - lat1);
    final dLon = radians(lon2 - lon1);
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(radians(lat1)) *
            math.cos(radians(lat2)) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    return earthRadius *
        2 *
        math.atan2(math.sqrt(a), math.sqrt(1 - a));
  }

  static String _normalize(String value) => value
      .toLowerCase()
      .replaceAll('ä', 'a')
      .replaceAll('ö', 'o')
      .replaceAll('ü', 'u')
      .replaceAll('ß', 'ss')
      .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
      .trim();

  void close() => _client.close();
}
