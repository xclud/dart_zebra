library bresenham;

import 'package:zebra/src/common/image_wrapper.dart';
import 'package:zebra/src/types.dart';

const _Slope_DIR_UP = 1;
const _Slope_DIR_DOWN = -1;

/// Scans a line of the given image from point p1 to p2 and returns a result object containing
/// gray-scale values (0-255) of the underlying pixels in addition to the min
/// and max values.
/// @param {Object} imageWrapper
/// @param {Object} p1 The start point {x,y}
/// @param {Object} p2 The end point {x,y}
/// @returns {line, min, max}
BarcodeLine getBarcodeLine(ImageWrapper imageWrapper, Point p1, Point p2) {
  /* eslint-disable no-bitwise */
  int x0 = p1?.x ?? 0;
  int y0 = p1?.y ?? 0;
  int x1 = p2?.x ?? 0;
  int y1 = p2?.y ?? 0;

  /* eslint-disable no-bitwise */
  final steep = (y1 - y0).abs() > (x1 - x0).abs();
  final line = <int>[];
  final imageData = imageWrapper.data;
  final width = imageWrapper.size.x;
  int val;
  var min = 255;
  var max = 0;

  void read(int a, int b) {
    val = imageData[b * width + a];
    min = val < min ? val : min;
    max = val > max ? val : max;
    line.add(val);
  }

  if (steep) {
    var tmp = x0;
    x0 = y0;
    y0 = tmp;

    tmp = x1;
    x1 = y1;
    y1 = tmp;
  }
  if (x0 > x1) {
    var tmp = x0;
    x0 = x1;
    x1 = tmp;

    tmp = y0;
    y0 = y1;
    y1 = tmp;
  }

  final deltaX = x1 - x0;
  final deltaY = (y1 - y0).abs();
  var error = (deltaX / 2.0);
  var y = y0;
  final yStep = y0 < y1 ? 1 : -1;
  for (var x = x0; x < x1; x++) {
    if (steep) {
      read(y, x);
    } else {
      read(x, y);
    }
    error -= deltaY;
    if (error < 0) {
      y += yStep;
      error += deltaX;
    }
  }

  return BarcodeLine(
    line: line,
    min: min,
    max: max,
  );
}

/// Converts the result from [getBarcodeLine] into a binary representation
/// also considering the frequency and slope of the signal for more robust results
/// @param {Object} result {line, min, max}
BinaryLine toBinaryLine(BarcodeLine result) {
  final min = result.min;
  final max = result.max;
  final line = result.line;
  final center = min + (max - min) / 2.0;
  final extrema = <Extrema>[];
  int dir;
  var threshold = (max - min) / 12.0;
  final rThreshold = -threshold;

  // 1. find extrema
  var currentDir = line[0] > center ? _Slope_DIR_UP : _Slope_DIR_DOWN;
  extrema.add(Extrema(
    pos: 0,
    val: line[0],
  ));
  for (var i = 0; i < line.length - 2; i++) {
    final slope = (line[i + 1] - line[i]);
    final slope2 = (line[i + 2] - line[i + 1]);
    if ((slope + slope2) < rThreshold && line[i + 1] < (center * 1.5)) {
      dir = _Slope_DIR_DOWN;
    } else if ((slope + slope2) > threshold && line[i + 1] > (center * 0.5)) {
      dir = _Slope_DIR_UP;
    } else {
      dir = currentDir;
    }

    ///!==
    if (currentDir != dir) {
      extrema.add(Extrema(
        pos: i,
        val: line[i],
      ));
      currentDir = dir;
    }
  }

  extrema.add(Extrema(
    pos: line.length,
    val: line[line.length - 1],
  ));

  for (var j = extrema[0].pos; j < extrema[1].pos; j++) {
    line[j] = line[j] > center ? 0 : 1;
  }

  // iterate over extrema and convert to binary based on avg between minmax
  for (var i = 1; i < extrema.length - 1; i++) {
    if (extrema[i + 1].val > extrema[i].val) {
      threshold = (extrema[i].val +
          ((extrema[i + 1].val - extrema[i].val) / 3) * 2); // | 0;
    } else {
      threshold = (extrema[i + 1].val +
          ((extrema[i].val - extrema[i + 1].val) / 3)); // | 0;
    }

    for (var j = extrema[i].pos; j < extrema[i + 1].pos; j++) {
      line[j] = line[j] > threshold ? 0 : 1;
    }
  }

  return BinaryLine(
    line: line,
    threshold: threshold,
  );
}

/// Used for development only
void printFrequency(line, canvas) {
  final ctx = canvas.getContext('2d');
  // eslint-disable-next-line no-param-reassign
  canvas.width = line.length;
  // eslint-disable-next-line no-param-reassign
  canvas.height = 256;

  ctx.beginPath();
  ctx.strokeStyle = 'blue';
  for (var i = 0; i < line.length; i++) {
    ctx.moveTo(i, 255);
    ctx.lineTo(i, 255 - line[i]);
  }
  ctx.stroke();
  ctx.closePath();
}

void printPattern(line, canvas) {
  final ctx = canvas.getContext('2d');

  // eslint-disable-next-line no-param-reassign
  canvas.width = line.length;
  ctx.fillColor = 'black';
  for (var i = 0; i < line.length; i++) {
    if (line[i] == 1) {
      //===
      ctx.fillRect(i, 0, 1, 100);
    }
  }
}
