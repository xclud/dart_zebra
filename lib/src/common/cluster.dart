import 'dart:math' as math;

import 'package:zebra/src/common/image_wrapper.dart';
import 'package:vector_math/vector_math_64.dart';

class Circle {
  double rad;
  Vector2 vec;

  Circle({this.rad, this.vec});
}

class MomentPoint {
  dynamic rad;
  Moment point;
  int id;

  MomentPoint({this.rad, this.point, this.id});
}

/// Creates a cluster for grouping similar orientations of datapoints
class Cluster2 {
  final num threshold;
  final _pointMap = <int, MomentPoint>{};
  final _points = <MomentPoint>[];
  final _center = Circle(
    rad: 0,
    vec: Vector2(0, 0),
  );

  Cluster2(MomentPoint point, this.threshold) {
    _add(point);
    _updateCenter();
  }

  void _add(MomentPoint pointToAdd) {
    _pointMap[pointToAdd.id] = pointToAdd;
    _points.add(pointToAdd);
  }

  void _updateCenter() {
    var sum = 0;
    for (var i = 0; i < _points.length; i++) {
      sum += _points[i].rad;
    }
    _center.rad = sum / _points.length;
    _center.vec = Vector2(math.cos(_center.rad), math.sin(_center.rad));
  }

  void add(MomentPoint pointToAdd) {
    if (!_pointMap.containsKey(pointToAdd.id)) {
      _add(pointToAdd);
      _updateCenter();
    }
  }

  bool fits(MomentPoint otherPoint) {
    // check cosine similarity to center-angle
    final similarity = otherPoint.point.vec.dot(_center.vec).abs();
    if (similarity > threshold) {
      return true;
    }
    return false;
  }

  List<MomentPoint> getPoints() {
    return _points;
  }

  Circle getCenter() {
    return _center;
  }
}
