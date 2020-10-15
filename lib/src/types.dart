import 'package:vector_math/vector_math_64.dart';

class Extrema {
  int pos;
  int val;

  Extrema({this.pos, this.val});
}

class Vertex2D {
  num x;
  num y;
  num dir;

  Vertex2D next;
  Vertex2D prev;

  Vertex2D({this.x, this.y, this.dir, this.next, this.prev});
}

class Point {
  int x;
  int y;

  Vector2 get vec => Vector2(x.toDouble(), y.toDouble());

  Point({this.x, this.y});
}

class BarcodeLine {
  List<int> line;
  int min;
  int max;

  BarcodeLine({this.line, this.min, this.max});
}

class BinaryLine {
  List<int> line;
  double threshold;

  BinaryLine({this.line, this.threshold});
}

class ImageReference {
  int x;
  int y;

  ImageReference({this.x, this.y});

  Vector2 toVec2() {
    return Vector2(x.toDouble(), y.toDouble());
  }

  Vector3 toVec3() {
    return Vector3(x.toDouble(), y.toDouble(), 1);
  }

  ImageReference round() {
    this.x = this.x > 0.0 ? (this.x + 0.5).floor() : (this.x - 0.5).floor();
    this.y = this.y > 0.0 ? (this.y + 0.5).floor() : (this.y - 0.5).floor;
    return this;
  }
}

ImageReference imageRef(int x, int y) {
  return ImageReference(x: x, y: y);
}
