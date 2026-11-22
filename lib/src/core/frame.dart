// Dual-buffer PixelFrame (`color` + `light`) and RGBA composition.

import 'dart:math' as math;
import 'dart:typed_data';

class PixelFrame {
  final int w;
  final int h;
  int ox;
  int oy;
  final Uint32List color;
  final Uint32List light;

  PixelFrame(this.w, this.h, [this.ox = 0, this.oy = 0])
      : color = Uint32List(w * h),
        light = Uint32List(w * h);
}

PixelFrame createFrame(int w, int h, [int ox = 0, int oy = 0]) =>
    PixelFrame(w, h, ox, oy);

PixelFrame clearFrame(PixelFrame f) {
  f.color.fillRange(0, f.color.length, 0);
  f.light.fillRange(0, f.light.length, 0);
  return f;
}

@pragma('vm:prefer-inline')
int _toUint8Clamp(double v) {
  if (v <= 0.0) return 0;
  if (v >= 255.0) return 255;
  final f = v.floor();
  final d = v - f;
  if (d < 0.5) return f;
  if (d > 0.5) return f + 1;
  return f.isOdd ? f + 1 : f;
}

/// Color over a background, plus light, into RGBA bytes (`w * h * 4`).
/// Pass neither [bgColor] nor [bgBuffer] for transparency; light becomes color
/// with alpha (its brightest channel), reading as additive over dark scenes.
Uint8List composite(
  PixelFrame f,
  Uint8List out, {
  int? bgColor,
  Uint32List? bgBuffer,
  double lightK = 1.0,
}) {
  final n = f.w * f.h;
  final cBuf = f.color;
  final lBuf = f.light;
  final hasBg = bgColor != null || bgBuffer != null;
  final flatBg = bgColor ?? 0;

  for (var i = 0; i < n; i++) {
    final c = cBuf[i];
    final l = lBuf[i] & 0xffffff;
    var r = 0.0;
    var g = 0.0;
    var b = 0.0;
    var a = 0.0;
    final ca = c >>> 24;

    if (ca == 255) {
      r = (c & 255).toDouble();
      g = ((c >>> 8) & 255).toDouble();
      b = ((c >>> 16) & 255).toDouble();
      a = 255.0;
    } else if (!hasBg) {
      r = (c & 255).toDouble();
      g = ((c >>> 8) & 255).toDouble();
      b = ((c >>> 16) & 255).toDouble();
      a = ca.toDouble();
    } else {
      final k = bgBuffer != null ? bgBuffer[i] : flatBg;
      final frac = ca / 255.0;
      r = (c & 255) * frac + (k & 255) * (1.0 - frac);
      g = ((c >>> 8) & 255) * frac + ((k >>> 8) & 255) * (1.0 - frac);
      b = ((c >>> 16) & 255) * frac + ((k >>> 16) & 255) * (1.0 - frac);
      a = 255.0;
    }

    if (l != 0) {
      final lr = (l & 255) * lightK;
      final lg = ((l >>> 8) & 255) * lightK;
      final lb = ((l >>> 16) & 255) * lightK;
      if (a < 255.0) {
        final pa = a / 255.0;
        final pr = r * pa + lr;
        final pg = g * pa + lg;
        final pb = b * pa + lb;
        final maxCh = math.max(lr, math.max(lg, lb)) / 255.0;
        final na = math.min(1.0, math.max(pa, maxCh));
        if (na > 0.0) {
          r = math.min(255.0, pr / na);
          g = math.min(255.0, pg / na);
          b = math.min(255.0, pb / na);
          a = na * 255.0;
        }
      } else {
        r = math.min(255.0, r + lr);
        g = math.min(255.0, g + lg);
        b = math.min(255.0, b + lb);
      }
    }

    final j = i * 4;
    out[j] = _toUint8Clamp(r);
    out[j + 1] = _toUint8Clamp(g);
    out[j + 2] = _toUint8Clamp(b);
    out[j + 3] = _toUint8Clamp(a);
  }
  return out;
}

/// Ease light out over the last [margin] pixels of the frame so exported sprite
/// sheets never show hard box edges on glow pools.
void edgeFade(PixelFrame f, [int margin = 8]) {
  final w = f.w;
  final h = f.h;
  final lBuf = f.light;
  for (var y = 0; y < h; y++) {
    final ey = math.min(y, h - 1 - y);
    for (var x = 0; x < w; x++) {
      final e = math.min(ey, math.min(x, w - 1 - x));
      if (e >= margin) {
        x = w - 1 - margin;
        continue;
      }
      final i = y * w + x;
      final l = lBuf[i];
      if ((l & 0xffffff) == 0) continue;
      final u = (e + 0.5) / margin;
      final k = u * u * (3.0 - 2.0 * u);
      lBuf[i] = (l & 0xff000000) |
          ((l & 255) * k).round() |
          ((((l >>> 8) & 255) * k).round() << 8) |
          ((((l >>> 16) & 255) * k).round() << 16);
    }
  }
}
