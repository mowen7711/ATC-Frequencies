import 'package:geolocator/geolocator.dart';

class LocationService {
  LocationService._();
  static final LocationService instance = LocationService._();

  Future<LocationResult> getCurrentLocation() async {
    final serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      return LocationResult.error(
          'Location services are disabled. Enable them in device settings.');
    }

    var permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        return LocationResult.error(
            'Location permission was denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      return LocationResult.error(
          'Location permission is permanently denied. Enable it in app settings.');
    }

    try {
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 15),
        ),
      );
      return LocationResult.success(position.latitude, position.longitude);
    } catch (e) {
      return LocationResult.error('Could not determine location: $e');
    }
  }
}

class LocationResult {
  final double? latitude;
  final double? longitude;
  final String? error;

  const LocationResult._({this.latitude, this.longitude, this.error});

  factory LocationResult.success(double lat, double lon) =>
      LocationResult._(latitude: lat, longitude: lon);

  factory LocationResult.error(String message) =>
      LocationResult._(error: message);

  bool get isSuccess => error == null;
}
