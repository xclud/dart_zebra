import 'package:zebra/src/common/image_wrapper.dart';
import 'package:zebra/src/locator/tracer.dart';
import 'package:zebra/src/types.dart';

class Contour2D {
  int dir;
  int index;
  Vertex2D firstVertex;
  Contour2D insideContours;
  Contour2D nextpeer;
  Contour2D prevpeer;
}

const OUTSIDE_EDGE = -32767;
const INSIDE_EDGE = -32766;

const CW_DIR = 0;
const CCW_DIR = 1;
const UNKNOWN_DIR = 2;

class RasterResult {
  Contour2D cc;
  int count;

  RasterResult({this.cc, this.count});
}

class Rasterizer {
  final ImageWrapper imageWrapper;
  final ImageWrapper labelWrapper;
  final Tracer tracer;

  Rasterizer(this.imageWrapper, this.labelWrapper)
      : tracer = Tracer(imageWrapper, labelWrapper);

  RasterResult rasterize(int depthlabel) {
    var imageData = imageWrapper.data,
        labelData = labelWrapper.data,
        width = imageWrapper.size.x,
        height = imageWrapper.size.y;

    var colorMap = List<int>(400);

    for (var i = 0; i < 400; i++) {
      colorMap[i] = 0;
    }

    colorMap[0] = imageData[0];
    Contour2D cc;
    Contour2D sc;
    int connectedCount = 0;

    for (var cy = 1; cy < height - 1; cy++) {
      var labelindex = 0;
      var bc = colorMap[0];
      for (var cx = 1; cx < width - 1; cx++) {
        final pos = cy * width + cx;
        if (labelData[pos] == 0) {
          final color = imageData[pos];
          if (color != bc) {
            if (labelindex == 0) {
              final lc = connectedCount + 1;
              colorMap[lc] = color;
              bc = color;
              final vertex =
                  tracer.contourTracing(cy, cx, lc, color, OUTSIDE_EDGE);
              if (vertex != null) {
                connectedCount++;
                labelindex = lc;
                final p = Contour2D();
                p.dir = CW_DIR;
                p.index = labelindex;
                p.firstVertex = vertex;
                p.nextpeer = cc;
                p.insideContours = null;
                if (cc != null) {
                  cc.prevpeer = p;
                }
                cc = p;
              }
            } else {
              final vertex =
                  tracer.contourTracing(cy, cx, INSIDE_EDGE, color, labelindex);
              if (vertex != null) {
                final p = Contour2D();
                p.firstVertex = vertex;
                p.insideContours = null;
                if (depthlabel == 0) {
                  p.dir = CCW_DIR;
                } else {
                  p.dir = CW_DIR;
                }
                p.index = depthlabel;
                sc = cc;
                while ((sc != null) && sc.index != labelindex) {
                  sc = sc.nextpeer;
                }
                if (sc != null) {
                  p.nextpeer = sc.insideContours;
                  if (sc.insideContours != null) {
                    sc.insideContours.prevpeer = p;
                  }
                  sc.insideContours = p;
                }
              }
            }
          } else {
            labelData[pos] = labelindex;
          }
        } else if (labelData[pos] == OUTSIDE_EDGE ||
            labelData[pos] == INSIDE_EDGE) {
          labelindex = 0;
          if (labelData[pos] == INSIDE_EDGE) {
            bc = imageData[pos];
          } else {
            bc = colorMap[0];
          }
        } else {
          labelindex = labelData[pos];
          bc = colorMap[labelindex];
        }
      }
    }
    sc = cc;
    while (sc != null) {
      sc.index = depthlabel;
      sc = sc.nextpeer;
    }
    return RasterResult(cc: cc, count: connectedCount);
  }

  void drawContour(dynamic canvas, Contour2D firstContour) {
    var ctx = canvas.getContext("2d");
    var pq = firstContour, iq, q, p;

    ctx.strokeStyle = "red";
    ctx.fillStyle = "red";
    ctx.lineWidth = 1;

    if (pq != null) {
      iq = pq.insideContours;
    } else {
      iq = null;
    }

    while (pq != null) {
      if (iq != null) {
        q = iq;
        iq = iq.nextpeer;
      } else {
        q = pq;
        pq = pq.nextpeer;
        if (pq != null) {
          iq = pq.insideContours;
        } else {
          iq = null;
        }
      }

      switch (q.dir) {
        case CW_DIR:
          ctx.strokeStyle = "red";
          break;
        case CCW_DIR:
          ctx.strokeStyle = "blue";
          break;
        case UNKNOWN_DIR:
          ctx.strokeStyle = "green";
          break;
      }

      p = q.firstVertex;
      ctx.beginPath();
      ctx.moveTo(p.x, p.y);
      do {
        p = p.next;
        ctx.lineTo(p.x, p.y);
      } while (p != q.firstVertex);
      ctx.stroke();
    }
  }
}
