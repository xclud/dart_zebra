import 'package:zebra/src/common/image_wrapper.dart';
import 'package:zebra/src/types.dart';

class _Dir {
  num cx;
  num cy;
  num dir;

  _Dir({this.cx, this.cy, this.dir});
}

class Tracer {
  ImageWrapper imageWrapper;
  ImageWrapper labelWrapper;

  Tracer(this.imageWrapper, this.labelWrapper);

  static const searchDirections = [
    [0, 1],
    [1, 1],
    [1, 0],
    [1, -1],
    [0, -1],
    [-1, -1],
    [-1, 0],
    [-1, 1]
  ];

  Vertex2D _vertex2D(num x, num y, num dir) {
    return Vertex2D(dir: dir, x: x, y: y, next: null, prev: null);
  }

  bool trace(_Dir current, int color, int label, int edgelabel) {
    var imageData = imageWrapper.data,
        labelData = labelWrapper.data,
        width = imageWrapper.size.x;

    for (var i = 0; i < 7; i++) {
      var y = current.cy + searchDirections[current.dir][0];
      var x = current.cx + searchDirections[current.dir][1];
      var pos = y * width + x;
      if ((imageData[pos] == color) &&
          ((labelData[pos] == 0) || (labelData[pos] == label))) {
        labelData[pos] = label;
        current.cy = y;
        current.cx = x;
        return true;
      } else {
        if (labelData[pos] == 0) {
          labelData[pos] = edgelabel;
        }
        current.dir = (current.dir + 1) % 8;
      }
    }
    return false;
  }

  Vertex2D contourTracing(num sy, num sx, int label, int color, int edgelabel) {
    Vertex2D fv;

    var current = _Dir(cx: sx, cy: sy, dir: 0);

    if (trace(current, color, label, edgelabel)) {
      fv = _vertex2D(sx, sy, current.dir);
      var cv = fv;
      var ldir = current.dir;
      var p = _vertex2D(current.cx, current.cy, 0);
      p.prev = cv;
      cv.next = p;
      p.next = null;
      cv = p;
      do {
        current.dir = (current.dir + 6) % 8;
        trace(current, color, label, edgelabel);
        if (ldir != current.dir) {
          cv.dir = current.dir;
          p = _vertex2D(current.cx, current.cy, 0);
          p.prev = cv;
          cv.next = p;
          p.next = null;
          cv = p;
        } else {
          cv.dir = ldir;
          cv.x = current.cx;
          cv.y = current.cy;
        }
        ldir = current.dir;
      } while (current.cx != sx || current.cy != sy);
      fv.prev = cv.prev;
      cv.prev.next = fv;
    }

    return fv;
  }
}
