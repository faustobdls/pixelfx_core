// Preview backdrops: what the tools and the gallery draw behind an effect.

import 'dart:math' as math;
import 'dart:typed_data';

import 'color.dart';
import 'math.dart';

enum BackdropKind { dark, ground, sky, light, black, isoGrid, none }

final int _sky = hex('#15131d');
final int _skyTop = hex('#0d0b14');
final int _skyLow = hex('#221d33');
final int _floorEdge = hex('#4a4263');
final int _floor = hex('#2b2639');
final int _floorDark = hex('#211d2d');
final int _mortar = hex('#1a1724');
final int _isoTileA = hex('#1c1829');
final int _isoTileB = hex('#181524');
final int _isoEdge = hex('#312a47');
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
  if (kind == BackdropKind.isoGrid) {
    final cx = w ~/ 2;
    final cy = groundY ?? (h * 0.65).round();
    final rx = math.max(1.0, w * 0.58);
    final ry = math.max(1.0, h * 0.58);
    for (var y = 0; y < h; y++) {
      final dy = y - cy;
      for (var x = 0; x < w; x++) {
        final dx = x - cx;
        final a = dx + 2 * dy;
        final b = 2 * dy - dx;
        final tx = (a / 32.0).floor();
        final ty = (b / 32.0).floor();
        final ra = a - tx * 32;
        final rb = b - ty * 32;
        final edge = ra <= 1 || rb <= 1;
        var c = edge ? _isoEdge : (((tx + ty) & 1) == 0 ? _isoTileA : _isoTileB);
        final dist = math.sqrt((dx / rx) * (dx / rx) + (dy / ry) * (dy / ry));
        final vig = clamp((dist - 0.55) / 0.55) * 0.72;
        if (vig > 0.0) {
          c = mix(c, _skyTop, vig);
        }
        out[y * w + x] = c;
      }
    }
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
