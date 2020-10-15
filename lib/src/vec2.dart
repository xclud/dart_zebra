import 'package:vector_math/vector_math_64.dart';

Vector2 transformMat2(Vector2 out, Vector2 a, Matrix2 m) {
  var x = a[0];
  var y = a[1];

  out[0] = m[0] * x + m[2] * y;
  out[1] = m[1] * x + m[3] * y;

  m.transform(a);
  return out;
}
