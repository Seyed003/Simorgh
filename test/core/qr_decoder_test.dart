import 'dart:typed_data';

import 'package:aghelan_ghiamat/core/utils/qr_decoder.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// Renders [text] as a QR code PNG with a quiet zone, [scale] px/module.
Uint8List _qrPng(String text, {int scale = 6, bool inverted = false}) {
  final matrix = Encoder.encode(text, ErrorCorrectionLevel.m).matrix!;
  const quiet = 4;
  final size = (matrix.width + quiet * 2) * scale;
  final image = img.Image(width: size, height: size);
  final dark = inverted ? img.ColorRgb8(255, 255, 255) : img.ColorRgb8(0, 0, 0);
  final light = inverted
      ? img.ColorRgb8(0, 0, 0)
      : img.ColorRgb8(255, 255, 255);
  img.fill(image, color: light);
  for (var y = 0; y < matrix.height; y++) {
    for (var x = 0; x < matrix.width; x++) {
      if (matrix.get(x, y) == 1) {
        img.fillRect(
          image,
          x1: (x + quiet) * scale,
          y1: (y + quiet) * scale,
          x2: (x + quiet + 1) * scale - 1,
          y2: (y + quiet + 1) * scale - 1,
          color: dark,
        );
      }
    }
  }
  return img.encodePng(image);
}

void main() {
  const link =
      'vless://b831381d-6324-4d53-ad4f-8cda48b30811@1.2.3.4:443?security=reality&sni=www.microsoft.com&pbk=SbVKOEMjK0sIlbwg4akyBg5mL5KZwwB-ed4eEE7YnRc#QR';

  test('decodes a PNG QR code', () {
    expect(QrDecoder.decodeImageBytes(_qrPng(link)), link);
  });

  test('decodes an inverted (light on dark) QR code', () {
    expect(QrDecoder.decodeImageBytes(_qrPng(link, inverted: true)), link);
  });

  test('decodes a luminance buffer with row padding', () {
    final image = img.decodePng(_qrPng(link, scale: 4))!;
    const padding = 16;
    final stride = image.width + padding;
    final luma = Uint8List(stride * image.height);
    for (final p in image) {
      luma[p.y * stride + p.x] = p.r.toInt();
    }
    expect(
      QrDecoder.decodeLuminance(
        luma,
        image.width,
        image.height,
        rowStride: stride,
      ),
      link,
    );
  });

  test('returns null when there is no QR code', () {
    final blank = img.Image(width: 64, height: 64);
    img.fill(blank, color: img.ColorRgb8(255, 255, 255));
    expect(QrDecoder.decodeImageBytes(img.encodePng(blank)), isNull);
    expect(QrDecoder.decodeImageBytes(Uint8List.fromList([1, 2, 3])), isNull);
  });
}
