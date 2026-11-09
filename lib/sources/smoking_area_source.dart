import '../models/city.dart';
import '../models/smoking_area.dart';

/// A publicly reachable data source for smoking areas.
///
/// Additional sources (e.g. municipal open-data GeoJSON/CSV files published
/// by individual wards) can be added by implementing this interface and
/// registering them in [SmokingAreaRepository].
abstract class SmokingAreaSource {
  /// Short identifier, used in cache keys.
  String get id;

  /// Human readable name shown in the UI / attribution.
  String get displayName;

  /// Attribution / licence text that must be shown in the app.
  String get attribution;

  /// Whether this source has data for [bounds]. Sources that only cover a
  /// single municipality can return false for everything else.
  bool covers(GeoBounds bounds) => true;

  Future<List<SmokingArea>> fetch(GeoBounds bounds);
}

class SourceException implements Exception {
  SourceException(this.message);
  final String message;
  @override
  String toString() => message;
}
