import 'dart:math' as math;

import 'package:latlong2/latlong.dart';

/// Vertex-budget simplification for polygons, run inside the parsing isolate.
///
/// This replaces the previous index-stride decimation
/// (`ring[i += stride]`), which sheared straight edges and moved vertices off
/// their true position. Douglas–Peucker keeps the vertices that carry the most
/// shape information, so the same vertex budget produces a far more faithful
/// outline — and, crucially, the budget itself now grows with zoom (see
/// `MapDetail.maxPoints`), so zooming in actually reveals new detail.
abstract final class GeoSimplify {
  /// Smallest tolerance search resolution worth computing.
  static const _minTolerance = 1e-7;

  /// Bisection passes; 2^-18 is well below display precision.
  static const _bisectionSteps = 18;

  /// Simplify [ring] to at most [maxPoints] vertices.
  ///
  /// Ring closure is preserved when [ring] is closed. If the ring is already
  /// within budget it is returned with duplicates removed and nothing else
  /// changed, so identical inputs produce identical outputs (stable rendering).
  static List<LatLng> ring(List<LatLng> ring, int maxPoints) {
    if (maxPoints < 3) return ring;

    final closed = _isClosed(ring);
    final open = _dedupe(closed ? ring.sublist(0, ring.length - 1) : ring);

    // Re-closing the ring appends the first vertex again, so the open polyline
    // must fit in one fewer slot or the result would exceed [maxPoints].
    final budget = closed ? maxPoints - 1 : maxPoints;
    if (open.length <= budget) return _close(open, closed);
    if (budget < 2) return _close(open, closed);

    var best = open;
    var low = 0.0;
    var high = _diagonal(open);
    if (high <= _minTolerance) return _close(open, closed);

    for (var step = 0; step < _bisectionSteps && high > _minTolerance; step++) {
      final mid = (low + high) / 2;
      final candidate = _douglasPeucker(open, mid);
      if (candidate.length > budget) {
        // Too detailed: widen the tolerance.
        low = mid;
      } else {
        // Fits: keep it and try to recover a little more detail.
        best = candidate;
        high = mid;
      }
    }

    return _close(best, closed);
  }

  /// Iterative Douglas–Peucker (stack based, so 10k-vertex rings cannot blow
  /// the isolate's call stack).
  static List<LatLng> _douglasPeucker(List<LatLng> points, double tolerance) {
    if (points.length <= 2) return points;

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    final toleranceSquared = tolerance * tolerance;
    final stack = <int>[0, points.length - 1];

    while (stack.isNotEmpty) {
      final last = stack.removeLast();
      final first = stack.removeLast();
      if (last <= first + 1) continue;

      var maxDistanceSquared = 0.0;
      var splitAt = -1;
      for (var i = first + 1; i < last; i++) {
        final distanceSquared = _distanceToSegmentSquared(
          points[i],
          points[first],
          points[last],
        );
        if (distanceSquared > maxDistanceSquared) {
          maxDistanceSquared = distanceSquared;
          splitAt = i;
        }
      }

      if (splitAt != -1 && maxDistanceSquared > toleranceSquared) {
        keep[splitAt] = true;
        stack.addAll(<int>[first, splitAt, splitAt, last]);
      }
    }

    final result = <LatLng>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) result.add(points[i]);
    }
    return result;
  }

  /// Squared distance from [point] to the segment `a → b`, in a locally
  /// isotropic degrees space (longitude scaled by `cos(latitude)`).
  static double _distanceToSegmentSquared(LatLng point, LatLng a, LatLng b) {
    final scale = math.cos(a.latitude * math.pi / 180).abs();

    final px = point.longitude * scale;
    final py = point.latitude;
    final ax = a.longitude * scale;
    final ay = a.latitude;
    final bx = b.longitude * scale;
    final by = b.latitude;

    final dx = bx - ax;
    final dy = by - ay;
    final lengthSquared = dx * dx + dy * dy;

    if (lengthSquared == 0) {
      final ox = px - ax;
      final oy = py - ay;
      return ox * ox + oy * oy;
    }

    var t = ((px - ax) * dx + (py - ay) * dy) / lengthSquared;
    t = t.clamp(0.0, 1.0);

    final cx = ax + t * dx;
    final cy = ay + t * dy;
    final ox = px - cx;
    final oy = py - cy;
    return ox * ox + oy * oy;
  }

  static List<LatLng> _dedupe(List<LatLng> points) {
    if (points.length < 2) return points;
    final result = <LatLng>[points.first];
    for (var i = 1; i < points.length; i++) {
      if (points[i] != result.last) result.add(points[i]);
    }
    return result;
  }

  static List<LatLng> _close(List<LatLng> points, bool closed) {
    if (!closed || points.length < 2) return points;
    if (points.first == points.last) return points;
    return <LatLng>[...points, points.first];
  }

  static bool _isClosed(List<LatLng> ring) =>
      ring.length > 2 && ring.first == ring.last;

  static double _diagonal(List<LatLng> points) {
    var south = double.infinity;
    var west = double.infinity;
    var north = double.negativeInfinity;
    var east = double.negativeInfinity;

    for (final point in points) {
      if (point.latitude < south) south = point.latitude;
      if (point.latitude > north) north = point.latitude;
      if (point.longitude < west) west = point.longitude;
      if (point.longitude > east) east = point.longitude;
    }

    final dLat = north - south;
    final dLng = east - west;
    if (!dLat.isFinite || !dLng.isFinite) return 0;
    return math.sqrt(dLat * dLat + dLng * dLng);
  }
}
