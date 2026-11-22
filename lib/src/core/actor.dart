// A stock character to try effects on: status effects wrap its silhouette, hits land on it,
// auras sit behind it. Previews and the gallery draw it; effects read its mask through o.actor.

import 'dart:typed_data';

import 'color.dart';
import 'painter.dart';
import 'particles.dart';

const List<String> kHeroRows = [
  '....kkkkk...',
  '..kkhhhhhk..',
  '.khhhhhhhhk.',
  '.khhhhhhhhhk',
  '.khhssssshhk',
  '.khsessesshk',
  '.khsessesshk',
  '..ksssssssk.',
  '...kkSSSkk..',
  '..kttttttk..',
  '.kttTttTttk.',
  '.ksttTTttsk.',
  '.kstttttttk.',
  '..kbbbbbbk..',
  '..kppkkppk..',
  '..kppk.kppk.',
  '..kppk.kppk.',
  '..koook.kook',
  '..kkkkk.kkkk',
];

const Map<String, String> kHeroPal = {
  'k': '#17121f',
  'h': '#7a4128',
  's': '#f3c49d',
  'S': '#c98b6c',
  'e': '#17121f',
  't': '#5f6f94',
  'T': '#46536f',
  'b': '#8a5a32',
  'p': '#38334a',
  'o': '#6a4030',
  'H': '#a35d34',
  'w': '#ffffff',
  'm': '#a3564a',
  'g': '#e8c060',
  'L': '#7f90b6',
  'O': '#8f5a3f',
  'P': '#4b4560',
  'c': '#f53cd1',
  'C': '#ff8fe6',
  'D': '#a31f8a',
};

const Map<String, String> kDummyPal = {
  'k': '#0e0c14',
  'A': '#e4e6ec',
  'B': '#b6b9c3',
  'C': '#868995',
  'D': '#5c5e6a',
  'E': '#6e707c',
  'F': '#4b4d58',
  'G': '#34353f',
  'J': '#2a2b33',
  'm': '#f53cd1',
};

/// The 2x character (24 x 38), standing easy: rest pose of `rig.dart`, baked.
const List<String> kHero2Rows = [
  '...........kkk..........',
  '..........kAABk.........',
  '.........kAAABJk........',
  '.........kABBJJk........',
  '.........kBBBJCDk.......',
  '.........kBCJDDDk.......',
  '.........kkJJJDk........',
  '.......kkkkABBJCkk......',
  '......kAABCJBCCCkDk.....',
  '......kABBCJCCCmDkDk....',
  '......kBBCDDJCDDDkDk....',
  '......kABCDJDDDDDkk.....',
  '.....kAABDkDDDDJkk......',
  '.....kABCDkDDJJGkk......',
  '.....kABCkJJJGGGkk......',
  '....kJJCDkFFFGGGk.......',
  '....kAJJDkJJJGGGk.......',
  '....kJCJJkABBJGGk.......',
  '.....kJCCkBBCDJJJk......',
  '.....kCCCJBBCDJJDk......',
  '.....kCCCDJCCDkJDDk.....',
  '......kCDDJBCDkDDDk.....',
  '.......kDJJJCDkDDDkk....',
  '.......kJBCJCDkDDDkk....',
  '.......kBDJBCDkCDDkk....',
  '........kJJBCDkCDDk.....',
  '........kBBBCDkCCDDk....',
  '........kBBBCDkCCDDk....',
  '.........kBBCDkJDDDk....',
  '........kBJJJJkCJJJk....',
  '........kBBCCDkCCDDk....',
  '........kBBCDDkCDDk.....',
  '........kBBCDkCCDDk.....',
  '........kBCCDkCCDDk.....',
  '........kBCDDkCDDDk.....',
  '.......kJBCJkkkDJkkkk...',
  '.......kAJJAAAAkCCCCCk..',
  '........kkkkkkkkkkkkk...',
];

class ActorMask {
  final int w;
  final int h;
  final Uint8List data;

  const ActorMask({required this.w, required this.h, required this.data});
}

class ActorDefinition {
  final ActorMask mask;
  final Uint32List pixels;
  final List<String> rows;
  final Map<String, String> palette;
  final int x;
  final int y;
  final int w;
  final int h;
  final int scale;
  final Point2 head;
  final Point2 chest;
  final List<(int, int)>? eyes;

  const ActorDefinition({
    required this.mask,
    required this.pixels,
    required this.rows,
    required this.palette,
    required this.x,
    required this.y,
    required this.w,
    required this.h,
    required this.scale,
    required this.head,
    required this.chest,
    this.eyes,
  });
}

ActorMask _maskOf(List<String> rows) {
  final h = rows.length;
  final w = rows[0].length;
  final data = Uint8List(w * h);
  for (var y = 0; y < h; y++) {
    final row = rows[y];
    for (var x = 0; x < w; x++) {
      if (row[x] != '.') data[y * w + x] = 1;
    }
  }
  return ActorMask(w: w, h: h, data: data);
}

Uint32List _pixelsOf(List<String> rows, Map<String, String> pal) {
  final w = rows[0].length;
  final data = Uint32List(w * rows.length);
  for (var y = 0; y < rows.length; y++) {
    final row = rows[y];
    for (var x = 0; x < w; x++) {
      final ch = row[x];
      data[y * w + x] = ch == '.' ? 0 : hex(pal[ch]!);
    }
  }
  return data;
}

final ActorMask _mask1 = _maskOf(kHeroRows);
final ActorMask _mask2 = _maskOf(kHero2Rows);
final Uint32List _pixels1 = _pixelsOf(kHeroRows, kHeroPal);
final Uint32List _pixels2 = _pixelsOf(kHero2Rows, kDummyPal);

final ActorDefinition _stock1 = ActorDefinition(
  mask: _mask1,
  pixels: _pixels1,
  rows: kHeroRows,
  palette: kHeroPal,
  x: -(_mask1.w ~/ 2),
  y: -_mask1.h,
  w: _mask1.w,
  h: _mask1.h,
  scale: 1,
  head: (0.0, (-_mask1.h).toDouble()),
  chest: (0.0, (-_mask1.h + 11).toDouble()),
);

final ActorDefinition _stock2 = ActorDefinition(
  mask: _mask2,
  pixels: _pixels2,
  rows: kHero2Rows,
  palette: kDummyPal,
  x: -(_mask2.w ~/ 2),
  y: -_mask2.h,
  w: _mask2.w,
  h: _mask2.h,
  scale: 2,
  head: (0.0, (-_mask2.h).toDouble()),
  chest: (0.0, -26.0),
  eyes: const [(13, 3), (15, 3)],
);

/// The stock actor at scale [scale] (1: 12 x 19 px, 2: 24 x 38 px), feet at (0, 0).
ActorDefinition stockActor([int scale = 1]) => scale == 2 ? _stock2 : _stock1;

/// Build a custom actor from ASCII sprite rows and palette (extensible for user games).
ActorDefinition buildActor({
  required List<String> rows,
  required Map<String, String> palette,
  int scale = 2,
  Point2? chest,
  List<(int, int)>? eyes,
}) {
  final mask = _maskOf(rows);
  final pixels = _pixelsOf(rows, palette);
  final x = -(mask.w ~/ 2);
  final y = -mask.h;
  return ActorDefinition(
    mask: mask,
    pixels: pixels,
    rows: rows,
    palette: palette,
    x: x,
    y: y,
    w: mask.w,
    h: mask.h,
    scale: scale,
    head: (0.0, y.toDouble()),
    chest: chest ?? (0.0, (y * 0.68).roundToDouble()),
    eyes: eyes,
  );
}

/// Draw the actor with its feet at the painter's origin, at dithered alpha [a].
void drawActor(Painter p, [ActorDefinition? actor, double a = 1.0]) {
  if (a <= 0.0) return;
  final act = actor ?? _stock1;
  p.sprite(act.rows, act.palette, act.x, act.y, a: a);
}
