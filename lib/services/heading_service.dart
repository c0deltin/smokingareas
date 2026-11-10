import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_rotation_sensor/flutter_rotation_sensor.dart';

import 'heading_math.dart';

/// Where the heading currently comes from.
enum HeadingSource { none, compass, gps }

/// Direction the user is facing (compass) or walking (GPS course), for the
/// cone around the location dot – like in map apps.
///
/// * Compass: fused rotation sensor (Android rotation vector, iOS CoreMotion
///   referenced to magnetic north), corrected to true north for Japan.
/// * GPS course is used while walking when no compass data is available.
/// * The sensor is paused while the app is in the background.
class HeadingService extends ChangeNotifier with WidgetsBindingObserver {
  HeadingService({Stream<OrientationEvent>? orientationStream})
      : _streamOverride = orientationStream;

  final Stream<OrientationEvent>? _streamOverride;
  StreamSubscription<OrientationEvent>? _sub;
  final _smoother = AngleSmoother();

  double? _heading;
  double? _lastNotified;
  double _spread = 30;
  HeadingSource _source = HeadingSource.none;
  DateTime? _lastCompass;
  double _declinationWest = 7.6;
  bool _started = false;

  /// Degrees clockwise from true north, or null if unknown.
  double? get heading => _heading;

  /// Half opening angle of the cone (degrees); wider when inaccurate.
  double get spread => _spread;

  HeadingSource get source => _source;

  /// Minimum change before listeners are notified (avoids repainting the
  /// map for sensor noise).
  static const double notifyThreshold = 1.5;

  void start() {
    if (_started) return;
    _started = true;
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  void _listen() {
    if (_sub != null) return;
    Stream<OrientationEvent> stream;
    if (_streamOverride != null) {
      stream = _streamOverride;
    } else {
      if (!RotationSensor.isPlatformSupported) return;
      try {
        RotationSensor.referenceFrame = ReferenceFrame.magneticNorth;
        RotationSensor.samplingPeriod = const Duration(milliseconds: 66);
        stream = RotationSensor.orientationStream;
      } catch (_) {
        return; // no sensor – GPS course remains as fallback
      }
    }
    _sub = stream.listen(onOrientation, onError: (Object _) {});
  }

  void _pause() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!_started) return;
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _pause();
    }
  }

  /// Updates the magnetic declination for the current position.
  void updatePosition(double latitude, double longitude) {
    _declinationWest = japanDeclinationWest(latitude, longitude);
  }

  @visibleForTesting
  void onOrientation(OrientationEvent event) {
    final m = event.rotationMatrix;
    final magnetic = headingFromRotationMatrix(
        m.a, m.b, m.c, m.d, m.e, m.f, m.g, m.h, m.i);
    if (magnetic == null) return;
    _lastCompass = DateTime.now();
    final accuracyDeg = event.accuracy > 0 ? event.accuracy * 180 / math.pi : -1;
    _spread = accuracyDeg < 0 ? 30 : accuracyDeg.clamp(18, 60).toDouble();
    _set(_smoother.add(trueHeading(magnetic, _declinationWest)),
        HeadingSource.compass);
  }

  /// GPS course over ground; used while walking if the compass is silent.
  void updateFromGps({required double course, required double speed}) {
    final compassRecent = _lastCompass != null &&
        DateTime.now().difference(_lastCompass!) < const Duration(seconds: 3);
    if (compassRecent || speed < 1.0 || course < 0) return;
    _spread = 35;
    _set(_smoother.add(course), HeadingSource.gps);
  }

  void _set(double value, HeadingSource source) {
    _heading = value;
    final changedSource = source != _source;
    _source = source;
    final last = _lastNotified;
    if (changedSource ||
        last == null ||
        angleDelta(last, value).abs() >= notifyThreshold) {
      _lastNotified = value;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _pause();
    if (_started) WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
