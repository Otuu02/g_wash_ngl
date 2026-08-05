import 'dart:math';
import 'package:flutter_test/flutter_test.dart';

double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
  const double earthRadiusKm = 6371.0;
  double dLat = _degreesToRadians(lat2 - lat1);
  double dLon = _degreesToRadians(lon2 - lon1);

  double a = sin(dLat / 2) * sin(dLat / 2) +
      cos(_degreesToRadians(lat1)) *
          cos(_degreesToRadians(lat2)) *
          sin(dLon / 2) *
          sin(dLon / 2);

  double c = 2 * atan2(sqrt(a), sqrt(1 - a));
  return earthRadiusKm * c;
}

double _degreesToRadians(double degrees) {
  return degrees * pi / 180;
}

void main() {
  group('Job Service Location & Category Tests', () {
    test('Haversine distance calculation between Lagos points', () {
      // Victoria Island to Ikeja (~18 km)
      double dist = calculateDistance(6.4281, 3.4219, 6.6018, 3.3515);
      expect(dist, greaterThan(10.0));
      expect(dist, lessThan(30.0));
    });

    test('Category matching helper logic', () {
      const category = 'Car Wash';
      final cleanCategory = category.toLowerCase().trim();
      expect(cleanCategory, equals('car wash'));

      const sampleCat = 'car_wash';
      bool isMatch = sampleCat.toLowerCase().contains('wash');
      expect(isMatch, isTrue);
    });
  });
}
