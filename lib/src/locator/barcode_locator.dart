import 'dart:math';
import 'dart:typed_data';

import 'package:zebra/src/common/cluster.dart';
import 'package:zebra/src/common/cv_utils.dart';
import 'package:zebra/src/common/image_wrapper.dart';
import 'package:zebra/src/locator/rasterizer.dart';
import 'package:zebra/src/locator/skeletonizer.dart';
import 'package:zebra/src/locator/tracer.dart' as tr;
import 'package:zebra/src/types.dart';
import 'package:vector_math/vector_math_64.dart';

void init<T>(List<T> arr, T val) {
  var l = arr.length;
  while ((l--) > 0) {
    arr[l] = val;
  }
}

class Patch {
  int index;
  Point pos;
  Box box;
  dynamic moments;
  dynamic rad;
  Vector2 vec;

  Patch({this.index, this.pos, this.box, this.moments, this.rad, this.vec});
}

class Box {
  List<Vector2> box;

  Box(this.box);
}

class IndexValue<T> {
  final int label;
  final T val;

  IndexValue({this.label, this.val});
}

const undefined = null;

class BarcodeLocator {
  final ImageWrapper _inputImageWrapper;
  final dynamic _config;

  ImageWrapper _currentImageWrapper;
  Point _patchSize;
  Point _numPatches;
  ImageWrapper _binaryImageWrapper;
  ImageWrapper _subImageWrapper;
  ImageWrapper _skelImageWrapper;
  Skeletonizer _skeletonizer;
  List<Patch> _imageToPatchGrid;
  ImageWrapper _patchGrid;
  ImageWrapper _patchLabelGrid;
  ImageWrapper _labelImageWrapper;

  BarcodeLocator(ImageWrapper inputImageWrapper, dynamic config)
      : _inputImageWrapper = inputImageWrapper,
        _config = config {
    initBuffers();
  }

  void initBuffers() {
    if (_config.halfSample) {
      _currentImageWrapper = ImageWrapper(
        Point(
            x: _inputImageWrapper.size.x ~/ 2 | 0,
            y: _inputImageWrapper.size.y ~/ 2 | 0),
      );
    } else {
      _currentImageWrapper = _inputImageWrapper;
    }

    _patchSize =
        calculatePatchSize(_config.patchSize, _currentImageWrapper.size);

    _numPatches = Point();
    _numPatches.x = _currentImageWrapper.size.x ~/ _patchSize.x;
    _numPatches.y = _currentImageWrapper.size.y ~/ _patchSize.y;

    _binaryImageWrapper = ImageWrapper(_currentImageWrapper.size);

    _labelImageWrapper = ImageWrapper(_patchSize);

    final skeletonImageData = Uint8List(64 * 1024);
    _subImageWrapper = ImageWrapper(_patchSize);
    _skelImageWrapper = ImageWrapper(_patchSize);
    _skeletonizer = Skeletonizer({'size': _patchSize.x}, skeletonImageData);

    final gx = _currentImageWrapper.size.x ~/ _subImageWrapper.size.x;
    final gy = _currentImageWrapper.size.y ~/ _subImageWrapper.size.y;
    _imageToPatchGrid = List<Patch>(gx * gy);

    final gs = Point(x: gx, y: gy);

    _patchGrid = ImageWrapper(gs);
    _patchLabelGrid = ImageWrapper(gs);
  }

  /// Creates a bounding box which encloses all the given patches.
  Box boxFromPatches(List<Patch> patches) {
    double minx = _binaryImageWrapper.size.x.toDouble();
    double miny = _binaryImageWrapper.size.y.toDouble();
    double maxx = -_binaryImageWrapper.size.x.toDouble();
    double maxy = -_binaryImageWrapper.size.y.toDouble();

    // draw all patches which are to be taken into consideration
    double overAvg = 0;
    for (var i = 0; i < patches.length; i++) {
      final patch = patches[i];
      overAvg += patch.rad;
      // if (ENV.development && _config.debug.showPatches) {
      //     ImageDebug.drawRect(patch.pos, _subImageWrapper.size, _canvasContainer.ctx.binary, {color: "red"});
      // }
    }

    overAvg /= patches.length;
    overAvg = (overAvg * 180 / pi + 90) % 180 - 90;
    if (overAvg < 0) {
      overAvg += 180;
    }

    overAvg = (180 - overAvg) * pi / 180;
    final transMat =
        Matrix2(cos(overAvg), sin(overAvg), -sin(overAvg), cos(overAvg));

    // iterate over patches and rotate by angle
    for (var i = 0; i < patches.length; i++) {
      final patch = patches[i];
      for (var j = 0; j < 4; j++) {
        patch.box.box[j] = transMat.transform(patch.box.box[j]);
      }

      // if (ENV.development && _config.debug.boxFromPatches.showTransformed) {
      //     ImageDebug.drawPath(patch.box, {x: 0, y: 1}, _canvasContainer.ctx.binary, {color: '#99ff00', lineWidth: 2});
      // }
    }

    // find bounding box
    for (var i = 0; i < patches.length; i++) {
      final patch = patches[i];
      for (var j = 0; j < 4; j++) {
        if (patch.box.box[j][0] < minx) {
          minx = patch.box.box[j][0];
        }
        if (patch.box.box[j][0] > maxx) {
          maxx = patch.box.box[j][0];
        }
        if (patch.box.box[j][1] < miny) {
          miny = patch.box.box[j][1];
        }
        if (patch.box.box[j][1] > maxy) {
          maxy = patch.box.box[j][1];
        }
      }
    }

    final box = [
      Vector2(minx, miny),
      Vector2(maxx, miny),
      Vector2(maxx, maxy),
      Vector2(minx, maxy),
    ];

    // if (ENV.development && _config.debug.boxFromPatches.showTransformedBox) {
    //     ImageDebug.drawPath(box, {x: 0, y: 1}, _canvasContainer.ctx.binary, {color: '#ff0000', lineWidth: 2});
    // }

    Matrix2 invert(Matrix2 a) {
      var a0 = a[0];
      var a1 = a[1];
      var a2 = a[2];
      var a3 = a[3];
      var det = a0 * a3 - a2 * a1;

      if (det == 0) return null;
      det = 1.0 / det;

      final out = Matrix2(0, 0, 0, 0);
      out[0] = a3 * det;
      out[1] = -a1 * det;
      out[2] = -a2 * det;
      out[3] = a0 * det;

      return out;
    }

    final scale = _config.halfSample ? 2 : 1;
    // reverse rotation;
    final itransMat = invert(transMat);
    for (var j = 0; j < 4; j++) {
      box[j] = itransMat.transform(box[j]);
    }

    // if (ENV.development && _config.debug.boxFromPatches.showBB) {
    //     ImageDebug.drawPath(box, {x: 0, y: 1}, _canvasContainer.ctx.binary, {color: '#ff0000', lineWidth: 2});
    // }

    for (var j = 0; j < 4; j++) {
      box[j] = box[j] * scale.toDouble();
    }

    return Box(box);
  }

  /// Creates a binary image of the current image

  void binarizeImage() {
    otsuThreshold(_currentImageWrapper, _binaryImageWrapper);
    _binaryImageWrapper.zeroBorder();
    // if (ENV.development && _config.debug.showCanvas) {
    //     _binaryImageWrapper.show(_canvasContainer.dom.binary, 255);
    // }
  }

  /// Iterate over the entire image extract patches
  List<Patch> findPatches() {
    final patchesFound = <Patch>[];

    for (var i = 0; i < _numPatches.x; i++) {
      for (var j = 0; j < _numPatches.y; j++) {
        final x = _subImageWrapper.size.x * i;
        final y = _subImageWrapper.size.y * j;

        // seperate parts
        skeletonize(x, y);

        // Rasterize, find individual bars
        _skelImageWrapper.zeroBorder();
        init(_labelImageWrapper.data, 0);
        final rasterizer = Rasterizer(_skelImageWrapper, _labelImageWrapper);
        final rasterResult = rasterizer.rasterize(0);

        // if (ENV.development && _config.debug.showLabels) {
        //     _labelImageWrapper.overlay(_canvasContainer.dom.binary, floor(360 / rasterResult.count),
        //         {x: x, y: y});
        // }

        // calculate moments from the skeletonized patch
        final moments = _labelImageWrapper.moments(rasterResult.count);

        // extract eligible patches
        patchesFound
            .addAll(describePatch(moments, [i, j], x.toDouble(), y.toDouble()));
      }
    }

    // if (ENV.development && _config.debug.showFoundPatches) {
    //     for ( i = 0; i < patchesFound.length; i++) {
    //         patch = patchesFound[i];
    //         ImageDebug.drawRect(patch.pos, _subImageWrapper.size, _canvasContainer.ctx.binary,
    //             {color: "#99ff00", lineWidth: 2});
    //     }
    // }

    return patchesFound;
  }

  /// Finds those connected areas which contain at least 6 patches
  /// and returns them ordered DESC by the number of contained patches
  List<IndexValue<int>> findBiggestConnectedAreas(int maxLabel) {
    var labelHist = <int>[];

    for (var i = 0; i < maxLabel; i++) {
      labelHist.add(0);
    }
    var sum = _patchLabelGrid.data.length;
    while ((sum--) != 0) {
      if (_patchLabelGrid.data[sum] > 0) {
        labelHist[_patchLabelGrid.data[sum] - 1]++;
      }
    }

    int idx = 0;
    final labelHist0 = labelHist.map((val) {
      return IndexValue(val: val, label: ++idx);
    }).toList();

    labelHist0.sort((a, b) {
      return b.val - a.val;
    });

    // extract top areas with at least 6 patches present
    final topLabels = labelHist0.where((el) {
      return el.val >= 5;
    });

    return topLabels.toList();
  }

  List<Box> findBoxes(List<IndexValue<int>> topLabels, int maxLabel) {
    var boxes = <Box>[];

    for (var i = 0; i < topLabels.length; i++) {
      var sum = _patchLabelGrid.data.length;
      final patches = <Patch>[];
      while ((sum--) > 0) {
        if (_patchLabelGrid.data[sum] == topLabels[i].label) {
          final patch = _imageToPatchGrid[sum];
          patches.add(patch);
        }
      }

      final box = boxFromPatches(patches);
      if (box != null) {
        boxes.add(box);

        // draw patch-labels if requested
        // if (ENV.development && _config.debug.showRemainingPatchLabels) {
        //     for ( j = 0; j < patches.length; j++) {
        //         patch = patches[j];
        //         hsv[0] = (topLabels[i].label / (maxLabel + 1)) * 360;
        //         hsv2rgb(hsv, rgb);
        //         ImageDebug.drawRect(patch.pos, _subImageWrapper.size, _canvasContainer.ctx.binary,
        //             {color: "rgb(" + rgb.join(",") + ")", lineWidth: 2});
        //     }
        // }
      }
    }
    return boxes;
  }

  /// Find similar moments (via cluster)
  List<MomentPoint> similarMoments(List<Moment> moments) {
    var clusters = cluster(moments, 0.90);
    var topCluster = topGeneric(clusters, 1, (e) {
      return e.getPoints().length;
    });
    var result = <MomentPoint>[];
    if (topCluster.length == 1) {
      final points = topCluster[0].item.getPoints();
      for (var i = 0; i < points.length; i++) {
        result.add(points[i]);
      }
    }
    return result;
  }

  void skeletonize(x, y) {
    _binaryImageWrapper.subImageAsCopy(_subImageWrapper, imageRef(x, y));
    _skeletonizer.skeletonize();

    // Show skeleton if requested
    // if (ENV.development && _config.debug.showSkeleton) {
    //     _skelImageWrapper.overlay(_canvasContainer.dom.binary, 360, imageRef(x, y));
    // }
  }

  /// Extracts and describes those patches which seem to contain a barcode pattern
  List<Patch> describePatch(
      List<Moment> moments, List<int> patchPos, double x, double y) {
    final patchesFound = <Patch>[];
    final minComponentWeight = (_patchSize.x / 3).ceil();

    final eligibleMoments = <Moment>[];
    if (moments.length >= 2) {
      // only collect moments which's area covers at least minComponentWeight pixels.
      for (var k = 0; k < moments.length; k++) {
        if (moments[k].m00 > minComponentWeight) {
          eligibleMoments.add(moments[k]);
        }
      }

      // if at least 2 moments are found which have at least minComponentWeights covered
      if (eligibleMoments.length >= 2) {
        final matchingMoments = similarMoments(eligibleMoments);
        var avg = 0.0;
        // determine the similarity of the moments
        for (var k = 0; k < matchingMoments.length; k++) {
          avg += matchingMoments[k].rad;
        }

        // Only two of the moments are allowed not to fit into the equation
        // add the patch to the set
        if (matchingMoments.length > 1 &&
            matchingMoments.length >= (eligibleMoments.length / 4) * 3 &&
            matchingMoments.length > moments.length / 4) {
          avg /= matchingMoments.length;
          final patch = Patch(
              index: patchPos[1] * _numPatches.x + patchPos[0],
              pos: Point(x: x.toInt(), y: y.toInt()),
              box: Box([
                Vector2(x, y),
                Vector2(x + _subImageWrapper.size.x, y),
                Vector2(
                    x + _subImageWrapper.size.x, y + _subImageWrapper.size.y),
                Vector2(x, y + _subImageWrapper.size.y)
              ]),
              moments: matchingMoments,
              rad: avg,
              vec: Vector2(cos(avg), sin(avg)));
          patchesFound.add(patch);
        }
      }
    }
    return patchesFound;
  }

  /// finds patches which are connected and share the same orientation
  int rasterizeAngularSimilarity(List<Patch> patchesFound) {
    var currIdx = 0;

    final threshold = 0.95;
    int label = 0;
    int notYetProcessed() {
      for (var i = 0; i < _patchLabelGrid.data.length; i++) {
        if (_patchLabelGrid.data[i] == 0 && _patchGrid.data[i] == 1) {
          return i;
        }
      }

      return _patchLabelGrid.data.length;
    }

    void trace(int currentIdx) {
      final current = Point(
          x: currentIdx % _patchLabelGrid.size.x,
          y: (currentIdx ~/ _patchLabelGrid.size.x) | 0);

      if (currentIdx < _patchLabelGrid.data.length) {
        final currentPatch = _imageToPatchGrid[currentIdx];
        // assign label
        _patchLabelGrid.data[currentIdx] = label;
        for (var dir = 0; dir < tr.Tracer.searchDirections.length; dir++) {
          final y = current.y + tr.Tracer.searchDirections[dir][0];
          final x = current.x + tr.Tracer.searchDirections[dir][1];
          final idx = y * _patchLabelGrid.size.x + x;

          // continue if patch empty
          if (_patchGrid.data[idx] == 0) {
            _patchLabelGrid.data[idx] = 999999999999999999;
            continue;
          }

          if (_patchLabelGrid.data[idx] == 0) {
            final similarity =
                _imageToPatchGrid[idx].vec.dot(currentPatch.vec).abs();
            if (similarity > threshold) {
              trace(idx);
            }
          }
        }
      }
    }

    // prepare for finding the right patches
    init(_patchGrid.data, 0);
    init(_patchLabelGrid.data, 0);
    init(_imageToPatchGrid, null);

    for (var j = 0; j < patchesFound.length; j++) {
      final patch = patchesFound[j];
      _imageToPatchGrid[patch.index] = patch;
      _patchGrid.data[patch.index] = 1;
    }

    // rasterize the patches found to determine area
    _patchGrid.zeroBorder();

    while ((currIdx = notYetProcessed()) < _patchLabelGrid.data.length) {
      label++;
      trace(currIdx);
    }

    // draw patch-labels if requested
    // if (ENV.development && _config.debug.showPatchLabels) {
    //     for ( j = 0; j < _patchLabelGrid.data.length; j++) {
    //         if (_patchLabelGrid.data[j] > 0 && _patchLabelGrid.data[j] <= label) {
    //             patch = _imageToPatchGrid.data[j];
    //             hsv[0] = (_patchLabelGrid.data[j] / (label + 1)) * 360;
    //             hsv2rgb(hsv, rgb);
    //             ImageDebug.drawRect(patch.pos, _subImageWrapper.size, _canvasContainer.ctx.binary,
    //                 {color: "rgb(" + rgb.join(",") + ")", lineWidth: 2});
    //         }
    //     }
    // }

    return label;
  }

  List<Box> locate() {
    if (_config.halfSample) {
      halfSample(_inputImageWrapper, _currentImageWrapper);
    }

    binarizeImage();
    final patchesFound = findPatches();
    // return unless 5% or more patches are found
    if (patchesFound.length < _numPatches.x * _numPatches.y * 0.05) {
      return null;
    }

    // rasterrize area by comparing angular similarity;
    var maxLabel = rasterizeAngularSimilarity(patchesFound);
    if (maxLabel < 1) {
      return null;
    }

    // search for area with the most patches (biggest connected area)
    final topLabels = findBiggestConnectedAreas(maxLabel);
    if (topLabels.length == 0) {
      return null;
    }

    final boxes = findBoxes(topLabels, maxLabel);
    return boxes;
  }

  bool checkImageConstraints(inputStream, config) {
    var width = inputStream.getWidth(),
        height = inputStream.getHeight(),
        halfSample = config.halfSample ? 0.5 : 1;

    // calculate width and height based on area
    // if (inputStream.getConfig().area) {
    //   final area =
    //       computeImageArea(width, height, inputStream.getConfig().area);
    //   // inputStream.setTopRight({x: area.sx, y: area.sy});
    //   // inputStream.setCanvasSize({x: width, y: height});
    //   width = area.sw;
    //   height = area.sh;
    // }

    final size = Point(
        x: (width * halfSample).floor(), y: (height * halfSample).floor());

    final patchSize = calculatePatchSize(config.patchSize, size);
    // if (ENV.development) {
    //     console.log("Patch-Size: " + JSON.stringify(patchSize));
    // }

    inputStream.setWidth(
        ((size.x / patchSize.x).floor() * (1 / halfSample) * patchSize.x)
            .floor());
    inputStream.setHeight(
        ((size.y / patchSize.y).floor() * (1 / halfSample) * patchSize.y)
            .floor());

    if ((inputStream.getWidth() % patchSize.x) == 0 &&
        (inputStream.getHeight() % patchSize.y) == 0) {
      return true;
    }

    throw ("Image dimensions do not comply with the current settings: Width ($width) and height ($height) must a multiple of ${patchSize.x}");
  }
}
