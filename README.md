# zebra

Zebra is a barcode reader/scanner library for Flutter and Dart.

## Attention

> This is a WIP package and it does not implement any of the features
> listed.

## Supported platforms

* [x] Flutter Android
* [x]  Flutter iOS
* [x]  Flutter Web
* [x]  Flutter Desktop

## What is Zebra

Zebra is a barcode-scanner entirely written in Dart supporting real-time localization and decoding of various types of barcodes such as **EAN**, **CODE 128**, **CODE 39**, **EAN 8**, **UPC-A**, **UPC-C**, **I2of5**, **2of5**, **CODE 93** and **CODABAR**. The library is also capable of using flutter's `camera`plugin to get direct access to the user’s camera stream. Although the code relies on heavy image-processing even recent smartphones are capable of locating and decoding barcodes in real-time.


## Getting Started

In your `pubspec.yaml` file add:

```dart
dependencies:
  zebra: any
```
Then, in your code import:
```dart
import 'package:zebra/zebra.dart';
```