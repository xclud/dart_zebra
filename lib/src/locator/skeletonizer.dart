import 'dart:typed_data';

class Skeletonizer {
  Uint8List images;
  int size;

  int imul(int a, int b) {
    return a * b;
  }

  Skeletonizer(dynamic foreign, Uint8List buffer)
      : size = foreign.size,
        images = buffer;

  void erode(int inImagePtr, int outImagePtr) {
    inImagePtr = inImagePtr | 0;
    outImagePtr = outImagePtr | 0;

    var v = 0,
        u = 0,
        sum = 0,
        yStart1 = 0,
        yStart2 = 0,
        xStart1 = 0,
        xStart2 = 0,
        offset = 0;

    for (v = 1; (v | 0) < ((size - 1) | 0); v = (v + 1) | 0) {
      offset = (offset + size) | 0;
      for (u = 1; (u | 0) < ((size - 1) | 0); u = (u + 1) | 0) {
        yStart1 = (offset - size) | 0;
        yStart2 = (offset + size) | 0;
        xStart1 = (u - 1) | 0;
        xStart2 = (u + 1) | 0;
        sum = ((images[(inImagePtr + yStart1 + xStart1) | 0] | 0) +
                (images[(inImagePtr + yStart1 + xStart2) | 0] | 0) +
                (images[(inImagePtr + offset + u) | 0] | 0) +
                (images[(inImagePtr + yStart2 + xStart1) | 0] | 0) +
                (images[(inImagePtr + yStart2 + xStart2) | 0] | 0)) |
            0;
        if ((sum | 0) == (5 | 0)) {
          images[(outImagePtr + offset + u) | 0] = 1;
        } else {
          images[(outImagePtr + offset + u) | 0] = 0;
        }
      }
    }
    return;
  }

  void subtract(int aImagePtr, int bImagePtr, int outImagePtr) {
    aImagePtr = aImagePtr | 0;
    bImagePtr = bImagePtr | 0;
    outImagePtr = outImagePtr | 0;

    var length = 0;

    length = imul(size, size) | 0;

    while ((length | 0) > 0) {
      length = (length - 1) | 0;
      images[(outImagePtr + length) | 0] =
          ((images[(aImagePtr + length) | 0] | 0) -
                  (images[(bImagePtr + length) | 0] | 0)) |
              0;
    }
  }

  void bitwiseOr(int aImagePtr, int bImagePtr, int outImagePtr) {
    aImagePtr = aImagePtr | 0;
    bImagePtr = bImagePtr | 0;
    outImagePtr = outImagePtr | 0;

    var length = 0;

    length = imul(size, size) | 0;

    while ((length | 0) > 0) {
      length = (length - 1) | 0;
      images[(outImagePtr + length) | 0] =
          ((images[(aImagePtr + length) | 0] | 0) |
                  (images[(bImagePtr + length) | 0] | 0)) |
              0;
    }
  }

  int countNonZero(int imagePtr) {
    imagePtr = imagePtr | 0;

    var sum = 0, length = 0;

    length = imul(size, size) | 0;

    while ((length | 0) > 0) {
      length = (length - 1) | 0;
      sum = ((sum | 0) + (images[(imagePtr + length) | 0] | 0)) | 0;
    }

    return (sum | 0);
  }

  void init(int imagePtr, int value) {
    imagePtr = imagePtr | 0;
    value = value | 0;

    var length = 0;

    length = imul(size, size) | 0;

    while ((length | 0) > 0) {
      length = (length - 1) | 0;
      images[(imagePtr + length) | 0] = value;
    }
  }

  void dilate(int inImagePtr, int outImagePtr) {
    inImagePtr = inImagePtr | 0;
    outImagePtr = outImagePtr | 0;

    var v = 0,
        u = 0,
        sum = 0,
        yStart1 = 0,
        yStart2 = 0,
        xStart1 = 0,
        xStart2 = 0,
        offset = 0;

    for (v = 1; (v | 0) < ((size - 1) | 0); v = (v + 1) | 0) {
      offset = (offset + size) | 0;
      for (u = 1; (u | 0) < ((size - 1) | 0); u = (u + 1) | 0) {
        yStart1 = (offset - size) | 0;
        yStart2 = (offset + size) | 0;
        xStart1 = (u - 1) | 0;
        xStart2 = (u + 1) | 0;
        sum = ((images[(inImagePtr + yStart1 + xStart1) | 0] | 0) +
                (images[(inImagePtr + yStart1 + xStart2) | 0] | 0) +
                (images[(inImagePtr + offset + u) | 0] | 0) +
                (images[(inImagePtr + yStart2 + xStart1) | 0] | 0) +
                (images[(inImagePtr + yStart2 + xStart2) | 0] | 0)) |
            0;
        if ((sum | 0) > (0 | 0)) {
          images[(outImagePtr + offset + u) | 0] = 1;
        } else {
          images[(outImagePtr + offset + u) | 0] = 0;
        }
      }
    }
    return;
  }

  void memcpy(int srcImagePtr, int dstImagePtr) {
    srcImagePtr = srcImagePtr | 0;
    dstImagePtr = dstImagePtr | 0;

    var length = 0;

    length = imul(size, size) | 0;

    while ((length | 0) > 0) {
      length = (length - 1) | 0;
      images[(dstImagePtr + length) | 0] =
          (images[(srcImagePtr + length) | 0] | 0);
    }
  }

  void zeroBorder(int imagePtr) {
    imagePtr = imagePtr | 0;

    var x = 0, y = 0;

    for (x = 0; (x | 0) < ((size - 1) | 0); x = (x + 1) | 0) {
      images[(imagePtr + x) | 0] = 0;
      images[(imagePtr + y) | 0] = 0;
      y = ((y + size) - 1) | 0;
      images[(imagePtr + y) | 0] = 0;
      y = (y + 1) | 0;
    }
    for (x = 0; (x | 0) < (size | 0); x = (x + 1) | 0) {
      images[(imagePtr + y) | 0] = 0;
      y = (y + 1) | 0;
    }
  }

  void skeletonize() {
    var subImagePtr = 0,
        erodedImagePtr = 0,
        tempImagePtr = 0,
        skelImagePtr = 0,
        sum = 0,
        done = false;

    erodedImagePtr = imul(size, size) | 0;
    tempImagePtr = (erodedImagePtr + erodedImagePtr) | 0;
    skelImagePtr = (tempImagePtr + erodedImagePtr) | 0;

    // init skel-image
    init(skelImagePtr, 0);
    zeroBorder(subImagePtr);

    do {
      erode(subImagePtr, erodedImagePtr);
      dilate(erodedImagePtr, tempImagePtr);
      subtract(subImagePtr, tempImagePtr, tempImagePtr);
      bitwiseOr(skelImagePtr, tempImagePtr, skelImagePtr);
      memcpy(erodedImagePtr, subImagePtr);
      sum = countNonZero(subImagePtr) | 0;
      done = ((sum | 0) == 0 | 0);
    } while (!done);
  }
}
