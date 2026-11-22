// Point lists for shapes effects keep reaching for: lightning paths, stars, polygons, trails.

import 'dart:math' as math;

import 'math.dart';
import 'particles.dart';

/// A jagged lightning path from (x0, y0) to (x1, y1) by midpoint displacement.
List<Point2> bolt(
  Rng r,
  double x0,
  double y0,
  double x1,
  double y1, {
  double jag = 0.22,
  int depth = 5,
}) {
  var pts = <Point2>[(x0, y0), (x1, y1)];
  for (var d = 0; d < depth; d++) {
    final next = <Point2>[pts[0]];
    for (var i = 1; i < pts.length; i++) {
      final (ax, ay) = pts[i - 1];
      final (bx, by) = pts[i];
      final dx = bx - ax;
      final dy = by - ay;
      final l = hypot(dx, dy);
      final denom = l == 0.0 ? 1.0 : l;
      final off = (r.next() * 2.0 - 1.0) * jag * l;
      next.add((
        (ax + bx) / 2.0 + (-dy / denom) * off,
        (ay + by) / 2.0 + (dx / denom) * off,
      ));
      next.add(pts[i]);
    }
    pts = next;
  }
  return pts;
}

/// Forks off a bolt path: [count] branches, each up to [len] px long.
List<List<Point2>> forks(
  Rng r,
  List<Point2> path, {
  int count = 3,
  double len = 20.0,
  double jag = 0.3,
  double spread = 0.9,
}) {
  final out = <List<Point2>>[];
  for (var k = 0; k < count; k++) {
    final i = 1 + (r.next() * (path.length - 2)).floor();
    final (x, y) = path[i];
    final (px, py) = path[i - 1];
    final a = math.atan2(y - py, x - px) +
        (r.next() < 0.5 ? -1.0 : 1.0) * spread * (0.4 + 0.6 * r.next());
    final l = len * (0.4 + 0.6 * r.next());
    out.add(bolt(r, x, y, x + math.cos(a) * l, y + math.sin(a) * l,
        jag: jag, depth: 3));
  }
  return out;
}

/// A star: [n] points between radii [r1] (tips) and [r0] (inner corners).
List<Point2> star(
  double cx,
  double cy,
  double r0,
  double r1, [
  int n = 5,
  double rot = -math.pi / 2.0,
]) {
  final pts = <Point2>[];
  for (var i = 0; i < n * 2; i++) {
    final a = rot + (i * math.pi) / n;
    final r = i.isOdd ? r0 : r1;
    pts.add((cx + math.cos(a) * r, cy + math.sin(a) * r));
  }
  return pts;
}

/// A regular polygon with [n] sides.
List<Point2> ngon(double cx, double cy, double r, [int n = 6, double rot = 0.0]) =>
    [
      for (var i = 0; i < n; i++)
        (
          cx + math.cos(rot + (i * tau) / n) * r,
          cy + math.sin(rot + (i * tau) / n) * r,
        ),
    ];

/// Positions of `pos(t - i * dt)` for `i = 0..n-1`: a moving thing's trail, newest first.
List<Point2> trail(Point2 Function(double t) pos, double t, int n, double dt) =>
    [for (var i = 0; i < n; i++) pos(math.max(0.0, t - i * dt))];
