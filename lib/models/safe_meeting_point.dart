class SafeMeetingPoint {
  const SafeMeetingPoint({
    required this.id,
    required this.name,
    required this.address,
    required this.category,
    required this.latitude,
    required this.longitude,
    required this.distanceMeters,
  });

  final String id;
  final String name;
  final String address;
  final String category;
  final double latitude;
  final double longitude;
  final double distanceMeters;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'category': category,
      'latitude': latitude,
      'longitude': longitude,
      'distanceMeters': distanceMeters,
    };
  }

  factory SafeMeetingPoint.fromMap(Map<String, dynamic> map) {
    return SafeMeetingPoint(
      id: map['id']?.toString() ?? '',
      name: map['name']?.toString() ?? '',
      address: map['address']?.toString() ?? '',
      category: map['category']?.toString() ?? 'general',
      latitude: (map['latitude'] as num?)?.toDouble() ?? 0,
      longitude: (map['longitude'] as num?)?.toDouble() ?? 0,
      distanceMeters: (map['distanceMeters'] as num?)?.toDouble() ?? 0,
    );
  }
}
