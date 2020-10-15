import 'dart:math';

import 'package:vector_math/vector_math_64.dart';
import 'package:zebra/src/common/sub_image.dart';
import 'package:zebra/src/types.dart';

class IndexMapping {
  final x = <int, int>{};
  final y = <int, int>{};
}

class Moment {
  double m00;
  double m01;
  double m10;
  double m11;
  double m02;
  double m20;
  double theta;
  double rad;
  Vector2 vec;

  Moment({
    this.m00,
    this.m01,
    this.m10,
    this.m11,
    this.m02,
    this.m20,
    this.theta,
    this.rad,
    this.vec,
  });
}

class ImageWrapper {
  List<int> data;
  Point size;

  IndexMapping indexMapping;

/**
 * Represents a basic image combining the data and size.
 * In addition, some methods for manipulation are contained.
 * @param size {x,y} The size of the image in pixel
 * @param data {Array} If given, a flat array containing the pixel data
 * @param ArrayType {Type} If given, the desired DataType of the Array (may be typed/non-typed)
 * @param initialize {Boolean} Indicating if the array should be initialized on creation.
 * @returns {ImageWrapper}
 */
  ImageWrapper(this.size) : this.data = List<int>(size.x * size.y);

  ImageWrapper.fromData(this.size, this.data);

/**
 * tests if a position is within the image with a given offset
 * @param imgRef {x, y} The location to test
 * @param border Number the padding value in pixel
 * @returns {Boolean} true if location inside the image's border, false otherwise
 * @see cvd/image.h
 */
  bool inImageWithBorder(ImageReference imgRef, int border) {
    return (imgRef.x >= border) &&
        (imgRef.y >= border) &&
        (imgRef.x < (this.size.x - border)) &&
        (imgRef.y < (this.size.y - border));
  }

/**
 * Performs bilinear sampling
 * @param inImg Image to extract sample from
 * @param x the x-coordinate
 * @param y the y-coordinate
 * @returns the sampled value
 * @see cvd/vision.h
 */
  int sample(ImageWrapper inImg, int x, int y) {
    var lx = x.floor();
    var ly = y.floor();
    var w = inImg.size.x;
    var base = ly * inImg.size.x + lx;
    var a = inImg.data[base + 0];
    var b = inImg.data[base + 1];
    var c = inImg.data[base + w];
    var d = inImg.data[base + w + 1];
    var e = a - b;
    x -= lx;
    y -= ly;

    var result = (x * (y * (e - c + d) - e) + y * (c - a) + a).floor();
    return result;
  }

/**
 * Initializes a given array. Sets each element to zero.
 * @param array {Array} The array to initialize
 */
  void clearArray(List<num> array) {
    var l = array.length;
    while ((l--) > 0) {
      array[l] = 0;
    }
  }

/**
 * Creates a {SubImage} from the current image ({this}).
 * @param from {ImageRef} The position where to start the {SubImage} from. (top-left corner)
 * @param size {ImageRef} The size of the resulting image
 * @returns {SubImage} A shared part of the original image
 */
  SubImage subImage(from, size) {
    return SubImage(from, size, this);
  }

/**
 * Creates an {ImageWrapper) and copies the needed underlying image-data area
 * @param imageWrapper {ImageWrapper} The target {ImageWrapper} where the data should be copied
 * @param from {ImageRef} The location where to copy from (top-left location)
 */
  void subImageAsCopy(ImageWrapper imageWrapper, from) {
    final sizeY = imageWrapper.size.y;
    final sizeX = imageWrapper.size.x;

    for (var x = 0; x < sizeX; x++) {
      for (var y = 0; y < sizeY; y++) {
        imageWrapper.data[y * sizeX + x] =
            this.data[(from.y + y) * this.size.x + from.x + x];
      }
    }
  }

  void copyTo(ImageWrapper imageWrapper) {
    var length = this.data.length,
        srcData = this.data,
        dstData = imageWrapper.data;

    while ((length--) > 0) {
      dstData[length] = srcData[length];
    }
  }

/**
 * Retrieves a given pixel position from the image
 * @param x {Number} The x-position
 * @param y {Number} The y-position
 * @returns {Number} The grayscale value at the pixel-position
 */
  int get(x, y) {
    return this.data[y * this.size.x + x];
  }

/**
 * Retrieves a given pixel position from the image
 * @param x {Number} The x-position
 * @param y {Number} The y-position
 * @returns {Number} The grayscale value at the pixel-position
 */
  int getSafe(int x, int y) {
    if (this.indexMapping == null) {
      this.indexMapping = IndexMapping();
      for (var i = 0; i < this.size.x; i++) {
        this.indexMapping.x[i] = i;
        this.indexMapping.x[i + this.size.x] = i;
      }
      for (var i = 0; i < this.size.y; i++) {
        this.indexMapping.y[i] = i;
        this.indexMapping.y[i + this.size.y] = i;
      }
    }
    return this.data[(this.indexMapping.y[y + this.size.y]) * this.size.x +
        this.indexMapping.x[x + this.size.x]];
  }

/**
 * Sets a given pixel position in the image
 * @param x {Number} The x-position
 * @param y {Number} The y-position
 * @param value {Number} The grayscale value to set
 * @returns {ImageWrapper} The Image itself (for possible chaining)
 */
  ImageWrapper set(int x, int y, int value) {
    this.data[y * this.size.x + x] = value;
    return this;
  }

/**
 * Sets the border of the image (1 pixel) to zero
 */
  void zeroBorder() {
    final width = this.size.x;
    final height = this.size.y;
    final data = this.data;

    for (var i = 0; i < width; i++) {
      data[i] = data[(height - 1) * width + i] = 0;
    }
    for (var i = 1; i < height - 1; i++) {
      data[i * width] = data[i * width + (width - 1)] = 0;
    }
  }

/**
 * Inverts a binary image in place
 */
  void invert() {
    final data = this.data;
    var length = data.length;

    while ((length--) > 0) {
      data[length] = data[length] != 0 ? 0 : 1;
    }
  }

  void convolve(List<List<num>> kernel) {
    var kSize = (kernel.length ~/ 2);

    for (var y = 0; y < this.size.y; y++) {
      for (var x = 0; x < this.size.x; x++) {
        var accu = 0;
        for (var ky = -kSize; ky <= kSize; ky++) {
          for (var kx = -kSize; kx <= kSize; kx++) {
            accu +=
                kernel[ky + kSize][kx + kSize] * this.getSafe(x + kx, y + ky);
          }
        }
        this.data[y * this.size.x + x] = accu;
      }
    }
  }

  List<Moment> moments(int labelcount) {
    var data = this.data,
        height = this.size.y,
        width = this.size.x,
        val,
        mu11,
        mu02,
        mu20,
        x_,
        y_,
        tmp,
        PI = pi,
        PI_4 = pi / 4;

    if (labelcount <= 0) {
      return [];
    }

    final result = <Moment>[];
    final labelsum = List<Moment>(labelcount);

    for (var i = 0; i < labelcount; i++) {
      var moment = Moment(
          m00: 0, m01: 0, m10: 0, m11: 0, m02: 0, m20: 0, theta: 0, rad: 0);
      labelsum[i] = moment;
    }

    for (var y = 0; y < height; y++) {
      final ysq = y * y;
      for (var x = 0; x < width; x++) {
        val = data[y * width + x];
        if (val > 0) {
          final label = labelsum[val - 1];
          label.m00 += 1;
          label.m01 += y;
          label.m10 += x;
          label.m11 += x * y;
          label.m02 += ysq;
          label.m20 += x * x;
        }
      }
    }

    for (var i = 0; i < labelcount; i++) {
      final label = labelsum[i];
      if (!label.m00.isNaN && label.m00 != 0) {
        x_ = label.m10 / label.m00;
        y_ = label.m01 / label.m00;
        mu11 = label.m11 / label.m00 - x_ * y_;
        mu02 = label.m02 / label.m00 - y_ * y_;
        mu20 = label.m20 / label.m00 - x_ * x_;
        tmp = (mu02 - mu20) / (2 * mu11);
        tmp = 0.5 * atan(tmp) + (mu11 >= 0 ? PI_4 : -PI_4) + PI;
        label.theta = (tmp * 180 / PI + 90) % 180 - 90;
        if (label.theta < 0) {
          label.theta += 180;
        }
        label.rad = tmp > pi ? tmp - pi : tmp;
        label.vec = Vector2(cos(tmp), sin(tmp));
        result.add(label);
      }
    }

    return result;
  }

  // Displays the {ImageWrapper} in a given canvas
  // void show(canvas, num scale) {
  //   var ctx, frame, data, current, pixel, x, y;

  //   if (!scale) {
  //     scale = 1.0;
  //   }
  //   ctx = canvas.getContext('2d');
  //   canvas.width = this.size.x;
  //   canvas.height = this.size.y;
  //   frame = ctx.getImageData(0, 0, canvas.width, canvas.height);
  //   data = frame.data;
  //   current = 0;
  //   for (y = 0; y < this.size.y; y++) {
  //     for (x = 0; x < this.size.x; x++) {
  //       pixel = y * this.size.x + x;
  //       current = this.get(x, y) * scale;
  //       data[pixel * 4 + 0] = current;
  //       data[pixel * 4 + 1] = current;
  //       data[pixel * 4 + 2] = current;
  //       data[pixel * 4 + 3] = 255;
  //     }
  //   }
  //   //frame.data = data;
  //   ctx.putImageData(frame, 0, 0);
  // }

  // Displays the {SubImage} in a given canvas
  // @param canvas {Canvas} The canvas element to write to
  // @param scale {Number} Scale which is applied to each pixel-value

  // void overlay(canvas, scale, from) {
  //   if (!scale || scale < 0 || scale > 360) {
  //     scale = 360;
  //   }
  //   var hsv = [0, 1, 1];
  //   var whiteRgb = [255, 255, 255];
  //   var blackRgb = [0, 0, 0];
  //   var result = [];
  //   var ctx = canvas.getContext('2d');
  //   var frame = ctx.getImageData(from.x, from.y, this.size.x, this.size.y);
  //   var data = frame.data;
  //   var length = this.data.length;
  //   while ((length--) > 0) {
  //     hsv[0] = this.data[length] * scale;
  //     result = hsv[0] <= 0
  //         ? whiteRgb
  //         : hsv[0] >= 360
  //             ? blackRgb
  //             : hsv2rgb(hsv);
  //     data[length * 4 + 0] = result[0];
  //     data[length * 4 + 1] = result[1];
  //     data[length * 4 + 2] = result[2];
  //     data[length * 4 + 3] = 255;
  //   }
  //   ctx.putImageData(frame, from.x, from.y);
  // }
}
