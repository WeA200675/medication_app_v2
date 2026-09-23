import 'package:flutter_test/flutter_test.dart';
import 'package:medication_app_v2/core/doctor_search_service.dart';

void main() {
  group('DoctorSearchService.parseOverpass', () {
    final payload = <String, dynamic>{
      'elements': [
        {
          'type': 'node',
          'id': 42,
          'lat': 52.5205,
          'lon': 13.4055,
          'tags': {
            'name': 'Praxis am Park',
            'healthcare:speciality': 'dermatology',
            'addr:street': 'Parkstraße',
            'addr:housenumber': '3',
            'addr:postcode': '10115',
            'addr:city': 'Berlin',
            'contact:phone': '+49 30 123456',
            'contact:email': 'praxis@example.org',
            'contact:website': 'https://example.org',
            'opening_hours': 'Mo-Fr 08:00-17:00',
          },
        },
        {
          'type': 'way',
          'id': 43,
          'center': {'lat': 52.51, 'lon': 13.4},
          'tags': {
            'name': 'Zahnarzt Mitte',
            'amenity': 'dentist',
          },
        },
      ],
    };

    test('findet deutsche Fachbegriffe über Synonyme', () {
      final result = DoctorSearchService.parseOverpass(
        payload,
        'Hautarzt',
        (52.52, 13.405),
      );

      expect(result, hasLength(1));
      expect(result.single.name, 'Praxis am Park');
      expect(result.single.specialty, 'dermatology');
      expect(result.single.phone, '+49 30 123456');
      expect(result.single.email, 'praxis@example.org');
      expect(result.single.sourceName, 'OpenStreetMap');
      expect(result.single.distanceKm, lessThan(1));
    });

    test('ordnet Ergebnisse nach Entfernung', () {
      final result = DoctorSearchService.parseOverpass(
        payload,
        '',
        (52.52, 13.405),
      );

      expect(result, hasLength(2));
      expect(result.first.name, 'Praxis am Park');
    });

    test('liefert bei unpassender Fachrichtung keine Treffer', () {
      final result = DoctorSearchService.parseOverpass(
        payload,
        'Kardiologie',
        (52.52, 13.405),
      );

      expect(result, isEmpty);
    });
  });
}
