import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maps_toolkit/maps_toolkit.dart' as mt;
import '../models/app_models.dart';
import 'database_service.dart';

class TerritoryLogicService {
  final DatabaseService _db = DatabaseService();

  /// Converts a raw GPS route (list of LatLng) into a simplified Territory Polygon.
  /// MVP Algorithm: Create a bounding box based on the min/max lat and long of the run.
  Future<Territory?> generateTerritoryFromRun({
    required String userId,
    required String userName,
    required List<LatLng> route,
    required double distanceKm,
  }) async {
    // Basic protection: don't claim territories for tiny runs.
    if (route.length < 5 || distanceKm < 0.1) {
      return null;
    }

    // Step 1: Simplify the GPS route using Douglas-Peucker (8m tolerance)
    final mtPoints = route
        .map((p) => mt.LatLng(p.latitude, p.longitude))
        .toList();
    final simplified = mt.PolygonUtil.simplify(mtPoints, 8.0);
    List<LatLng> polygonPoints = simplified
        .map((p) => LatLng(p.latitude, p.longitude))
        .toList();

    // Step 2: Close the polygon
    // If end point is within 150m of start, treat as a closed loop
    final distanceToStart = Geolocator.distanceBetween(
      polygonPoints.last.latitude,
      polygonPoints.last.longitude,
      polygonPoints.first.latitude,
      polygonPoints.first.longitude,
    );
    if (distanceToStart > 150) {
      // Add closing line from end back to start
      polygonPoints = [...polygonPoints, polygonPoints.first];
    }

    // Step 3: Calculate area using spherically correct formula
    final mtPolygon = polygonPoints
        .map((p) => mt.LatLng(p.latitude, p.longitude))
        .toList();
    double areaSqKm = mt.SphericalUtil.computeArea(mtPolygon).toDouble() / 1e6;
    areaSqKm = areaSqKm < 0.001 ? 0.001 : areaSqKm;

    // Step 4: Check for overlaps with existing territories
    // (MVP: Query all territories and check bounding box collision)
    // NOTE: In production, we would use GeoQueries to limit the search space.
    final existingTerritories = await _db.streamGlobalTerritories().first;

    Territory? overtakenTerritory;

    for (var existing in existingTerritories) {
      if (_doesOverlap(polygonPoints, existing.polygonPoints)) {
        // Simple overtake rule: If the new run is longer than the old run's area score, overtake it.
        // Or for MVP, simply the last active runner claims the intersecting zone.
        overtakenTerritory = existing;
        break;
      }
    }

    // Step 5: Write to Database
    if (overtakenTerritory != null) {
      await _db.overWriteTerritoryOwner(
        overtakenTerritory.id,
        overtakenTerritory.ownerId,
        userId,
        userName,
        areaSqKm: overtakenTerritory.areaSqKm,
        oldOwnerName: overtakenTerritory.ownerName,
      );

      // We return the old territory but with updated owner details
      return Territory(
        id: overtakenTerritory.id,
        ownerId: userId,
        ownerName: userName,
        areaSqKm: overtakenTerritory.areaSqKm,
        polygonPoints: overtakenTerritory.polygonPoints,
        createdAt: DateTime.now(),
      );
    } else {
      // Create a brand new territory
      final newTerritory = Territory(
        id: '', // Set by DatabaseService
        ownerId: userId,
        ownerName: userName,
        areaSqKm: areaSqKm,
        polygonPoints: polygonPoints,
        createdAt: DateTime.now(),
      );

      await _db.claimTerritory(newTerritory);
      return newTerritory;
    }
  }

  // AABB overlap check — computes bounding box dynamically for both polygons.
  bool _doesOverlap(List<LatLng> polyA, List<LatLng> polyB) {
    if (polyA.isEmpty || polyB.isEmpty) return false;

    double minLatA = polyA.first.latitude, maxLatA = polyA.first.latitude;
    double minLngA = polyA.first.longitude, maxLngA = polyA.first.longitude;
    for (final p in polyA) {
      if (p.latitude < minLatA) minLatA = p.latitude;
      if (p.latitude > maxLatA) maxLatA = p.latitude;
      if (p.longitude < minLngA) minLngA = p.longitude;
      if (p.longitude > maxLngA) maxLngA = p.longitude;
    }

    double minLatB = polyB.first.latitude, maxLatB = polyB.first.latitude;
    double minLngB = polyB.first.longitude, maxLngB = polyB.first.longitude;
    for (final p in polyB) {
      if (p.latitude < minLatB) minLatB = p.latitude;
      if (p.latitude > maxLatB) maxLatB = p.latitude;
      if (p.longitude < minLngB) minLngB = p.longitude;
      if (p.longitude > maxLngB) maxLngB = p.longitude;
    }

    return minLngA <= maxLngB && maxLngA >= minLngB &&
        minLatA <= maxLatB && maxLatA >= minLatB;
  }
}
