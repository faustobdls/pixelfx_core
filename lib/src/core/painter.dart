// The painter draws into a frame's two buffers: `color` (opaque pixels, faded with ordered dither,
// or translucent via `blend`) and `light` (additive glow, composited on top).

import 'dart:math' as math;
import 'dart:typed_data';

import 'actor.dart';
import 'color.dart';
import 'font.dart';
import 'frame.dart';
import 'math.dart';

const List<double> _bayer4x4 = [
  0.5 / 16, 8.5 / 16, 2.5 / 16, 10.5 / 16,
  12.5 / 16, 4.5 / 16, 14.5 / 16, 6.5 / 16,
  3.5 / 16, 11.5 / 16, 1.5 / 16, 9.5 / 16,
  15.5 / 16, 7.5 / 16, 13.5 / 16, 5.5 / 16,
];

class ShadeOut {
  int c = 0;
  double a = 1.0;
  int l = 0;
  double k = 0.0;

  void reset() {
    c = 0;
    a = 1.0;
    l = 0;
    k = 0.0;
  }
}

enum TextAlign { left, center, right }

class Painter {
  final PixelFrame frame;
  final ShadeOut _out = ShadeOut();
  final Expando<List<List<String>>> _spriteCache = Expando();

  late int w;
  late int h;
  late int ox;
  late int oy;
  late Uint32List _c;
  late Uint32List _l;

  double tx = 0.0;
  double ty = 0.0;
  int fx = 1;
  double cs = 1.0;
  double sn = 0.0;
  double fade = 1.0;
  double lightK = 1.0;
  String layer = 'front';

  Painter(this.frame) {
    reset();
  }

  Painter reset() {
    w = frame.w;
    h = frame.h;
    ox = frame.ox;
    oy = frame.oy;
    _c = frame.color;
    _l = frame.light;
    tx = 0.0;
    ty = 0.0;
    fx = 1;
    cs = 1.0;
    sn = 0.0;
    fade = 1.0;
    lightK = 1.0;
    layer = 'front';
    return this;
  }

  /// Put the effect's origin at (x, y) in frame space, mirrored if [flip], rotated by [angle] radians.
  Painter place(double x, double y, {bool flip = false, double angle = 0.0}) {
    tx = x;
    ty = y;
    fx = flip ? -1 : 1;
    cs = math.cos(angle);
    sn = math.sin(angle);
    return this;
  }

  // ---- transforms: local (effect) space <-> screen (frame) space
  @pragma('vm:prefer-inline')
  double toX(double x, double y) => tx + x * fx * cs - y * sn;

  @pragma('vm:prefer-inline')
  double toY(double x, double y) => ty + x * fx * sn + y * cs;

  @pragma('vm:prefer-inline')
  double fromX(double sx, double sy) {
    final dx = sx - tx;
    final dy = sy - ty;
    return (dx * cs + dy * sn) * fx;
  }

  @pragma('vm:prefer-inline')
  double fromY(double sx, double sy) {
    final dx = sx - tx;
    final dy = sy - ty;
    return -dx * sn + dy * cs;
  }

  @pragma('vm:prefer-inline')
  int cellX(double x, double y) =>
      toX(x.floorToDouble() + 0.5, y.floorToDouble() + 0.5).floor();

  @pragma('vm:prefer-inline')
  int cellY(double x, double y) =>
      toY(x.floorToDouble() + 0.5, y.floorToDouble() + 0.5).floor();

  // ---- raw writes, screen space, whole pixels. Color 0 means "nothing".
  void put(int sx, int sy, int c, [double a = 1.0]) {
    if (c == 0) return;
    final alphaEff = a * fade;
    if (alphaEff < 1.0 &&
        alphaEff <= _bayer4x4[((sy & 3) << 2) | (sx & 3)]) {
      return;
    }
    final x = sx - ox;
    final y = sy - oy;
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    _c[y * w + x] = c;
  }

  void add(int sx, int sy, int c, [double k = 1.0]) {
    final kEff = k * fade * lightK;
    if (kEff <= 0.004) return;
    final x = sx - ox;
    final y = sy - oy;
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    final d = _l[i];
    final r = math.min(255, ((d & 255) + (c & 255) * kEff).toInt());
    final g = math.min(255, (((d >>> 8) & 255) + ((c >>> 8) & 255) * kEff).toInt());
    final b = math.min(255, (((d >>> 16) & 255) + ((c >>> 16) & 255) * kEff).toInt());
    _l[i] = ((255 << 24) | (b << 16) | (g << 8) | r) & 0xffffffff;
  }

  /// Blend a color over what's there at alpha [a] (0..1), keeping the result's own alpha.
  void blendPx(int sx, int sy, int c, double a) {
    final alphaEff = a * fade;
    if (c == 0 || alphaEff <= 0.004) return;
    final x = sx - ox;
    final y = sy - oy;
    if (x < 0 || y < 0 || x >= w || y >= h) return;
    final i = y * w + x;
    final d = _c[i];
    final da = (d >>> 24) / 255.0;
    final oa = alphaEff + da * (1.0 - alphaEff);
    final k = alphaEff / oa;
    final oneMinusK = 1.0 - k;
    final r = (((c & 255) * k + (d & 255) * oneMinusK).toInt()) & 255;
    final g = ((((c >>> 8) & 255) * k + ((d >>> 8) & 255) * oneMinusK).toInt()) & 255;
    final b = ((((c >>> 16) & 255) * k + ((d >>> 16) & 255) * oneMinusK).toInt()) & 255;
    final outA = ((oa * 255.0).toInt()) & 255;
    _c[i] = ((outA << 24) | (b << 16) | (g << 8) | r) & 0xffffffff;
  }

  /// Translucent pixel at a local point.
  void blend(num x, num y, int c, double a) =>
      blendPx(cellX(x.toDouble(), y.toDouble()), cellY(x.toDouble(), y.toDouble()), c, a);

  /// A translucent disc: puffs of smoke, vapour, dust.
  void disc(num cx, num cy, num r, int c, double a) => discShaded(
        cx,
        cy,
        r,
        color: (_, _) => c,
        alpha: (_, _) => a,
      );

  void discShaded(
    num cx,
    num cy,
    num r, {
    required int Function(double d, double angle) color,
    required double Function(double d, double angle) alpha,
  }) {
    final cxd = cx.toDouble();
    final cyd = cy.toDouble();
    final rd = r.toDouble();
    if (rd < 0.5) {
      blend(cxd, cyd, color(0.0, 0.0), alpha(0.0, 0.0));
      return;
    }
    final r2 = rd * rd;
    each(cxd - rd, cyd - rd, cxd + rd, cyd + rd, (x, y, sx, sy) {
      final dx = x - cxd;
      final dy = y - cyd;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) return;
      final d = math.sqrt(d2) / rd;
      final ang = math.atan2(dy, dx);
      blendPx(sx, sy, color(d, ang), alpha(d, ang));
    });
  }

  /// Read back the color under a local point (0 if empty).
  int get(num x, num y) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    final sx = cellX(xd, yd) - ox;
    final sy = cellY(xd, yd) - oy;
    return sx < 0 || sy < 0 || sx >= w || sy >= h ? 0 : _c[sy * w + sx];
  }

  // ---- pixels
  void px(num x, num y, int c) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    put(cellX(xd, yd), cellY(xd, yd), c, 1.0);
  }

  void dot(num x, num y, int c, [double a = 1.0]) {
    if (a <= 0.0) return;
    final xd = x.toDouble();
    final yd = y.toDouble();
    put(cellX(xd, yd), cellY(xd, yd), c, a);
  }

  void light(num x, num y, int c, [double k = 1.0]) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    add(cellX(xd, yd), cellY(xd, yd), c, k);
  }

  /// Visit every screen pixel whose center falls in local box [x0, x1] x [y0, y1].
  void each(
    double x0,
    double y0,
    double x1,
    double y1,
    void Function(double lx, double ly, int sx, int sy) fn,
  ) {
    var ax = double.infinity;
    var bx = double.negativeInfinity;
    var ay = double.infinity;
    var by = double.negativeInfinity;
    for (var k = 0; k < 4; k++) {
      final x = (k & 1) != 0 ? x1 : x0;
      final y = (k & 2) != 0 ? y1 : y0;
      final sx = toX(x, y);
      final sy = toY(x, y);
      if (sx < ax) ax = sx;
      if (sx > bx) bx = sx;
      if (sy < ay) ay = sy;
      if (sy > by) by = sy;
    }
    final sx0 = math.max(ax.floor(), ox);
    final sx1 = math.min(bx.ceil(), ox + w - 1);
    final sy0 = math.max(ay.floor(), oy);
    final sy1 = math.min(by.ceil(), oy + h - 1);
    for (var sy = sy0; sy <= sy1; sy++) {
      for (var sx = sx0; sx <= sx1; sx++) {
        final cx = sx + 0.5;
        final cy = sy + 0.5;
        fn(fromX(cx, cy), fromY(cx, cy), sx, sy);
      }
    }
  }

  /// A pixel shader over a local box. [fn] returns a color or mutates [out].
  void shade(
    num x0,
    num y0,
    num x1,
    num y1,
    int? Function(double x, double y, ShadeOut out) fn,
  ) {
    final o = _out;
    each(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble(),
        (lx, ly, sx, sy) {
      o.reset();
      final res = fn(lx, ly, o);
      final c = (res != null && res != 0) ? res : o.c;
      if (c != 0) put(sx, sy, c, o.a);
      if (o.k > 0.0) add(sx, sy, o.l != 0 ? o.l : c, o.k);
    });
  }

  // ---- shapes
  void line(num x0, num y0, num x1, num y1, int c, [double a = 1.0]) =>
      _lineImpl(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble(),
          (_) => c, (_) => a);

  void lineShaded(
    num x0,
    num y0,
    num x1,
    num y1, {
    required int Function(double u) color,
    double Function(double u)? alpha,
  }) =>
      _lineImpl(x0.toDouble(), y0.toDouble(), x1.toDouble(), y1.toDouble(),
          color, alpha ?? (_) => 1.0);

  void _lineImpl(
    double x0,
    double y0,
    double x1,
    double y1,
    int Function(double u) color,
    double Function(double u) alpha,
  ) {
    var sx = cellX(x0, y0);
    var sy = cellY(x0, y0);
    final ex = cellX(x1, y1);
    final ey = cellY(x1, y1);
    final dx = (ex - sx).abs();
    final dy = -(ey - sy).abs();
    final stepx = sx < ex ? 1 : -1;
    final stepy = sy < ey ? 1 : -1;
    final maxD = math.max(dx, -dy);
    final n = maxD == 0 ? 1 : maxD;
    var err = dx + dy;
    var i = 0;
    for (;;) {
      final u = i++ / n;
      put(sx, sy, color(u), alpha(u));
      if (sx == ex && sy == ey) break;
      final e2 = 2 * err;
      if (e2 >= dy) {
        err += dy;
        sx += stepx;
      }
      if (e2 <= dx) {
        err += dx;
        sy += stepy;
      }
    }
  }

  void polyline(List<(double, double)> pts, int c, [double a = 1.0]) {
    for (var i = 1; i < pts.length; i++) {
      line(pts[i - 1].$1, pts[i - 1].$2, pts[i].$1, pts[i].$2, c, a);
    }
  }

  void beam(num x0, num y0, num x1, num y1, num width, int c, [double a = 1.0]) =>
      beamShaded(x0, y0, x1, y1, width, color: (_, _) => c, alpha: (_, _) => a);

  void beamShaded(
    num x0,
    num y0,
    num x1,
    num y1,
    num width, {
    required int Function(double u, double v) color,
    double Function(double u, double v)? alpha,
  }) {
    final ax = x0.toDouble();
    final ay = y0.toDouble();
    final bx = x1.toDouble();
    final by = y1.toDouble();
    final r = width.toDouble() / 2.0;
    final dx = bx - ax;
    final dy = by - ay;
    final sumSq = dx * dx + dy * dy;
    final l2 = sumSq == 0.0 ? 1e-9 : sumSq;
    final r2 = r * r;
    shade(
      math.min(ax, bx) - r,
      math.min(ay, by) - r,
      math.max(ax, bx) + r,
      math.max(ay, by) + r,
      (x, y, o) {
        final u = clamp(((x - ax) * dx + (y - ay) * dy) / l2);
        final px = ax + dx * u - x;
        final py = ay + dy * u - y;
        final d2 = px * px + py * py;
        if (d2 > r2) return null;
        final v = math.sqrt(d2) / r;
        o.c = color(u, v);
        o.a = alpha != null ? alpha(u, v) : 1.0;
        return null;
      },
    );
  }

  void circle(num cx, num cy, num r, int c, [double a = 1.0]) =>
      circleShaded(cx, cy, r, color: (_, _) => c, alpha: (_, _) => a);

  void circleShaded(
    num cx,
    num cy,
    num r, {
    required int Function(double d, double angle) color,
    double Function(double d, double angle)? alpha,
  }) {
    final cxd = cx.toDouble();
    final cyd = cy.toDouble();
    final rd = r.toDouble();
    if (rd < 0.6) {
      dot(cxd, cyd, color(0.0, 0.0), alpha != null ? alpha(0.0, 0.0) : 1.0);
      return;
    }
    final r2 = rd * rd;
    shade(cxd - rd, cyd - rd, cxd + rd, cyd + rd, (x, y, o) {
      final dx = x - cxd;
      final dy = y - cyd;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2) return null;
      final d = math.sqrt(d2) / rd;
      final ang = math.atan2(dy, dx);
      o.c = color(d, ang);
      o.a = alpha != null ? alpha(d, ang) : 1.0;
      return null;
    });
  }

  void ellipse(num cx, num cy, num rx, num ry, int c, [double a = 1.0]) =>
      ellipseShaded(cx, cy, rx, ry, color: (_, _) => c, alpha: (_, _) => a);

  void ellipseShaded(
    num cx,
    num cy,
    num rx,
    num ry, {
    required int Function(double d, double angle) color,
    double Function(double d, double angle)? alpha,
  }) {
    final cxd = cx.toDouble();
    final cyd = cy.toDouble();
    final rxd = rx.toDouble();
    final ryd = ry.toDouble();
    if (rxd <= 0.0 || ryd <= 0.0) return;
    shade(cxd - rxd, cyd - ryd, cxd + rxd, cyd + ryd, (x, y, o) {
      final dx = (x - cxd) / rxd;
      final dy = (y - cyd) / ryd;
      final d2 = dx * dx + dy * dy;
      if (d2 > 1.0) return null;
      final d = math.sqrt(d2);
      final ang = math.atan2(dy, dx);
      o.c = color(d, ang);
      o.a = alpha != null ? alpha(d, ang) : 1.0;
      return null;
    });
  }

  void ring(num cx, num cy, num r, num w, int c, [double a = 1.0]) =>
      ringShaded(cx, cy, r, w, color: (_, _) => c, alpha: (_, _) => a);

  void ringShaded(
    num cx,
    num cy,
    num r,
    num w, {
    required int Function(double v, double angle) color,
    double Function(double v, double angle)? alpha,
  }) {
    final cxd = cx.toDouble();
    final cyd = cy.toDouble();
    final rd = r.toDouble();
    final wd = w.toDouble();
    final r0 = math.max(0.0, rd - wd);
    final r2 = rd * rd;
    final r02 = r0 * r0;
    final span = (rd - r0) == 0.0 ? 1.0 : (rd - r0);
    shade(cxd - rd, cyd - rd, cxd + rd, cyd + rd, (x, y, o) {
      final dx = x - cxd;
      final dy = y - cyd;
      final d2 = dx * dx + dy * dy;
      if (d2 > r2 || d2 < r02) return null;
      final v = wd > 0.0 ? (math.sqrt(d2) - r0) / span : 1.0;
      final ang = math.atan2(dy, dx);
      o.c = color(v, ang);
      o.a = alpha != null ? alpha(v, ang) : 1.0;
      return null;
    });
  }

  void arc(
    num cx,
    num cy,
    num r,
    num w,
    num a0,
    num a1,
    int c, [
    double a = 1.0,
  ]) =>
      arcShaded(
        cx,
        cy,
        r,
        a0,
        a1,
        width: (_) => w.toDouble(),
        color: (_, _) => c,
        alpha: (_, _) => a,
      );

  void arcShaded(
    num cx,
    num cy,
    num r,
    num a0,
    num a1, {
    required double Function(double u) width,
    required int Function(double u, double v) color,
    double Function(double u, double v)? alpha,
  }) {
    final cxd = cx.toDouble();
    final cyd = cy.toDouble();
    final rd = r.toDouble();
    final a0d = a0.toDouble();
    final span = a1.toDouble() - a0d;
    shade(cxd - rd, cyd - rd, cxd + rd, cyd + rd, (x, y, o) {
      final dx = x - cxd;
      final dy = y - cyd;
      final d = math.sqrt(dx * dx + dy * dy);
      if (d > rd) return null;
      var ang = math.atan2(dy, dx) - a0d;
      ang -= (ang / tau).floorToDouble() * tau;
      if (ang > span) return null;
      final u = ang / span;
      final ww = width(u);
      if (ww <= 0.0 || d < rd - ww) return null;
      final v = (d - (rd - ww)) / ww;
      o.c = color(u, v);
      o.a = alpha != null ? alpha(u, v) : 1.0;
      return null;
    });
  }

  void rect(num x, num y, num width, num height, int c, [double a = 1.0]) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    final wd = width.toDouble();
    final hd = height.toDouble();
    if (sn == 0.0) {
      final x0 = xd.round();
      final y0 = yd.round();
      final x1 = (xd + wd).round();
      final y1 = (yd + hd).round();
      for (var yy = y0; yy < y1; yy++) {
        for (var xx = x0; xx < x1; xx++) {
          put(cellX(xx.toDouble(), yy.toDouble()),
              cellY(xx.toDouble(), yy.toDouble()), c, a);
        }
      }
      return;
    }
    shade(xd, yd, xd + wd, yd + hd, (lx, ly, o) {
      if (lx < xd || ly < yd || lx >= xd + wd || ly >= yd + hd) return null;
      o.c = c;
      o.a = a;
      return null;
    });
  }

  void poly(List<(double, double)> pts, int c, [double a = 1.0]) =>
      polyShaded(pts, color: (_, _) => c, alpha: (_, _) => a);

  void polyShaded(
    List<(double, double)> pts, {
    required int Function(double x, double y) color,
    double Function(double x, double y)? alpha,
  }) {
    if (pts.isEmpty) return;
    var x0 = double.infinity;
    var y0 = double.infinity;
    var x1 = double.negativeInfinity;
    var y1 = double.negativeInfinity;
    for (final (px, py) in pts) {
      if (px < x0) x0 = px;
      if (px > x1) x1 = px;
      if (py < y0) y0 = py;
      if (py > y1) y1 = py;
    }
    final n = pts.length;
    shade(x0, y0, x1, y1, (x, y, o) {
      var inside = false;
      for (var i = 0, j = n - 1; i < n; j = i++) {
        final (xi, yi) = pts[i];
        final (xj, yj) = pts[j];
        if ((yi > y) != (yj > y) &&
            x < ((xj - xi) * (y - yi)) / (yj - yi) + xi) {
          inside = !inside;
        }
      }
      if (!inside) return null;
      o.c = color(x, y);
      o.a = alpha != null ? alpha(x, y) : 1.0;
      return null;
    });
  }

  void tri(
    num x0,
    num y0,
    num x1,
    num y1,
    num x2,
    num y2,
    int c, [
    double a = 1.0,
  ]) =>
      poly(
        [
          (x0.toDouble(), y0.toDouble()),
          (x1.toDouble(), y1.toDouble()),
          (x2.toDouble(), y2.toDouble()),
        ],
        c,
        a,
      );

  // ---- light
  void glow(num x, num y, num r, int c, [double k = 0.5]) {
    final rd = r.toDouble();
    if (rd < 1.0 || k <= 0.004) return;
    final cx = toX(x.toDouble(), y.toDouble());
    final cy = toY(x.toDouble(), y.toDouble());
    final x0 = (cx - rd).floor();
    final x1 = (cx + rd).ceil();
    final y0 = (cy - rd).floor();
    final y1 = (cy + rd).ceil();
    for (var sy = y0; sy <= y1; sy++) {
      final dy = (sy + 0.5 - cy) / rd;
      for (var sx = x0; sx <= x1; sx++) {
        final dx = (sx + 0.5 - cx) / rd;
        final d = dx * dx + dy * dy;
        if (d >= 1.0) continue;
        final f = 1.0 - math.sqrt(d);
        add(sx, sy, c, f * f * k);
      }
    }
  }

  void glowLine(
    num x0,
    num y0,
    num x1,
    num y1,
    num r,
    int c, [
    double k = 0.5,
  ]) {
    final rd = r.toDouble();
    if (rd < 1.0 || k <= 0.004) return;
    final ax = toX(x0.toDouble(), y0.toDouble());
    final ay = toY(x0.toDouble(), y0.toDouble());
    final bx = toX(x1.toDouble(), y1.toDouble());
    final by = toY(x1.toDouble(), y1.toDouble());
    final dx = bx - ax;
    final dy = by - ay;
    final sumSq = dx * dx + dy * dy;
    final l2 = sumSq == 0.0 ? 1e-9 : sumSq;
    final xMin = (math.min(ax, bx) - rd).floor();
    final xMax = (math.max(ax, bx) + rd).ceil();
    final yMin = (math.min(ay, by) - rd).floor();
    final yMax = (math.max(ay, by) + rd).ceil();
    for (var sy = yMin; sy <= yMax; sy++) {
      for (var sx = xMin; sx <= xMax; sx++) {
        final px = sx + 0.5;
        final py = sy + 0.5;
        final u = clamp(((px - ax) * dx + (py - ay) * dy) / l2);
        final ex = ax + dx * u - px;
        final ey = ay + dy * u - py;
        final d = math.sqrt(ex * ex + ey * ey) / rd;
        if (d >= 1.0) continue;
        final f = 1.0 - d;
        add(sx, sy, c, f * f * k);
      }
    }
  }

  void glowRing(
    num x,
    num y,
    num ringR,
    num r,
    int c, [
    double k = 0.5,
  ]) {
    final rd = r.toDouble();
    final rBig = ringR.toDouble();
    if (rd < 1.0 || k <= 0.004) return;
    final cx = toX(x.toDouble(), y.toDouble());
    final cy = toY(x.toDouble(), y.toDouble());
    final e = rBig + rd;
    final x0 = (cx - e).floor();
    final x1 = (cx + e).ceil();
    final y0 = (cy - e).floor();
    final y1 = (cy + e).ceil();
    for (var sy = y0; sy <= y1; sy++) {
      for (var sx = x0; sx <= x1; sx++) {
        final d = (hypot(sx + 0.5 - cx, sy + 0.5 - cy) - rBig).abs() / rd;
        if (d >= 1.0) continue;
        final f = 1.0 - d;
        add(sx, sy, c, f * f * k);
      }
    }
  }

  // ---- sprites, text, masks
  void sprite(
    List<String> rows,
    Map<String, Object> pal,
    num x,
    num y, {
    int scale = 1,
    double a = 1.0,
    bool flip = false,
    bool flipY = false,
    int? tint,
  }) {
    var s = _spriteCache[rows];
    if (s == null) {
      s = [
        for (final r in rows) [for (var i = 0; i < r.length; i++) r[i]],
      ];
      _spriteCache[rows] = s;
    }
    final width = s.isEmpty ? 0 : s[0].length;
    final cache = <String, int>{};
    final xd = x.toDouble();
    final yd = y.toDouble();
    for (var r = 0; r < s.length; r++) {
      final rowChars = s[r];
      for (var q = 0; q < rowChars.length; q++) {
        final ch = rowChars[q];
        if (ch == '.' || ch == ' ') continue;
        int? c = tint;
        if (c == null) {
          c = cache[ch];
          if (c == null) {
            final raw = pal[ch];
            c = raw == null ? 0 : hex(raw);
            cache[ch] = c;
          }
        }
        if (c == 0) continue;
        final col = flip ? width - 1 - q : q;
        final row = flipY ? s.length - 1 - r : r;
        if (scale == 1) {
          dot(xd + col, yd + row, c, a);
        } else {
          rect(xd + col * scale, yd + row * scale, scale, scale, c, a);
        }
      }
    }
  }

  void text(
    String str,
    num x,
    num y,
    int c, {
    PixelFontKind font = PixelFontKind.mini,
    int scale = 1,
    TextAlign align = TextAlign.left,
    int? outline,
    int? shadow,
    double a = 1.0,
  }) =>
      textShaded(
        str,
        x,
        y,
        color: (_, _) => c,
        font: font,
        scale: scale,
        align: align,
        outline: outline,
        shadow: shadow,
        a: a,
      );

  void textShaded(
    String str,
    num x,
    num y, {
    required int Function(int gx, int gy) color,
    PixelFontKind font = PixelFontKind.mini,
    int scale = 1,
    TextAlign align = TextAlign.left,
    int? outline,
    int? shadow,
    double a = 1.0,
  }) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    final tw = textWidth(str, font) * scale;
    final left = switch (align) {
      TextAlign.center => (xd - tw / 2.0).round(),
      TextAlign.right => (xd - tw).round(),
      TextAlign.left => xd.round(),
    };
    final top = yd.round();
    if (outline != null) {
      rasterText(str, font, (gx, gy) {
        rect(left + gx * scale - 1, top + gy * scale - 1, scale + 2, scale + 2,
            outline, a);
      });
    }
    if (shadow != null) {
      rasterText(str, font, (gx, gy) {
        rect(left + gx * scale + 1, top + gy * scale + 1, scale, scale,
            shadow, a);
      });
    }
    rasterText(str, font, (gx, gy) {
      rect(left + gx * scale, top + gy * scale, scale, scale, color(gx, gy), a);
    });
  }

  (int w, int h) measure(
    String str, {
    PixelFontKind font = PixelFontKind.mini,
    int scale = 1,
  }) =>
      (textWidth(str, font) * scale, pixelFonts[font]!.height * scale);

  void mask(ActorMask m, num x, num y, int c, [double a = 1.0]) =>
      maskShaded(m, x, y, color: (_, _) => c, alpha: (_, _) => a);

  void maskShaded(
    ActorMask m,
    num x,
    num y, {
    required int Function(int mx, int my) color,
    double Function(int mx, int my)? alpha,
  }) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    for (var my = 0; my < m.h; my++) {
      for (var mx = 0; mx < m.w; mx++) {
        if (m.data[my * m.w + mx] != 0) {
          dot(xd + mx, yd + my, color(mx, my), alpha != null ? alpha(mx, my) : 1.0);
        }
      }
    }
  }

  void outline(ActorMask m, num x, num y, int c, [double a = 1.0]) =>
      outlineShaded(m, x, y, color: (_, _) => c, alpha: (_, _) => a);

  void outlineShaded(
    ActorMask m,
    num x,
    num y, {
    required int Function(int mx, int my) color,
    double Function(int mx, int my)? alpha,
  }) {
    final xd = x.toDouble();
    final yd = y.toDouble();
    bool atMask(int mx, int my) =>
        mx >= 0 &&
        my >= 0 &&
        mx < m.w &&
        my < m.h &&
        m.data[my * m.w + mx] != 0;

    for (var my = -1; my <= m.h; my++) {
      for (var mx = -1; mx <= m.w; mx++) {
        if (!atMask(mx, my) &&
            (atMask(mx - 1, my) ||
                atMask(mx + 1, my) ||
                atMask(mx, my - 1) ||
                atMask(mx, my + 1))) {
          dot(xd + mx, yd + my, color(mx, my),
              alpha != null ? alpha(mx, my) : 1.0);
        }
      }
    }
  }
}

final Expando<Painter> _painters = Expando<Painter>();

/// The painter for a frame (one per frame, reused).
Painter painterFor(PixelFrame frame) {
  var p = _painters[frame];
  if (p == null) {
    p = Painter(frame);
    _painters[frame] = p;
  }
  return p.reset();
}
