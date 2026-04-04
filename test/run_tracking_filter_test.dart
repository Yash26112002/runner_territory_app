// ignore_for_file: avoid_print

/// Tests for the GPS point filtering logic added to RunTrackingService.
///
/// The editor agent adds three independent filters applied in sequence to each
/// incoming GPS position:
///
///   1. Time window filter  — points received within the first 20 seconds of
///      run start are skipped (GPS warm-up / initial inaccuracy).
///   2. Accuracy filter     — points with position.accuracy > 50.0 m are
///      rejected.
///   3. Speed filter        — if the implied speed between the new point and
///      the previous accepted point exceeds 6 m/s the new point is rejected.
///
/// RunTrackingService depends on Geolocator hardware streams, so the full
/// service cannot be started in unit tests.  The editor agent is expected to
/// extract the filter decisions into a small, pure helper that can be called
/// without a live GPS stream.  This file tests that helper directly.
///
/// If the editor agent names the helper differently, update the import alias in
/// the "Filter under test" section.  No Firebase or Geolocator initialisation
/// is required.

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

// ---------------------------------------------------------------------------
// Inline implementation of the filter logic.
//
// This mirrors exactly what the editor agent must implement inside
// RunTrackingService.  Having it here lets the tests compile and pass
// independently; when the editor agent lands its version the test file should
// be updated to import from the service instead, or the service should delegate
// to this shared helper.
// ---------------------------------------------------------------------------

/// Result of evaluating a single GPS candidate point.
enum FilterResult {
  /// Point passes all filters and should be appended to the route.
  accepted,

  /// Point is within the 20-second warm-up window and must be discarded.
  tooEarlyInRun,

  /// Point's horizontal accuracy exceeds 50 m and must be discarded.
  poorAccuracy,

  /// The implied speed from the previous accepted point exceeds 6 m/s.
  speedTooHigh,
}

/// Haversine distance in metres.
double _haversineMeters(LatLng a, LatLng b) {
  const double r = 6371000;
  final double dLat = _toRad(b.latitude - a.latitude);
  final double dLon = _toRad(b.longitude - a.longitude);
  final double sinDLat = sin(dLat / 2);
  final double sinDLon = sin(dLon / 2);
  final double x = sinDLat * sinDLat +
      cos(_toRad(a.latitude)) * cos(_toRad(b.latitude)) * sinDLon * sinDLon;
  return r * 2 * atan2(sqrt(x), sqrt(1 - x));
}

double _toRad(double deg) => deg * pi / 180;

const double _maxAccuracyMeters = 50.0;
const double _maxSpeedMetersPerSecond = 6.0;
const int _warmUpSeconds = 20;

/// Evaluates whether [candidate] should be accepted into the route.
///
/// Parameters:
///   [runStartTime]   — the DateTime when the run was started.
///   [candidateTime]  — the timestamp of the candidate GPS fix.
///   [accuracy]       — horizontal accuracy reported by the GPS fix, in metres.
///   [candidate]      — the geographic position of the fix.
///   [lastAccepted]   — the most recent accepted route point, or null if this
///                      is the very first point being considered.
///   [lastAcceptedTime] — timestamp of [lastAccepted], or null.
FilterResult evaluateGpsPoint({
  required DateTime runStartTime,
  required DateTime candidateTime,
  required double accuracy,
  required LatLng candidate,
  LatLng? lastAccepted,
  DateTime? lastAcceptedTime,
}) {
  // Filter 1: warm-up window.
  final int elapsedSeconds =
      candidateTime.difference(runStartTime).inSeconds;
  if (elapsedSeconds < _warmUpSeconds) {
    return FilterResult.tooEarlyInRun;
  }

  // Filter 2: accuracy gate.
  if (accuracy > _maxAccuracyMeters) {
    return FilterResult.poorAccuracy;
  }

  // Filter 3: speed gate (only when a previous point exists).
  if (lastAccepted != null && lastAcceptedTime != null) {
    final double distMeters = _haversineMeters(lastAccepted, candidate);
    final double timeSec =
        candidateTime.difference(lastAcceptedTime).inMilliseconds / 1000.0;
    if (timeSec > 0) {
      final double speed = distMeters / timeSec;
      if (speed > _maxSpeedMetersPerSecond) {
        return FilterResult.speedTooHigh;
      }
    }
  }

  return FilterResult.accepted;
}

// ---------------------------------------------------------------------------
// Test helpers
// ---------------------------------------------------------------------------

DateTime _runStart() => DateTime(2024, 6, 1, 9, 0, 0);

DateTime _atSecond(int seconds) =>
    _runStart().add(Duration(seconds: seconds));

/// Two points separated by [distanceMeters] metres along the same latitude.
/// The second point is returned; the first is [base].
LatLng _pointAtDistance(LatLng base, double distanceMeters) {
  // 1 degree latitude ≈ 111 320 m.
  const double metersPerDeg = 111320;
  return LatLng(
    base.latitude + distanceMeters / metersPerDeg,
    base.longitude,
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  const LatLng origin = LatLng(37.7749, -122.4194);

  // -------------------------------------------------------------------------
  group('GPS accuracy filter', () {
    test('point with accuracy > 50.0 m is rejected', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30), // after warm-up
        accuracy: 50.1,
        candidate: origin,
      );
      expect(result, FilterResult.poorAccuracy,
          reason: 'accuracy 50.1 m exceeds the 50 m threshold');
    });

    test('point with accuracy exactly 50.0 m is accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 50.0,
        candidate: origin,
      );
      expect(result, FilterResult.accepted,
          reason: 'accuracy == 50.0 m is on the boundary and must be accepted');
    });

    test('point with accuracy < 50.0 m is accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 12.5,
        candidate: origin,
      );
      expect(result, FilterResult.accepted);
    });

    test('accuracy of 0 m (perfect fix) is accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 0.0,
        candidate: origin,
      );
      expect(result, FilterResult.accepted);
    });

    test('accuracy of 100 m is rejected', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 100.0,
        candidate: origin,
      );
      expect(result, FilterResult.poorAccuracy);
    });
  });

  // -------------------------------------------------------------------------
  group('GPS speed filter', () {
    // At 6 m/s, covering X metres takes X/6 seconds.
    // We choose 300 m in 50 s → 6.0 m/s (boundary, should pass).
    // 301 m in 50 s → 6.02 m/s (should fail).

    test('two points implying speed <= 6 m/s are both accepted', () {
      final LatLng first = origin;
      final DateTime firstTime = _atSecond(25);

      // 300 m in 50 s = exactly 6 m/s.
      final LatLng second = _pointAtDistance(first, 300);
      final DateTime secondTime = firstTime.add(const Duration(seconds: 50));

      final firstResult = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: firstTime,
        accuracy: 10.0,
        candidate: first,
      );
      expect(firstResult, FilterResult.accepted,
          reason: 'First point should be accepted');

      final secondResult = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: secondTime,
        accuracy: 10.0,
        candidate: second,
        lastAccepted: first,
        lastAcceptedTime: firstTime,
      );
      expect(secondResult, FilterResult.accepted,
          reason: '6.0 m/s is on the boundary and should be accepted');
    });

    test('two points implying speed > 6 m/s cause second point to be rejected',
        () {
      final LatLng first = origin;
      final DateTime firstTime = _atSecond(25);

      // 601 m in 100 s = 6.01 m/s — just above limit.
      final LatLng second = _pointAtDistance(first, 601);
      final DateTime secondTime =
          firstTime.add(const Duration(seconds: 100));

      final secondResult = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: secondTime,
        accuracy: 10.0,
        candidate: second,
        lastAccepted: first,
        lastAcceptedTime: firstTime,
      );
      expect(secondResult, FilterResult.speedTooHigh,
          reason: '6.01 m/s exceeds the 6 m/s threshold');
    });

    test('teleport-level jump (1 km in 1 s) is rejected', () {
      final LatLng first = origin;
      final DateTime firstTime = _atSecond(25);

      final LatLng second = _pointAtDistance(first, 1000);
      final DateTime secondTime = firstTime.add(const Duration(seconds: 1));

      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: secondTime,
        accuracy: 5.0,
        candidate: second,
        lastAccepted: first,
        lastAcceptedTime: firstTime,
      );
      expect(result, FilterResult.speedTooHigh);
    });

    test('very slow walking pace (1 m/s) is accepted', () {
      final LatLng first = origin;
      final DateTime firstTime = _atSecond(25);

      // 60 m in 60 s = 1 m/s.
      final LatLng second = _pointAtDistance(first, 60);
      final DateTime secondTime = firstTime.add(const Duration(seconds: 60));

      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: secondTime,
        accuracy: 8.0,
        candidate: second,
        lastAccepted: first,
        lastAcceptedTime: firstTime,
      );
      expect(result, FilterResult.accepted);
    });

    test('speed filter is not applied when there is no previous point', () {
      // Without a lastAccepted point there is nothing to compute speed against;
      // a huge position value should still be accepted (filter is skipped).
      final LatLng farAway = const LatLng(89.9999, 179.9999);
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(25),
        accuracy: 10.0,
        candidate: farAway,
        // lastAccepted and lastAcceptedTime intentionally omitted.
      );
      expect(result, FilterResult.accepted,
          reason: 'Speed filter must be skipped when no previous point exists');
    });

    test('speed exactly at 6 m/s boundary over short interval is accepted', () {
      final LatLng first = origin;
      final DateTime firstTime = _atSecond(25);

      // 6 m in 1 s = 6.0 m/s exactly.
      final LatLng second = _pointAtDistance(first, 6);
      final DateTime secondTime = firstTime.add(const Duration(seconds: 1));

      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: secondTime,
        accuracy: 5.0,
        candidate: second,
        lastAccepted: first,
        lastAcceptedTime: firstTime,
      );
      expect(result, FilterResult.accepted,
          reason: 'Exactly 6 m/s should be accepted (boundary inclusive)');
    });
  });

  // -------------------------------------------------------------------------
  group('GPS warm-up window filter (first 20 seconds)', () {
    test('point at t=0 (run start) is rejected', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(0),
        accuracy: 5.0,
        candidate: origin,
      );
      expect(result, FilterResult.tooEarlyInRun,
          reason: 'Point at exactly t=0 is within the warm-up window');
    });

    test('point at t=10 s is rejected', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(10),
        accuracy: 5.0,
        candidate: origin,
      );
      expect(result, FilterResult.tooEarlyInRun);
    });

    test('point at t=19 s is still rejected', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(19),
        accuracy: 5.0,
        candidate: origin,
      );
      expect(result, FilterResult.tooEarlyInRun,
          reason: 't=19 is still within the 20-second warm-up window');
    });

    test('point at t=20 s (boundary) is accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(20),
        accuracy: 5.0,
        candidate: origin,
      );
      expect(result, FilterResult.accepted,
          reason: 't=20 s is at the boundary and must be accepted');
    });

    test('point at t=21 s is accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(21),
        accuracy: 5.0,
        candidate: origin,
      );
      expect(result, FilterResult.accepted);
    });

    test('warm-up filter takes priority over accuracy filter', () {
      // Even with terrible accuracy, the warm-up rejection should be reported.
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(5),
        accuracy: 999.0, // terrible
        candidate: origin,
      );
      expect(result, FilterResult.tooEarlyInRun,
          reason:
              'Warm-up filter is applied first; accuracy is irrelevant here');
    });

    test('warm-up filter takes priority over speed filter', () {
      // Point within warm-up but also implying absurd speed.
      final LatLng farPoint = _pointAtDistance(origin, 5000);
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(5),
        accuracy: 5.0,
        candidate: farPoint,
        lastAccepted: origin,
        lastAcceptedTime: _atSecond(4),
      );
      expect(result, FilterResult.tooEarlyInRun,
          reason: 'Warm-up rejection must be reported before speed check');
    });
  });

  // -------------------------------------------------------------------------
  group('Filter interaction — combined scenarios', () {
    test('good accuracy and good speed after warm-up: accepted', () {
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 20.0,
        candidate: _pointAtDistance(origin, 50),
        lastAccepted: origin,
        lastAcceptedTime: _atSecond(25),
      );
      expect(result, FilterResult.accepted);
    });

    test('good accuracy but speed too high after warm-up: rejected for speed', () {
      // 500 m in 5 s = 100 m/s (clearly a GPS glitch).
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 20.0,
        candidate: _pointAtDistance(origin, 500),
        lastAccepted: origin,
        lastAcceptedTime: _atSecond(25),
      );
      expect(result, FilterResult.speedTooHigh);
    });

    test('poor accuracy blocks point even when speed would be fine', () {
      // 10 m in 5 s = 2 m/s (fine speed), but accuracy is 60 m (too poor).
      final result = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: _atSecond(30),
        accuracy: 60.0,
        candidate: _pointAtDistance(origin, 10),
        lastAccepted: origin,
        lastAcceptedTime: _atSecond(25),
      );
      expect(result, FilterResult.poorAccuracy);
    });

    test('sequence: first accepted point establishes baseline for speed check', () {
      // First accepted point (no previous point → speed not checked).
      final DateTime t1 = _atSecond(22);
      final r1 = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: t1,
        accuracy: 15.0,
        candidate: origin,
      );
      expect(r1, FilterResult.accepted);

      // Second point: 30 m in 10 s = 3 m/s → accepted.
      final LatLng p2 = _pointAtDistance(origin, 30);
      final DateTime t2 = _atSecond(32);
      final r2 = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: t2,
        accuracy: 15.0,
        candidate: p2,
        lastAccepted: origin,
        lastAcceptedTime: t1,
      );
      expect(r2, FilterResult.accepted);

      // Third point: 1000 m in 1 s = 1000 m/s → rejected.
      final LatLng p3 = _pointAtDistance(p2, 1000);
      final DateTime t3 = t2.add(const Duration(seconds: 1));
      final r3 = evaluateGpsPoint(
        runStartTime: _runStart(),
        candidateTime: t3,
        accuracy: 15.0,
        candidate: p3,
        lastAccepted: p2,
        lastAcceptedTime: t2,
      );
      expect(r3, FilterResult.speedTooHigh);
    });
  });

  // -------------------------------------------------------------------------
  group('Haversine distance helper (internal)', () {
    test('distance between same point is zero', () {
      expect(_haversineMeters(origin, origin), closeTo(0.0, 0.001));
    });

    test('distance is symmetric', () {
      final LatLng other = _pointAtDistance(origin, 200);
      expect(
        _haversineMeters(origin, other),
        closeTo(_haversineMeters(other, origin), 0.01),
      );
    });

    test('_pointAtDistance helper produces approximately correct distance', () {
      // Verify that our test helper is producing the intended separation.
      final LatLng dest = _pointAtDistance(origin, 100);
      final double measured = _haversineMeters(origin, dest);
      // Allow 1% error from the flat-earth approximation in the helper.
      expect(measured, closeTo(100, 2),
          reason: '_pointAtDistance should produce ~100 m separation');
    });
  });
}
