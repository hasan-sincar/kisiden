import 'dart:convert';

import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;

import '../models/safe_meeting_point.dart';
import '../utils/translations.dart';

class SafeMeetingPointsService {
  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://lz4.overpass-api.de/api/interpreter',
  ];

  Future<List<SafeMeetingPoint>> fetchNearbyPoints({
    required double latitude,
    required double longitude,
    int radiusMeters = 3500,
  }) async {
    final query =
        '''
[out:json][timeout:20];
(
  node(around:${radiusMeters},${latitude},${longitude})[shop=mall];
  way(around:${radiusMeters},${latitude},${longitude})[shop=mall];

  node(around:${radiusMeters},${latitude},${longitude})[amenity=police];
  way(around:${radiusMeters},${latitude},${longitude})[amenity=police];

  node(around:${radiusMeters},${latitude},${longitude})[amenity=townhall];
  way(around:${radiusMeters},${latitude},${longitude})[amenity=townhall];

  node(around:${radiusMeters},${latitude},${longitude})[amenity=bus_station];
  way(around:${radiusMeters},${latitude},${longitude})[amenity=bus_station];

  node(around:${radiusMeters},${latitude},${longitude})[railway=station];
  way(around:${radiusMeters},${latitude},${longitude})[railway=station];

  node(around:${radiusMeters},${latitude},${longitude})[railway=halt];
  way(around:${radiusMeters},${latitude},${longitude})[railway=halt];

  node(around:${radiusMeters},${latitude},${longitude})[station=subway];
  way(around:${radiusMeters},${latitude},${longitude})[station=subway];

  node(around:${radiusMeters},${latitude},${longitude})[amenity=cafe][brand];
  way(around:${radiusMeters},${latitude},${longitude})[amenity=cafe][brand];

  node(around:${radiusMeters},${latitude},${longitude})[place=square];
  way(around:${radiusMeters},${latitude},${longitude})[place=square];
);
out center 120;
''';

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await http
            .post(Uri.parse(endpoint), body: {'data': query})
            .timeout(const Duration(seconds: 12));

        if (response.statusCode != 200) {
          continue;
        }

        final decoded = jsonDecode(response.body) as Map<String, dynamic>;
        final elements = (decoded['elements'] as List<dynamic>? ?? const [])
            .whereType<Map<String, dynamic>>()
            .toList();

        final points = <SafeMeetingPoint>[];
        for (final element in elements) {
          final tags =
              (element['tags'] as Map<String, dynamic>? ??
              const <String, dynamic>{});
          final lat =
              (element['lat'] as num?)?.toDouble() ??
              ((element['center'] as Map<String, dynamic>?)?['lat'] as num?)
                  ?.toDouble();
          final lon =
              (element['lon'] as num?)?.toDouble() ??
              ((element['center'] as Map<String, dynamic>?)?['lon'] as num?)
                  ?.toDouble();

          if (lat == null || lon == null) {
            continue;
          }

          final name = _resolveName(tags);
          final category = _resolveCategory(tags);
          if (category == null) {
            continue;
          }

          final address = _resolveAddress(tags);
          final distance = Geolocator.distanceBetween(
            latitude,
            longitude,
            lat,
            lon,
          );

          points.add(
            SafeMeetingPoint(
              id: '${element['type']}_${element['id']}',
              name: name,
              address: address,
              category: category,
              latitude: lat,
              longitude: lon,
              distanceMeters: distance,
            ),
          );
        }

        points.sort((a, b) => a.distanceMeters.compareTo(b.distanceMeters));
        return _deduplicate(points).take(20).toList();
      } catch (_) {
        continue;
      }
    }

    return const <SafeMeetingPoint>[];
  }

  String _resolveName(Map<String, dynamic> tags) {
    final name = tags['name']?.toString().trim();
    if (name != null && name.isNotEmpty) {
      return name;
    }

    final brand = tags['brand']?.toString().trim();
    if (brand != null && brand.isNotEmpty) {
      return brand;
    }

    final category = _resolveCategory(tags);
    switch (category) {
      case 'mall':
        return tr('meeting_category_mall');
      case 'police':
        return tr('meeting_category_police');
      case 'gendarmerie':
        return tr('meeting_category_gendarmerie');
      case 'municipality':
        return tr('meeting_category_municipality');
      case 'metro':
        return tr('meeting_category_metro');
      case 'train_station':
        return tr('meeting_category_train_station');
      case 'bus_terminal':
        return tr('meeting_category_bus_terminal');
      case 'chain_coffee':
        return tr('meeting_category_chain_coffee');
      case 'square':
        return tr('meeting_category_square');
      default:
        return tr('meeting_point');
    }
  }

  String _resolveAddress(Map<String, dynamic> tags) {
    final street = tags['addr:street']?.toString().trim() ?? '';
    final number = tags['addr:housenumber']?.toString().trim() ?? '';
    final district =
        tags['addr:suburb']?.toString().trim() ??
        tags['addr:district']?.toString().trim() ??
        '';
    final city = tags['addr:city']?.toString().trim() ?? '';

    final chunks = <String>[];
    final streetAndNumber = '$street $number'.trim();
    if (streetAndNumber.isNotEmpty) chunks.add(streetAndNumber);
    if (district.isNotEmpty) chunks.add(district);
    if (city.isNotEmpty) chunks.add(city);

    if (chunks.isNotEmpty) {
      return chunks.join(', ');
    }

    return 'Adres bilgisi mevcut değil';
  }

  String? _resolveCategory(Map<String, dynamic> tags) {
    final amenity = tags['amenity']?.toString().toLowerCase();
    final shop = tags['shop']?.toString().toLowerCase();
    final railway = tags['railway']?.toString().toLowerCase();
    final station = tags['station']?.toString().toLowerCase();
    final place = tags['place']?.toString().toLowerCase();
    final name = tags['name']?.toString().toLowerCase() ?? '';
    final brand = tags['brand']?.toString().toLowerCase() ?? '';

    if (shop == 'mall') return 'mall';

    if (amenity == 'police') {
      if (name.contains('jandarma')) return 'gendarmerie';
      return 'police';
    }

    if (amenity == 'townhall') return 'municipality';
    if (amenity == 'bus_station') return 'bus_terminal';

    if (station == 'subway') return 'metro';

    if (railway == 'station' || railway == 'halt') {
      if (name.contains('metro')) return 'metro';
      return 'train_station';
    }

    if (amenity == 'cafe' && brand.isNotEmpty) {
      return 'chain_coffee';
    }

    if (place == 'square') return 'square';

    return null;
  }

  List<SafeMeetingPoint> _deduplicate(List<SafeMeetingPoint> points) {
    final seen = <String>{};
    final unique = <SafeMeetingPoint>[];

    for (final point in points) {
      final latKey = point.latitude.toStringAsFixed(4);
      final lonKey = point.longitude.toStringAsFixed(4);
      final key = '${point.name.toLowerCase()}-$latKey-$lonKey';
      if (seen.contains(key)) continue;
      seen.add(key);
      unique.add(point);
    }

    return unique;
  }
}
