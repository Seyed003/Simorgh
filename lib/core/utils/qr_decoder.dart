import 'dart:typed_data';

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Pure Dart QR decoding (zxing2), shared by the Android camera scanner and
/// the "import QR from image" action on every platform.
abstract final class QrDecoder {
  /// Decodes a QR code from an 8-bit luminance buffer (e.g. the Y plane of
  /// a camera frame). [rowStride] defaults to [width].
  static String? decodeLuminance(
    Uint8List luma,
    int width,
    int height, {
    int? rowStride,
  }) {
    final stride = rowStride ?? width;
    final Int8List data;
    if (stride == width) {
      data = Int8List.view(luma.buffer, luma.offsetInBytes, width * height);
    } else {
      data = Int8List(width * height);
      for (var y = 0; y < height; y++) {
        data.setRange(
          y * width,
          (y + 1) * width,
          Int8List.view(luma.buffer, luma.offsetInBytes + y * stride, width),
        );
      }
    }
    return _decode(_GreyLuminanceSource(data, width, height));
  }

  /// Larger images are refused before decoding: a small crafted file can
  /// claim a size that needs gigabytes of memory.
  static const maxImageBytes = 30 * 1024 * 1024;
  static const maxPixels = 50 * 1000 * 1000;

  /// Decodes a QR code from an encoded image file (PNG, JPEG, WebP, ...).
  static String? decodeImageBytes(Uint8List bytes) {
    if (bytes.length > maxImageBytes) return null;
    final img.Image? decoded;
    try {
      final info = img.findDecoderForData(bytes)?.startDecode(bytes);
      if (info == null || info.width * info.height > maxPixels) return null;
      decoded = img.decodeImage(bytes);
    } on Exception {
      return null;
    }
    if (decoded == null) return null;
    var image = decoded;
    // Huge photos are slow and gain nothing; QR modules stay several pixels
    // wide after downscaling.
    if (image.width > 1600 || image.height > 1600) {
      image = img.copyResize(
        image,
        width: image.width >= image.height ? 1600 : null,
        height: image.height > image.width ? 1600 : null,
      );
    }
    final luma = Int8List(image.width * image.height);
    var i = 0;
    for (final pixel in image) {
      // Composite transparent pixels on white so PNG QR codes decode.
      final a = pixel.aNormalized;
      final l = pixel.luminanceNormalized * a + (1 - a);
      luma[i++] = (l * 255).round();
    }
    return _decode(_GreyLuminanceSource(luma, image.width, image.height));
  }

  static String? _decode(LuminanceSource source) {
    final hints = DecodeHints()..put(DecodeHintType.tryHarder);
    for (final candidate in [source, source.invert()]) {
      try {
        final bitmap = BinaryBitmap(HybridBinarizer(candidate));
        return QRCodeReader().decode(bitmap, hints: hints).text;
      } on ReaderException {
        continue;
      } on ArgumentError {
        // zxing2 reports some malformed codes (an impossible version, a
        // broken bit stream) as errors rather than ReaderExceptions.
        continue;
      } on StateError {
        continue;
      } on FormatException {
        continue;
      }
    }
    return null;
  }
}

class _GreyLuminanceSource extends LuminanceSource {
  _GreyLuminanceSource(this._data, int width, int height)
    : super(width, height);

  final Int8List _data;

  @override
  Int8List getRow(int y, Int8List? row) {
    final result = (row == null || row.length < width) ? Int8List(width) : row;
    result.setRange(0, width, _data, y * width);
    return result;
  }

  @override
  Int8List getMatrix() => _data;
}
