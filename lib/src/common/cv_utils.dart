import 'dart:math' as math;
import 'dart:math';
import 'package:zebra/src/common/array_helper.dart';
import 'package:zebra/src/common/cluster.dart';
import 'package:zebra/src/common/image_wrapper.dart';
import 'package:zebra/src/types.dart';

typedef ScoreFunction = num Function(Cluster2);

/// Computes an integral image of a given grayscale image.
void computeIntegralImage2(
    ImageWrapper imageWrapper, ImageWrapper integralWrapper) {
  final imageData = imageWrapper.data;
  final width = imageWrapper.size.x;
  final height = imageWrapper.size.y;
  final integralImageData = integralWrapper.data;
  var sum = 0;
  var posA = 0;
  var posB = 0;
  var posC = 0;
  var posD = 0;
  var x;
  var y;

  // sum up first column
  posB = width;
  sum = 0;
  for (y = 1; y < height; y++) {
    sum += imageData[posA];
    integralImageData[posB] += sum;
    posA += width;
    posB += width;
  }

  posA = 0;
  posB = 1;
  sum = 0;
  for (x = 1; x < width; x++) {
    sum += imageData[posA];
    integralImageData[posB] += sum;
    posA++;
    posB++;
  }

  for (y = 1; y < height; y++) {
    posA = y * width + 1;
    posB = (y - 1) * width + 1;
    posC = y * width;
    posD = (y - 1) * width;
    for (x = 1; x < width; x++) {
      integralImageData[posA] += imageData[posA] +
          integralImageData[posB] +
          integralImageData[posC] -
          integralImageData[posD];
      posA++;
      posB++;
      posC++;
      posD++;
    }
  }
}

void computeIntegralImage(
    ImageWrapper imageWrapper, ImageWrapper integralWrapper) {
  final imageData = imageWrapper.data;
  final width = imageWrapper.size.x;
  final height = imageWrapper.size.y;
  final integralImageData = integralWrapper.data;
  var sum = 0;

  // sum up first row
  for (var i = 0; i < width; i++) {
    sum += imageData[i];
    integralImageData[i] = sum;
  }

  for (var v = 1; v < height; v++) {
    sum = 0;
    for (var u = 0; u < width; u++) {
      sum += imageData[v * width + u];
      integralImageData[((v) * width) + u] =
          sum + integralImageData[(v - 1) * width + u];
    }
  }
}

void thresholdImage(
    ImageWrapper imageWrapper, int threshold, ImageWrapper targetWrapper) {
  if (targetWrapper == null) {
    // eslint-disable-next-line no-param-reassign
    targetWrapper = imageWrapper;
  }
  final imageData = imageWrapper.data;
  var length = imageData.length;
  final targetData = targetWrapper.data;

  while ((length--) != 0) {
    targetData[length] = imageData[length] < threshold ? 1 : 0;
  }
}

List<int> computeHistogram(ImageWrapper imageWrapper, bitsPerPixel) {
  if (bitsPerPixel == null || bitsPerPixel == 0) {
    // eslint-disable-next-line no-param-reassign
    bitsPerPixel = 8;
  }
  final imageData = imageWrapper.data;
  var length = imageData.length;
  final bitShift = 8 - bitsPerPixel;
  final bucketCnt = 1 << bitsPerPixel;
  final hist = List<int>(bucketCnt);

  while ((length--) != 0) {
    hist[imageData[length] >> bitShift]++;
  }
  return hist;
}

List<int> sharpenLine(List<int> line) {
  var i;
  final length = line.length;
  var left = line[0];
  var center = line[1];

  for (i = 1; i < length - 1; i++) {
    final right = line[i + 1];
    //  -1 4 -1 kernel
    // eslint-disable-next-line no-param-reassign
    line[i - 1] = (((center * 2) - left - right)) & 255;
    left = center;
    center = right;
  }
  return line;
}

int determineOtsuThreshold(ImageWrapper imageWrapper, {int bitsPerPixel = 8}) {
  var hist;
  final bitShift = 8 - bitsPerPixel;

  int px(int init, int end) {
    var sum = 0;
    for (var i = init; i <= end; i++) {
      sum += hist[i];
    }
    return sum;
  }

  int mx(int init, int end) {
    var sum = 0;

    for (var i = init; i <= end; i++) {
      sum += i * hist[i];
    }

    return sum;
  }

  int determineThreshold() {
    final vet = [0];
    var p1;
    var p2;
    var p12;
    var m1;
    var m2;
    var m12;
    final max = (1 << bitsPerPixel) - 1;

    hist = computeHistogram(imageWrapper, bitsPerPixel);
    for (var k = 1; k < max; k++) {
      p1 = px(0, k);
      p2 = px(k + 1, max);
      p12 = p1 * p2;
      if (p12 == 0) //===
      {
        p12 = 1;
      }
      m1 = mx(0, k) * p2;
      m2 = mx(k + 1, max) * p1;
      m12 = m1 - m2;
      vet[k] = m12 * m12 / p12;
    }
    return maxIndex(vet);
  }

  final threshold = determineThreshold();
  return threshold << bitShift;
}

int otsuThreshold(imageWrapper, targetWrapper) {
  final threshold = determineOtsuThreshold(imageWrapper);

  thresholdImage(imageWrapper, threshold, targetWrapper);
  return threshold;
}

// local thresholding
void computeBinaryImage(ImageWrapper imageWrapper, ImageWrapper integralWrapper,
    ImageWrapper targetWrapper) {
  computeIntegralImage(imageWrapper, integralWrapper);

  if (targetWrapper == null) {
    // eslint-disable-next-line no-param-reassign
    targetWrapper = imageWrapper;
  }
  final imageData = imageWrapper.data;
  final targetData = targetWrapper.data;
  final width = imageWrapper.size.x;
  final height = imageWrapper.size.y;
  final integralImageData = integralWrapper.data;
  var sum = 0;
  var v;
  var u;
  final kernel = 3;
  var A;
  var B;
  var C;
  var D;
  var avg;
  final size = (kernel * 2 + 1) * (kernel * 2 + 1);

  // clear out top & bottom-border
  for (v = 0; v <= kernel; v++) {
    for (u = 0; u < width; u++) {
      targetData[((v) * width) + u] = 0;
      targetData[(((height - 1) - v) * width) + u] = 0;
    }
  }

  // clear out left & right border
  for (v = kernel; v < height - kernel; v++) {
    for (u = 0; u <= kernel; u++) {
      targetData[((v) * width) + u] = 0;
      targetData[((v) * width) + (width - 1 - u)] = 0;
    }
  }

  for (v = kernel + 1; v < height - kernel - 1; v++) {
    for (u = kernel + 1; u < width - kernel; u++) {
      A = integralImageData[(v - kernel - 1) * width + (u - kernel - 1)];
      B = integralImageData[(v - kernel - 1) * width + (u + kernel)];
      C = integralImageData[(v + kernel) * width + (u - kernel - 1)];
      D = integralImageData[(v + kernel) * width + (u + kernel)];
      sum = D - C - B + A;
      avg = sum / (size);
      targetData[v * width + u] = imageData[v * width + u] > (avg + 5) ? 0 : 1;
    }
  }
}

List<Cluster2> cluster(List<Moment> points, num threshold) {
  final clusters = <Cluster2>[];

  bool addToCluster(MomentPoint newPoint) {
    var found = false;
    for (var k = 0; k < clusters.length; k++) {
      final thisCluster = clusters[k];
      if (thisCluster.fits(newPoint)) {
        thisCluster.add(newPoint);
        found = true;
      }
    }
    return found;
  }

  // iterate over each cloud
  for (var i = 0; i < points.length; i++) {
    final point = MomentPoint(point: points[i], id: i, rad: points[i].rad);

    if (!addToCluster(point)) {
      clusters.add(Cluster2(point, threshold));
    }
  }
  return clusters;
}

class Tracer {
  static List trace(List<Point> points, List<num> vec) {
    final maxIterations = 10;
    var result = <Point>[];
    var centerPos = 0;
    var currentPos = 0;

    int trace(int idx, bool forward) {
      Point predictedPos;
      final thresholdX = 1;
      final thresholdY = (vec[1] / 10.0).abs();
      var found = false;

      bool match(Point pos, Point predicted) {
        if (pos.x > (predicted.x - thresholdX) &&
            pos.x < (predicted.x + thresholdX) &&
            pos.y > (predicted.y - thresholdY) &&
            pos.y < (predicted.y + thresholdY)) {
          return true;
        }
        return false;
      }

      // check if the next index is within the vec specifications
      // if not, check as long as the threshold is met

      final from = points[idx];
      if (forward) {
        predictedPos = Point(
          x: from.x + vec[0],
          y: from.y + vec[1],
        );
      } else {
        predictedPos = Point(
          x: from.x - vec[0],
          y: from.y - vec[1],
        );
      }

      var toIdx = forward ? idx + 1 : idx - 1;
      var to = points[toIdx];
      while (to != null &&
          (found = match(to, predictedPos)) != true &&
          ((to.y - from.y).abs() < vec[1])) {
        toIdx = forward ? toIdx + 1 : toIdx - 1;
        to = points[toIdx];
      }

      return found ? toIdx : null;
    }

    final rnd = math.Random();
    for (var iteration = 0; iteration < maxIterations; iteration++) {
      // randomly select point to start with
      centerPos = (rnd.nextDouble() * points.length).floor();

      // trace forward
      final top = <Point>[];
      currentPos = centerPos;
      top.add(points[currentPos]);
      // eslint-disable-next-line no-cond-assign
      while ((currentPos = trace(currentPos, true)) != null) {
        top.add(points[currentPos]);
      }
      if (centerPos > 0) {
        currentPos = centerPos;
        // eslint-disable-next-line no-cond-assign
        while ((currentPos = trace(currentPos, false)) != null) {
          top.add(points[currentPos]);
        }
      }

      if (top.length > result.length) {
        result = top;
      }
    }
    return result;
  }
}

const DILATE = 1;
const ERODE = 2;

void dilate(ImageWrapper inImageWrapper, ImageWrapper outImageWrapper) {
  final inImageData = inImageWrapper.data;
  final outImageData = outImageWrapper.data;
  final height = inImageWrapper.size.y;
  final width = inImageWrapper.size.x;

  for (var v = 1; v < height - 1; v++) {
    for (var u = 1; u < width - 1; u++) {
      final yStart1 = v - 1;
      final yStart2 = v + 1;
      final xStart1 = u - 1;
      final xStart2 = u + 1;
      final sum = inImageData[yStart1 * width + xStart1] +
          inImageData[yStart1 * width + xStart2] +
          inImageData[v * width + u] +
          inImageData[yStart2 * width + xStart1] +
          inImageData[yStart2 * width + xStart2];
      outImageData[v * width + u] = sum > 0 ? 1 : 0;
    }
  }
}

void erode(ImageWrapper inImageWrapper, ImageWrapper outImageWrapper) {
  final inImageData = inImageWrapper.data;
  final outImageData = outImageWrapper.data;
  final height = inImageWrapper.size.y;
  final width = inImageWrapper.size.x;

  for (var v = 1; v < height - 1; v++) {
    for (var u = 1; u < width - 1; u++) {
      final yStart1 = v - 1;
      final yStart2 = v + 1;
      final xStart1 = u - 1;
      final xStart2 = u + 1;
      final sum = inImageData[yStart1 * width + xStart1] +
          inImageData[yStart1 * width + xStart2] +
          inImageData[v * width + u] +
          inImageData[yStart2 * width + xStart1] +
          inImageData[yStart2 * width + xStart2];
      outImageData[v * width + u] = sum == 5 ? 1 : 0;
    }
  }
}

void subtract(ImageWrapper aImageWrapper, ImageWrapper bImageWrapper,
    ImageWrapper resultImageWrapper) {
  if (resultImageWrapper == null) {
    // eslint-disable-next-line no-param-reassign
    resultImageWrapper = aImageWrapper;
  }
  var length = aImageWrapper.data.length;
  final aImageData = aImageWrapper.data;
  final bImageData = bImageWrapper.data;
  final cImageData = resultImageWrapper.data;

  while ((length--) != 0) {
    cImageData[length] = aImageData[length] - bImageData[length];
  }
}

void bitwiseOr(ImageWrapper aImageWrapper, ImageWrapper bImageWrapper,
    ImageWrapper resultImageWrapper) {
  if (resultImageWrapper == null) {
    // eslint-disable-next-line no-param-reassign
    resultImageWrapper = aImageWrapper;
  }
  var length = aImageWrapper.data.length;
  final aImageData = aImageWrapper.data;
  final bImageData = bImageWrapper.data;
  final cImageData = resultImageWrapper.data;

  while ((length--) != 0) {
    cImageData[length] = aImageData[length] | bImageData[length];
  }
}

int countNonZero(imageWrapper) {
  var length = imageWrapper.data.length;
  final data = imageWrapper.data;
  var sum = 0;

  while ((length--) != 0) {
    sum += data[length];
  }
  return sum;
}

class Hit {
  num score;
  Cluster2 item;

  Hit({this.score, this.item});
}

List<Hit> topGeneric(List<Cluster2> list, int top, ScoreFunction scoreFunc) {
  var minIdx = 0;
  var min = 0;
  final queue = <Hit>[];

  for (var i = 0; i < top; i++) {
    queue.add(Hit(score: 0, item: null));
  }

  for (var i = 0; i < list.length; i++) {
    final score = scoreFunc.call(list[i]);
    if (score > min) {
      final hit = queue[minIdx];
      hit.score = score;
      hit.item = list[i];
      min = 999999999999999999;
      for (var pos = 0; pos < top; pos++) {
        if (queue[pos].score < min) {
          min = queue[pos].score;
          minIdx = pos;
        }
      }
    }
  }

  return queue;
}

void grayAndHalfSampleFromCanvasData(canvasData, size, outArray) {
  var topRowIdx = 0;
  var bottomRowIdx = size.x;
  final endIdx = (canvasData.length / 4.0).floor();
  final outWidth = size.x / 2;
  var outImgIdx = 0;
  final inWidth = size.x;
  var i;

  while (bottomRowIdx < endIdx) {
    for (i = 0; i < outWidth; i++) {
      // eslint-disable-next-line no-param-reassign
      outArray[outImgIdx] = ((0.299 * canvasData[topRowIdx * 4 + 0] +
                  0.587 * canvasData[topRowIdx * 4 + 1] +
                  0.114 * canvasData[topRowIdx * 4 + 2]) +
              (0.299 * canvasData[(topRowIdx + 1) * 4 + 0] +
                  0.587 * canvasData[(topRowIdx + 1) * 4 + 1] +
                  0.114 * canvasData[(topRowIdx + 1) * 4 + 2]) +
              (0.299 * canvasData[(bottomRowIdx) * 4 + 0] +
                  0.587 * canvasData[(bottomRowIdx) * 4 + 1] +
                  0.114 * canvasData[(bottomRowIdx) * 4 + 2]) +
              (0.299 * canvasData[(bottomRowIdx + 1) * 4 + 0] +
                  0.587 * canvasData[(bottomRowIdx + 1) * 4 + 1] +
                  0.114 * canvasData[(bottomRowIdx + 1) * 4 + 2])) /
          4;
      outImgIdx++;
      topRowIdx += 2;
      bottomRowIdx += 2;
    }
    topRowIdx += inWidth;
    bottomRowIdx += inWidth;
  }
}

void computeGray(imageData, outArray, config) {
  final l = (imageData.length / 4.0);
  final singleChannel = config != null && config.singleChannel == true;

  if (singleChannel) {
    for (var i = 0; i < l; i++) {
      // eslint-disable-next-line no-param-reassign
      outArray[i] = imageData[i * 4 + 0];
    }
  } else {
    for (var i = 0; i < l; i++) {
      // eslint-disable-next-line no-param-reassign
      outArray[i] = 0.299 * imageData[i * 4 + 0] +
          0.587 * imageData[i * 4 + 1] +
          0.114 * imageData[i * 4 + 2];
    }
  }
}

void halfSample(ImageWrapper inImgWrapper, ImageWrapper outImgWrapper) {
  final inImg = inImgWrapper.data;
  final inWidth = inImgWrapper.size.x;
  final outImg = outImgWrapper.data;
  var topRowIdx = 0;
  var bottomRowIdx = inWidth;
  final endIdx = inImg.length;
  final outWidth = inWidth / 2;
  var outImgIdx = 0;
  while (bottomRowIdx < endIdx) {
    for (var i = 0; i < outWidth; i++) {
      // Check
      outImg[outImgIdx] = ((inImg[topRowIdx] +
                  inImg[topRowIdx + 1] +
                  inImg[bottomRowIdx] +
                  inImg[bottomRowIdx + 1]) /
              4.0)
          .floor();
      outImgIdx++;
      topRowIdx += 2;
      bottomRowIdx += 2;
    }
    topRowIdx += inWidth;
    bottomRowIdx += inWidth;
  }
}

List<int> hsv2rgb(List<int> hsv) {
  final h = hsv[0];
  final s = hsv[1];
  final v = hsv[2];
  final c = (v * s).toDouble();
  final x = c * (1 - ((h / 60.0) % 2 - 1).abs());
  final m = v - c;
  var r = 0.0;
  var g = 0.0;
  var b = 0.0;

  if (h < 60) {
    r = c;
    g = x;
  } else if (h < 120) {
    r = x;
    g = c;
  } else if (h < 180) {
    g = c;
    b = x;
  } else if (h < 240) {
    g = x;
    b = c;
  } else if (h < 300) {
    r = x;
    b = c;
  } else if (h < 360) {
    r = c;
    b = x;
  }
  final rgb = [0, 0, 0];
  // eslint-disable-next-line no-param-reassign
  rgb[0] = ((r + m) * 255).toInt();
  // eslint-disable-next-line no-param-reassign
  rgb[1] = ((g + m) * 255).toInt();
  // eslint-disable-next-line no-param-reassign
  rgb[2] = ((b + m) * 255).toInt();
  return rgb;
}

List<num> _computeDivisors(int n) {
  final largeDivisors = <num>[];
  final divisors = <num>[];

  for (var i = 1; i < math.sqrt(n) + 1; i++) {
    if (n % i == 0) {
      divisors.add(i);
      if (i != n / i) {
        largeDivisors.insert(0, (n / i).floor());
      }
    }
  }
  return [...divisors, ...largeDivisors];
}

dynamic _computeIntersection(List<num> arr1, List<num> arr2) {
  var i = 0;
  var j = 0;
  final result = [];

  while (i < arr1.length && j < arr2.length) {
    if (arr1[i] == arr2[j]) //===
    {
      result.add(arr1[i]);
      i++;
      j++;
    } else if (arr1[i] > arr2[j]) {
      j++;
    } else {
      i++;
    }
  }
  return result;
}

Point calculatePatchSize(String patchSize, Point imgSize) {
  final divisorsX = _computeDivisors(imgSize.x);
  final divisorsY = _computeDivisors(imgSize.y);
  final wideSide = max(imgSize.x, imgSize.y);
  final common = _computeIntersection(divisorsX, divisorsY);
  final nrOfPatchesList = [8, 10, 15, 20, 32, 60, 80];
  final nrOfPatchesMap = {
    'x-small': 5,
    'small': 4,
    'medium': 3,
    'large': 2,
    'x-large': 1,
  };
  final nrOfPatchesIdx = nrOfPatchesMap[patchSize] ?? nrOfPatchesMap['medium'];
  final nrOfPatches = nrOfPatchesList[nrOfPatchesIdx];
  final desiredPatchSize = (wideSide / nrOfPatches).floor();

  Point findPatchSizeForDivisors(List<num> divisors) {
    var i = 0;
    var found = divisors[(divisors.length / 2.0).floor()];

    while (i < (divisors.length - 1) && divisors[i] < desiredPatchSize) {
      i++;
    }
    if (i > 0) {
      if ((divisors[i] - desiredPatchSize).abs() >
          (divisors[i - 1] - desiredPatchSize).abs()) {
        found = divisors[i - 1];
      } else {
        found = divisors[i];
      }
    }
    if (desiredPatchSize / found <
            nrOfPatchesList[nrOfPatchesIdx + 1] /
                nrOfPatchesList[nrOfPatchesIdx] &&
        desiredPatchSize / found >
            nrOfPatchesList[nrOfPatchesIdx - 1] /
                nrOfPatchesList[nrOfPatchesIdx]) {
      return Point(x: found, y: found);
    }
    return null;
  }

  var optimalPatchSize = findPatchSizeForDivisors(common);
  if (optimalPatchSize == null) {
    optimalPatchSize = findPatchSizeForDivisors(_computeDivisors(wideSide));
    if (optimalPatchSize == null) {
      optimalPatchSize = findPatchSizeForDivisors(
          (_computeDivisors(desiredPatchSize * nrOfPatches)));
    }
  }
  return optimalPatchSize;
}

// export function _parseCSSDimensionValues(value) {
//     final dimension = {
//         value: parseFloat(value),
//         unit: value.indexOf('%') === value.length - 1 ? '%' : '%',
//     };

//     return dimension;
// }

// export final _dimensionsConverters = {
//     top(dimension, context) {
//         return dimension.unit === '%' ? Math.floor(context.height * (dimension.value / 100)) : null;
//     },
//     right(dimension, context) {
//         return dimension.unit === '%' ? Math.floor(context.width - (context.width * (dimension.value / 100))) : null;
//     },
//     bottom(dimension, context) {
//         return dimension.unit === '%' ? Math.floor(context.height - (context.height * (dimension.value / 100))) : null;
//     },
//     left(dimension, context) {
//         return dimension.unit === '%' ? Math.floor(context.width * (dimension.value / 100)) : null;
//     },
// };

// function computeImageArea(inputWidth, inputHeight, area) {
//     final context = { width: inputWidth, height: inputHeight };

//     final parsedArea = Object.keys(area).reduce((result, key) => {
//         final value = area[key];
//         final parsed = _parseCSSDimensionValues(value);
//         final calculated = _dimensionsConverters[key](parsed, context);

//         // eslint-disable-next-line no-param-reassign
//         result[key] = calculated;
//         return result;
//     }, {});

//     return {
//         sx: parsedArea.left,
//         sy: parsedArea.top,
//         sw: parsedArea.right - parsedArea.left,
//         sh: parsedArea.bottom - parsedArea.top,
//     };
// }
