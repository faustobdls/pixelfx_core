// Preview backdrops: what the tools and the gallery draw behind an effect.

import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'math.dart';

enum BackdropKind { dark, ground, sky, light, black, none }

final int _sky = hex('#15131d');
final int _skyTop = hex('#0d0b14');
final int _skyLow = hex('#221d33');
final int _floorEdge = hex('#4a4263');
final int _floor = hex('#2b2639');
final int _floorDark = hex('#211d2d');
final int _mortar = hex('#1a1724');
final int _lightBg = hex('#ebe8f0');
final int _starTint = hex('#cfc8ff');

const List<int> _bayerInt = [
  0, 8, 2, 10,
  12, 4, 14, 6,
  3, 11, 1, 9,
  15, 7, 13, 5,
];

BackdropKind parseBackdrop(String name) => BackdropKind.values.firstWhere(
      (b) => b.name == name,
      orElse: () => BackdropKind.dark,
    );

/// A backdrop as a Uint32List of [w] x [h] colors (null if [BackdropKind.none]).
Uint32List? backdrop(BackdropKind kind, int w, int h, [int? groundY]) {
  if (kind == BackdropKind.none) return null;
  final out = Uint32List(w * h);
  if (kind == BackdropKind.light) {
    out.fillRange(0, out.length, _lightBg);
    return out;
  }
  if (kind == BackdropKind.black) {
    out.fillRange(0, out.length, kBlack);
    return out;
  }
  final gy0 = groundY ?? h;
  final denomH = math.max(1, h - 1);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      var c = _sky;
      if (kind == BackdropKind.sky) {
        final t = y / denomH;
        final step = (t * 5.0 + _bayerInt[((y & 3) << 2) | (x & 3)] / 16.0).floor();
        c = mix(_skyTop, _skyLow, math.min(1.0, step / 4.0));
        final r = rand(x, y, 77);
        if (r > 0.994) {
          c = mix(c, _starTint, 0.35 + (r - 0.994) * 90.0);
        }
      }
      if (kind == BackdropKind.ground && y >= gy0) {
        final gy = y - gy0;
        if (gy == 0) {
          c = _floorEdge;
        } else {
          final row = (gy - 1) ~/ 5;
          final off = row.isOdd ? 6 : 0;
          final mortar = (gy - 1) % 5 == 4 || (x + off) % 12 == 0;
          c = mortar ? _mortar : (gy < 3 ? _floor : _floorDark);
        }
      }
      out[y * w + x] = c;
    }
  }
  return out;
}
