import 'dart:async';
import 'dart:math' as math;
import 'package:sensors_plus/sensors_plus.dart';
import 'package:light/light.dart';

class SensorEngine {
  SensorEngine({required this.onEmergency});
  final void Function() onEmergency;
  StreamSubscription<AccelerometerEvent>? _accelSub;
  StreamSubscription<int>? _lightSub;
  Timer? _idleTimer;
  DateTime? _lastMotion;
  double _lightLux = -1;
  bool _impactDetected = false;
  bool _enabled = false;
  bool _triggered = false;

  bool get enabled => _enabled;
  double get lightLux => _lightLux;

  Future<void> start() async {
    if (_enabled) return;
    _enabled = true;
    _lastMotion = DateTime.now();
    _accelSub =
        accelerometerEventStream(samplingPeriod: SensorInterval.normalInterval)
            .listen((event) {
      final magnitude =
          math.sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      // Accelerometer includes gravity; 20 m/s² is a deliberately high impact threshold.
      if (magnitude > 20) {
        _impactDetected = true;
        _lastMotion = DateTime.now();
        _check();
      } else if (magnitude > 12) {
        _lastMotion = DateTime.now();
      }
    }, onError: (_) {});
    try {
      _lightSub = Light().lightSensorStream.listen((lux) {
        _lightLux = lux.toDouble();
        _check();
      }, onError: (_) {
        _lightLux = -1;
      });
    } catch (_) {
      _lightLux = -1;
    }
    _idleTimer =
        Timer.periodic(const Duration(milliseconds: 250), (_) => _check());
  }

  void _check() {
    if (!_enabled ||
        _triggered ||
        !_impactDetected ||
        _lightLux != 0 ||
        _lastMotion == null) return;
    if (DateTime.now().difference(_lastMotion!) >= const Duration(seconds: 5)) {
      _triggered = true;
      onEmergency();
    }
  }

  void resetTrigger() {
    _triggered = false;
    _impactDetected = false;
    _lastMotion = DateTime.now();
  }

  Future<void> stop() async {
    _enabled = false;
    _idleTimer?.cancel();
    await _accelSub?.cancel();
    await _lightSub?.cancel();
    _accelSub = null;
    _lightSub = null;
  }

  Future<void> dispose() => stop();
}
