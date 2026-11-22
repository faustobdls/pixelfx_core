// An act: an effect performed. The character winds up, lets go and recovers, a target takes the hit,
// and everything freezes for a moment on contact.
// Adapted from Hollow Crown (https://github.com/rehan-remade/hollow-crown), MIT License, Copyright (c) 2026 rehan-remade.

import 'dart:math' as math;
import 'dart:typed_data';

import '../framework/asset.dart';
import 'act_spec.dart';
import 'actor.dart';
import 'color.dart';
import 'frame.dart';
import 'fx.dart';
import 'math.dart';
import 'painter.dart';
import 'poses.dart';
import 'rig.dart';

const int _tw = 38;
const int _th = 52;
const double _ghostLife = 0.16;

final List<int> _dustColors = ramp(['#efe7dc', '#c9bfb8', '#8f8693', '#5a5468']);

class _TargetDummyData {
  final Uint32List pixels;
  final List<int> strawColors;
  final int whiteColor;

  _TargetDummyData._(this.pixels, this.strawColors, this.whiteColor);

  factory _TargetDummyData.build() {
    final tp = <String, int>{
      for (final e in const {
        'ink': '#0b0a1a',
        'wood': '#724c2e',
        'woodL': '#a0703a',
        'woodD': '#4e331f',
        'straw': '#d2aa55',
        'strawL': '#f0d98a',
        'burlapD': '#86643a',
        'burlap': '#b38b57',
        'burlapL': '#c9a26c',
        'red': '#9a2f3c',
        'redL': '#c4434f',
        'white': '#ffffff',
      }.entries)
        e.key: hex(e.value),
    };
    final dummy = Uint32List(_tw * _th);
    void px(int x, int y, int c) {
      if (x >= 0 && y >= 0 && x < _tw && y < _th) dummy[y * _tw + x] = c;
    }

    void rect(int x, int y, int w, int h, int c) {
      for (var j = 0; j < h; j++) {
        for (var i = 0; i < w; i++) {
          px(x + i, y + j, c);
        }
      }
    }

    rect(15, 38, 8, 14, tp['ink']!);
    rect(16, 34, 6, 18, tp['wood']!);
    rect(16, 34, 2, 18, tp['woodL']!);
    rect(20, 34, 2, 18, tp['woodD']!);
    rect(1, 18, 36, 1, tp['ink']!);
    rect(1, 23, 36, 1, tp['ink']!);
    rect(1, 19, 36, 4, tp['wood']!);
    rect(1, 19, 36, 1, tp['woodL']!);
    rect(1, 22, 36, 1, tp['woodD']!);

    for (final (bx, s) in const [(0, -1), (33, 1)]) {
      rect(bx, 17, 5, 8, tp['straw']!);
      for (final (dx, dy, key) in const [
        (2, 16, 'straw'), (3, 15, 'strawL'), (1, 17, 'strawL'),
        (2, 25, 'straw'), (1, 26, 'strawL'), (3, 25, 'burlapD'),
        (2, 19, 'strawL'), (3, 21, 'strawL'), (1, 22, 'burlapD'),
        (2, 23, 'strawL'),
      ]) {
        px(bx + dx, dy, tp[key]!);
      }
      px(s < 0 ? bx - 1 : bx + 5, 19, tp['straw']!);
      px(s < 0 ? bx - 1 : bx + 5, 22, tp['strawL']!);
    }

    void sack(int x, int y, int w, int h) {
      rect(x + 1, y, w - 2, 1, tp['ink']!);
      rect(x + 1, y + h - 1, w - 2, 1, tp['ink']!);
      rect(x, y + 1, 1, h - 2, tp['ink']!);
      rect(x + w - 1, y + 1, 1, h - 2, tp['ink']!);
      rect(x + 1, y + 1, w - 2, h - 2, tp['burlap']!);
      rect(x + w - 4, y + 1, 3, h - 2, tp['burlapD']!);
      rect(x + 1, y + h - 3, w - 2, 2, tp['burlapD']!);
      rect(x + 1, y + 1, 1, h - 4, tp['burlapL']!);
      rect(x + 1, y + 1, w - 6, 1, tp['burlapL']!);
      for (var j = y + 2; j < y + h - 2; j += 3) {
        for (var i = x + 3 + (j % 2); i < x + w - 4; i += 4) {
          px(i, j, tp['burlapD']!);
        }
      }
    }

    sack(9, 17, 20, 24);
    for (var y = 19; y < 36; y++) {
      for (var x = 11; x < 27; x++) {
        final d = hypot(x - 18.5, y - 27.0);
        if ((d > 4.0 && d < 5.4) || d < 1.9) {
          px(x, y, x + y < 45 ? tp['redL']! : tp['red']!);
        }
      }
    }
    for (var x = 10; x < 28; x++) {
      px(x, 36, (x & 1) != 0 ? tp['woodL']! : tp['straw']!);
      px(x, 37, (x & 1) != 0 ? tp['woodD']! : tp['wood']!);
    }
    for (final (x, y, key) in const [
      (11, 41, 'straw'), (12, 42, 'strawL'), (14, 41, 'strawL'),
      (15, 42, 'straw'), (23, 41, 'straw'), (24, 42, 'strawL'),
      (26, 41, 'straw'), (13, 43, 'straw'), (25, 43, 'straw'),
    ]) {
      px(x, y, tp[key]!);
    }

    sack(10, 1, 18, 16);
    for (final ex in const [14, 23]) {
      for (var d = -2; d <= 2; d++) {
        px(ex + d, 7 + d, tp['ink']!);
        px(ex - d, 7 + d, tp['ink']!);
      }
    }
    for (var x = 14; x < 24; x++) {
      px(x, 12, (x & 1) != 0 ? tp['ink']! : tp['burlapD']!);
    }
    for (final x in const [15, 18, 21]) {
      px(x, 11, tp['ink']!);
      px(x, 13, tp['ink']!);
    }
    for (var x = 12; x < 26; x++) {
      px(x, 16, (x & 1) != 0 ? tp['woodL']! : tp['straw']!);
      px(x, 17, (x & 1) != 0 ? tp['wood']! : tp['woodD']!);
    }
    for (final (x, y, key) in const [
      (13, 0, 'straw'), (15, 0, 'strawL'), (18, 0, 'straw'),
      (21, 0, 'strawL'), (24, 0, 'straw'), (9, 4, 'straw'),
      (28, 6, 'straw'), (8, 7, 'strawL'), (29, 3, 'strawL'),
    ]) {
      px(x, y, tp[key]!);
    }

    return _TargetDummyData._(
      dummy,
      [
        tp['strawL']!,
        tp['straw']!,
        tp['straw']!,
        tp['burlapD']!,
        tp['burlapD']!,
      ],
      tp['white']!,
    );
  }
}

final _TargetDummyData _dummyData = _TargetDummyData.build();

class StrawBit {
  double x;
  double y;
  double vx;
  double vy;
  double age = 0.0;
  final double life;
  final bool big;

  StrawBit({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.big,
  });
}

/// A straw target on a spring: sways, flashes, takes a skin, shivers and sheds straw.
class Target {
  final double x;
  double theta = 0.0;
  double omega = 0.0;
  double flashT = 0.0;
  String? skin;
  double skinFade = 0.0;
  double shiver = 0.0;
  double clock = 0.0;
  final Rng r;
  final List<StrawBit> straw = [];
  final SkinRegistry skins;

  Target(this.x, [int seed = 5, SkinRegistry? skins])
      : r = Rng(seed),
        skins = skins ?? SkinRegistry.instance;

  void hit(HitSpec h) {
    omega += h.push;
    flashT = math.max(flashT, h.flash);
    if (h.clearSkin) {
      skin = null;
    } else if (h.skin != null) {
      skin = h.skin;
    }
    if (h.shiver > 0.0) shiver = h.shiver;
    for (var k = 0; k < h.straw; k++) {
      final back = r.next() < 0.3;
      straw.add(StrawBit(
        x: x + r.range(-3.0, 3.0),
        y: h.y + r.range(-3.0, 3.0),
        vx: back ? r.range(-60.0, -5.0) : r.range(10.0, 130.0),
        vy: r.range(-120.0, -5.0),
        life: r.range(1.2, 2.2),
        big: r.next() < 0.5,
      ));
    }
  }

  void step(double dt) {
    clock += dt;
    omega += (-60.0 * theta - 3.4 * omega) * dt;
    theta = clamp(theta + omega * dt, -0.4, 0.42);
    if (flashT > 0.0) flashT -= dt;
    if (shiver > 0.0) shiver -= dt;
    for (final s in straw) {
      s.age += dt;
      s.vy += 210.0 * dt;
      s.x += s.vx * dt;
      s.y += s.vy * dt;
      if (s.y >= 0.0) {
        s.y = 0.0;
        s.vx *= 0.2;
        s.vy = 0.0;
      }
    }
    straw.removeWhere((s) => s.age >= s.life);
  }

  void draw(Uint32List cBuf, int w, int h, int xOrig, int yOrig, bool flip) {
    final tanVal = math.tan(theta);
    final sv = shiver > 0.0 ? (((clock * 30.0).floor() & 1) != 0 ? 1 : -1) : 0;
    final name = flashT > 0.0 ? 'flash' : skin;
    final sk = name != null ? skins[name] : null;
    final base = xOrig + (flip ? -x - 1.0 : x).truncate();
    final dummy = _dummyData.pixels;
    for (var row = 0; row < _th; row++) {
      final o = ((_th - 1 - row) * tanVal * 0.8).round() + sv;
      for (var col = 0; col < _tw; col++) {
        final c = dummy[row * _tw + col];
        if (c == 0) continue;
        final px = base + (flip ? -(col - 19 + o) - 1 : col - 19 + o);
        final py = yOrig - _th + row;
        if (px >= 0 && py >= 0 && px < w && py < h) {
          cBuf[py * w + px] = sk != null ? mix(c, sk.color, sk.mixAmount) : c;
        }
      }
    }
  }

  void drawStraw(Uint32List cBuf, int w, int h, int xOrig, int yOrig, bool flip) {
    final strawPal = _dummyData.strawColors;
    for (final s in straw) {
      final idx = math.min(4, ((s.age / s.life) * 5.0).floor());
      final c = strawPal[idx];
      final lx = s.x.round();
      final ly = s.y.round() - 1;
      final n = s.big ? 2 : 1;
      for (var i = 0; i < n; i++) {
        final px = xOrig + (flip ? -(lx + i) - 1 : lx + i);
        final py = yOrig + ly;
        if (px >= 0 && py >= 0 && px < w && py < h) {
          cBuf[py * w + px] = c;
        }
      }
    }
  }
}

class _BodyCarryTables {
  final Uint8List restMask;
  final Uint32List restPx;
  final Int16List nearest;

  _BodyCarryTables._(this.restMask, this.restPx, this.nearest);

  factory _BodyCarryTables.build() {
    final mask = Uint8List(24 * 38);
    final px = Uint32List(24 * 38);
    for (var r = 0; r < kHero2Rows.length; r++) {
      final row = kHero2Rows[r];
      for (var c = 0; c < row.length; c++) {
        final ch = row[c];
        if (ch != '.') {
          mask[r * 24 + c] = 1;
          px[r * 24 + c] = hex(kDummyPal[ch]!);
        }
      }
    }
    final nearest = Int16List(24 * 38)..fillRange(0, 24 * 38, -1);
    for (var r = 0; r < 38; r++) {
      for (var c = 0; c < 24; c++) {
        var best = -1;
        var bd = 1e9;
        final y0 = math.max(0, r - 7);
        final y1 = math.min(38, r + 8);
        final x0 = math.max(0, c - 7);
        final x1 = math.min(24, c + 8);
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            final d = ((x - c) * (x - c) + (y - r) * (y - r)).toDouble();
            if (mask[y * 24 + x] != 0 && d < bd) {
              bd = d;
              best = y * 24 + x;
            }
          }
        }
        nearest[r * 24 + c] = best;
      }
    }
    return _BodyCarryTables._(mask, px, nearest);
  }
}

final _BodyCarryTables _bodyCarry = _BodyCarryTables.build();

double _lum(int c) =>
    (0.3 * (c & 255) + 0.59 * ((c >>> 8) & 255) + 0.11 * ((c >>> 16) & 255)) /
    255.0;

int _carry(int v, int rest, int own) {
  final lv = _lum(v);
  if (lv > 0.9 || (v >>> 24) < 255) return v;
  final k = math.max(0.45, math.min(1.5, _lum(own) / math.max(0.08, _lum(rest))));
  int ch(int shift) => math.min(255, (((v >>> shift) & 255) * k).round());
  return ((255 << 24) | (ch(16) << 16) | (ch(8) << 8) | ch(0)) & 0xffffffff;
}

(double from, double to) actSpan(PixelEffect mod) {
  final a = mod.act;
  final d = mod.meta.duration;
  final k = a?.poses;
  final from = math.min(0.0, (k != null && k.isNotEmpty) ? k.first.t : 0.0);
  final to = mod.meta.loop
      ? double.infinity
      : math.max(d, (k != null && k.isNotEmpty) ? k.last.t : 0.0);
  return (from, to);
}

class _DustSpeck {
  double x;
  double y;
  double vx;
  double vy;
  double age = 0.0;
  final double life;
  final bool big;
  final int c;

  _DustSpeck({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.big,
    required this.c,
  });
}

class _GhostSnapshot {
  final Pose q;
  double age = 0.0;
  _GhostSnapshot(this.q);
}

class ActInstance implements AssetInstance {
  final PixelEffect effect;
  final EffectInstance fx;
  final EffectMeta meta;
  final ActSpec act;
  final List<Target> targets;
  final bool flip;
  final int _originX;
  final int _originY;
  final List<PoseKey> _track;
  final (double from, double to) _span;
  final List<HitSpec> _hits;
  final List<DustSpec> _dust;
  final Rng _r;
  final int _ghostColor;
  final RigRasterizer _rig;

  final List<_DustSpeck> _specks = [];
  final List<_GhostSnapshot> _ghosts = [];

  double _t;
  double _stop = 0.0;
  bool _stopped = false;
  double _shakeT = 0.0;
  double _shake0 = 0.0;
  double _amp = 0.0;
  int _nh = 0;
  int _nd = 0;
  int _loopN = 0;
  double _gAcc = 0.0;
  Pose? _last;
  PixelFrame? _scratchA;
  PixelFrame? _scratchB;

  void Function(HitSpec hit)? onHit;

  ActInstance._({
    required this.effect,
    required this.fx,
    required this.meta,
    required this.act,
    required this.targets,
    required this.flip,
    required this._originX,
    required this._originY,
    required this._track,
    required (double, double) span,
    required this._hits,
    required this._dust,
    required this._r,
    required this._ghostColor,
    required this._rig,
  })  : _span = span,
        _t = span.$1 {
    _poseNow();
  }

  @override
  double get t => _t;

  @override
  Map<String, Object?> get options => fx.options;

  (int sx, int sy) get shake {
    if (_shakeT <= 0.0) return (0, 0);
    final k = _amp * (_shakeT / _shake0);
    final f = (_shakeT * 60.0).floor();
    return ((math.sin(f * 2.4) * k).round(), (math.cos(f * 3.7) * k * 0.7).round());
  }

  bool get frozen => _stop > 0.0;

  Pose get pose => _last ?? kStand;

  Pose _poseNow() {
    var tt = _t;
    final d = meta.duration;
    if (meta.loop && _t >= d) tt = _t % d;
    var q = poseAt(_track, tt);
    if (!meta.loop && isPoseHeld(_track, tt)) {
      final up = (((tt * 3.0).floor()) & 1).toDouble();
      q = kStand.merge(q).copyWith(
            crouch: (q.crouch ?? 0.0) + up,
            fy: (q.fy ?? kStand.fy!) + up,
            by: (q.by ?? kStand.by!) + up,
          );
    }
    _last = q;
    return q;
  }

  (PixelFrame, PixelFrame) _scratchFor(PixelFrame f) {
    if (_scratchA == null || _scratchA!.w != f.w || _scratchA!.h != f.h) {
      _scratchA = createFrame(f.w, f.h, f.ox, f.oy);
      _scratchB = createFrame(f.w, f.h, f.ox, f.oy);
    }
    return (_scratchA!, _scratchB!);
  }

  @override
  void update(double dt) {
    if (_shakeT > 0.0) _shakeT -= dt;
    if (_stop > 0.0) {
      _stop -= dt;
      return;
    }
    final t0 = _t;
    _t += dt;
    if (_t >= 0.0) {
      fx.update(t0 < 0.0 ? _t : dt);
    }
    final d = meta.duration;
    if (meta.loop && _t >= d) {
      final n = (_t / d).floor();
      if (n != _loopN) {
        _loopN = n;
        _nh = 0;
        _nd = 0;
      }
    }
    final tt = meta.loop && _t >= d ? (_t % d) : _t;
    for (; _nh < _hits.length && _hits[_nh].t <= tt; _nh++) {
      final h = _hits[_nh];
      if (h.stop > 0.0) _stop = math.max(_stop, h.stop);
      if (h.shake > 0.0) {
        _shakeT = _shake0 = h.shake;
        _amp = h.amp;
      }
      if (h.target) {
        for (var i = 0; i < targets.length; i++) {
          if (h.at == null || h.at == i) targets[i].hit(h);
        }
      }
      onHit?.call(h);
    }
    for (; _nd < _dust.length && _dust[_nd].t <= tt; _nd++) {
      final du = _dust[_nd];
      for (var i = 0; i < du.n; i++) {
        final dir = du.dir ?? (_r.next() < 0.5 ? -1 : 1);
        _specks.add(_DustSpeck(
          x: du.x + _r.range(-3.0, 3.0),
          y: -1.0 - _r.range(0.0, 2.0),
          vx: dir * _r.range(22.0, 90.0),
          vy: _r.range(-34.0, -6.0),
          life: _r.range(0.16, 0.4),
          big: _r.next() < 0.45,
          c: du.color == null ? 0 : hex(du.color!),
        ));
      }
    }
    for (final k in _specks) {
      k.age += dt;
      k.vx *= 1.0 - 5.0 * dt;
      k.vy += 110.0 * dt;
      k.x += k.vx * dt;
      k.y = math.min(-1.0, k.y + k.vy * dt);
    }
    _specks.removeWhere((s) => s.age >= s.life);

    final q = _poseNow();
    for (final g in targets) {
      g.step(dt);
    }
    _gAcc += dt;
    if ((q.ghost ?? 0) != 0 && _gAcc >= 1.0 / 30.0) {
      _gAcc = 0.0;
      _ghosts.add(_GhostSnapshot(q));
      if (_ghosts.length > 7) _ghosts.removeAt(0);
    }
    for (final g in _ghosts) {
      g.age += dt;
    }
    while (_ghosts.isNotEmpty && _ghosts.first.age > _ghostLife) {
      _ghosts.removeAt(0);
    }
  }

  @override
  void draw(
    PixelFrame frame, [
    DrawLayer layer = DrawLayer.both,
    bool body = true,
    bool showTarget = true,
  ]) {
    final w = frame.w;
    final h = frame.h;
    final q = _last ?? _poseNow();
    final active = _t >= 0.0;
    final tgt = showTarget ? targets : const <Target>[];
    final fxX = _originX - frame.ox;
    final fxY = _originY - frame.oy;

    void drawTargets() {
      for (final g in tgt) {
        g.draw(frame.color, w, h, fxX, fxY, flip);
      }
    }

    void drawStraw() {
      for (final g in tgt) {
        g.drawStraw(frame.color, w, h, fxX, fxY, flip);
      }
    }

    void drawDust() {
      for (final k in _specks) {
        final idx = math.min(3, ((k.age / k.life) * 4.0).floor());
        final c = k.c != 0 ? k.c : _dustColors[idx];
        final lx = k.x.round();
        final py = fxY + k.y.round();
        final count = k.big ? 2 : 1;
        for (var i = 0; i < count; i++) {
          final px = flip ? fxX - lx - i - 1 : fxX + lx + i;
          if (px >= 0 && py >= 0 && px < w && py < h) {
            frame.color[py * w + px] = c;
          }
        }
      }
    }

    if (!body) {
      if (active) fx.draw(frame, DrawLayer.back);
      drawTargets();
      if (active) fx.draw(frame, DrawLayer.front);
      drawStraw();
      return;
    }

    final rx = (q.x ?? 0.0).round();
    final ry = (q.y ?? 0.0).round();
    final bx = fxX + (flip ? -rx : rx);
    final by = fxY + ry;
    final r = _rig.posed(q);

    void paint(int i, int color) {
      final px = flip ? bx - r.xs[i] - 1 : bx + r.xs[i];
      final py = by + r.ys[i];
      if (px < 0 || py < 0 || px >= w || py >= h) return;
      frame.color[py * w + px] = color;
      if (_ghosts.isNotEmpty) frame.light[py * w + px] = 0;
    }

    void drawGhosts() {
      for (final g in _ghosts) {
        final gr = _rig.posed(g.q);
        final gqx = (g.q.x ?? 0.0).round();
        final gx = fxX + (flip ? -gqx : gqx);
        final gy = fxY + (g.q.y ?? 0.0).round();
        final k = 0.5 * (1.0 - g.age / _ghostLife);
        final r0 = (_ghostColor & 255) * k;
        final g0 = ((_ghostColor >>> 8) & 255) * k;
        final b0 = ((_ghostColor >>> 16) & 255) * k;
        for (var i = 0; i < gr.n; i++) {
          final px = flip ? gx - gr.xs[i] - 1 : gx + gr.xs[i];
          final py = gy + gr.ys[i];
          if (px < 0 || py < 0 || px >= w || py >= h) continue;
          final j = py * w + px;
          final d = frame.light[j];
          final nr = math.min(255, ((d & 255) + r0).toInt());
          final ng = math.min(255, (((d >>> 8) & 255) + g0).toInt());
          final nb = math.min(255, (((d >>> 16) & 255) + b0).toInt());
          frame.light[j] =
              ((255 << 24) | (nb << 16) | (ng << 8) | nr) & 0xffffffff;
        }
      }
    }

    void shadow() {
      final sy = fxY;
      final cx = fxX + (flip ? -rx : rx);
      final hw = 10 +
          (((q.ffx ?? 0.0) - (q.fbx ?? 0.0)).abs().truncate() >> 1) -
          math.min<int>(8, ry.abs() >> 1);
      if (sy < 0 || sy >= h) return;
      for (var dy = 0; dy < 2; dy++) {
        if (sy + dy >= h) continue;
        for (var x = -hw + dy * 2; x <= hw - dy * 2; x++) {
          final px = cx + x;
          if (px < 0 || px >= w) continue;
          final i = (sy + dy) * w + px;
          frame.color[i] = ((frame.color[i] & 0xffffff) |
                  (math.max(frame.color[i] >>> 24, 110) << 24)) &
              0xffffffff;
        }
      }
    }

    if (!act.onBody) {
      if (active) fx.draw(frame, DrawLayer.back);
      drawTargets();
      shadow();
      drawGhosts();
      for (var i = 0; i < r.n; i++) {
        paint(i, r.color[i]);
      }
      if (active) fx.draw(frame, DrawLayer.front);
      drawStraw();
      drawDust();
      return;
    }

    final (aBuf, bBuf) = _scratchFor(frame);
    clearFrame(aBuf);
    clearFrame(bBuf);
    if (active) fx.draw(aBuf, DrawLayer.back);
    bBuf.color.setAll(0, aBuf.color);
    bBuf.light.setAll(0, aBuf.light);
    final dur = meta.duration;
    final tt = meta.loop ? (_t < 0.0 ? 0.0 : _t % dur) : clamp(_t, 0.0, dur);
    final alpha = active ? actorAlphaOf(effect, tt, fx.options) : 1.0;
    drawActor(
      painterFor(bBuf).place(fxX.toDouble(), fxY.toDouble(), flip: flip),
      (fx.options['actor'] as ActorDefinition?) ?? stockActor(2),
      alpha,
    );
    if (active) fx.draw(bBuf, DrawLayer.front);

    final follow = act.follow;
    final lean = (q.lean ?? 0.0) * follow;
    final cr = (q.crouch ?? 0.0) * follow;

    (int, int) shiftOf(int ly) {
      final k = clamp((-11 - ly) / 7.0);
      final f = clamp((-1 - ly) / 6.0);
      return ((lean * k + rx * f).round(), (cr * k + ry * f).round());
    }

    bool restAt(int sx, int sy) {
      final c = (flip ? fxX - sx - 1 : sx - fxX) + 12;
      final r0 = sy - fxY + 38;
      return c >= 0 &&
          r0 >= 0 &&
          c < 24 &&
          r0 < 38 &&
          _bodyCarry.restMask[r0 * 24 + c] == 1;
    }

    final cOut = frame.color;
    final lOut = frame.light;

    void copyPixel(bool isLight, int sx, int sy, int s) {
      final (dx, dy) = shiftOf(sy - fxY);
      final px = sx + (flip ? -dx : dx);
      final py = sy + dy;
      if (px < 0 || py < 0 || px >= w || py >= h) return;
      final i = py * w + px;
      if (isLight) {
        final d = lOut[i];
        final rCh = math.min(255, (d & 255) + (s & 255));
        final gCh = math.min(255, ((d >>> 8) & 255) + ((s >>> 8) & 255));
        final bCh = math.min(255, ((d >>> 16) & 255) + ((s >>> 16) & 255));
        lOut[i] = ((255 << 24) | (bCh << 16) | (gCh << 8) | rCh) & 0xffffffff;
      } else if ((s >>> 24) == 255 || cOut[i] == 0) {
        cOut[i] = s;
      } else {
        final k = (s >>> 24) / 255.0;
        final d = cOut[i];
        int ch(int shift) =>
            (((s >>> shift) & 255) * k + ((d >>> shift) & 255) * (1.0 - k))
                .round();
        cOut[i] = ((math.max(s >>> 24, d >>> 24) << 24) |
                (ch(16) << 16) |
                (ch(8) << 8) |
                ch(0)) &
            0xffffffff;
      }
    }

    drawTargets();
    shadow();
    for (var sy = 0; sy < h; sy++) {
      for (var sx = 0; sx < w; sx++) {
        final c = aBuf.color[sy * w + sx];
        if (c != 0) copyPixel(false, sx, sy, c);
      }
    }
    drawGhosts();

    int restIndex(int s) {
      final c = s % 24;
      final r0 = s ~/ 24;
      final sx = flip ? fxX - (c - 12) - 1 : fxX + c - 12;
      final sy = fxY + r0 - 38;
      return sx >= 0 && sy >= 0 && sx < w && sy < h ? sy * w + sx : -1;
    }

    for (var i = 0; i < r.n; i++) {
      final s = r.src[i] >= 0 ? _bodyCarry.nearest[r.src[i]] : -1;
      if (s < 0) {
        if (alpha > 0.5) paint(i, r.color[i]);
        continue;
      }
      final j = restIndex(s);
      final v = j >= 0 ? bBuf.color[j] : _bodyCarry.restPx[s];
      if (v == 0) continue;
      paint(
        i,
        v == _bodyCarry.restPx[s]
            ? r.color[i]
            : _carry(v, _bodyCarry.restPx[s], r.color[i]),
      );
    }

    for (var sy = 0; sy < h; sy++) {
      for (var sx = 0; sx < w; sx++) {
        final j = sy * w + sx;
        if (bBuf.color[j] != 0 &&
            bBuf.color[j] != aBuf.color[j] &&
            !restAt(sx, sy)) {
          copyPixel(false, sx, sy, bBuf.color[j]);
        }
        if ((bBuf.light[j] & 0xffffff) != 0) {
          copyPixel(true, sx, sy, bBuf.light[j]);
        }
      }
    }
    drawStraw();
    drawDust();
  }

  @override
  void stop() {
    fx.stop();
    _stopped = true;
  }

  @override
  bool get done => _stopped ? fx.done : (_t >= _span.$2 && _stop <= 0.0);
}

ActInstance createAct(
  PixelEffect mod, [
  Map<String, Object?> options = const {},
  RigRasterizer? rig,
  SkinRegistry? skins,
]) {
  final a = mod.act ?? const ActSpec(poses: [PoseKey(0.0, kStand)]);
  final meta = mod.meta;
  final flip = (options['flip'] as bool?) ?? false;
  final seed = (options['seed'] as num?)?.toInt() ??
      (meta.defaultOptions['seed'] as num?)?.toInt() ??
      1;
  final fx = createFx(mod, options);
  final track = a.poses.isEmpty ? const [PoseKey(0.0, kStand)] : a.poses;
  final span = actSpan(mod);
  final ox = (options['x'] as num?)?.toInt() ?? 0;
  final oy = (options['y'] as num?)?.toInt() ?? 0;
  final tgtList = a.effectiveTargets;
  final targets = [
    for (var i = 0; i < tgtList.length; i++)
      Target(tgtList[i].x, seed + 4 + i, skins),
  ];
  final hits = a.hits.toList()..sort((p, q) => p.t.compareTo(q.t));
  final dust = a.dust.toList();
  final ramp =
      (options['palette'] ?? meta.defaultOptions['palette']) as List<Object>?;
  final gcRaw = a.ghost ??
      (ramp != null && ramp.isNotEmpty
          ? ramp[(ramp.length * 0.7).floor()]
          : '#8fb4ff');

  return ActInstance._(
    effect: mod,
    fx: fx,
    meta: meta,
    act: a,
    targets: targets,
    flip: flip,
    originX: ox,
    originY: oy,
    track: track,
    span: span,
    hits: hits,
    dust: dust,
    r: Rng(seed + 9),
    ghostColor: hex(gcRaw),
    rig: rig ?? RigRasterizer.instance,
  );
}

ActTiming? actTiming(PixelEffect mod) {
  final a = mod.act;
  if (a == null) return null;
  final (from, to) = actSpan(mod);
  final d = mod.meta.duration;
  return ActTiming(
    windup: -from,
    recovery: mod.meta.loop ? 0.0 : math.max(0.0, to - d),
    onBody: a.onBody,
    targets: [for (final g in a.effectiveTargets) g.x],
    hits: [
      for (final h in a.hits)
        ActHitTiming(
          t: h.t,
          freeze: h.stop,
          shake: h.shake,
          amp: h.amp,
          push: !h.target ? 0.0 : h.push,
          skin: h.clearSkin ? null : h.skin,
          at: h.at,
        ),
    ],
    poses: [
      for (final p in a.poses)
        ActPoseTiming(t: p.t, how: p.how.name, pose: p.pose),
    ],
  );
}

class ActBounds {
  final int x0;
  final int y0;
  final int x1;
  final int y1;

  const ActBounds(this.x0, this.y0, this.x1, this.y1);
}

ActBounds actBounds(PixelEffect mod, [RigRasterizer? rig]) {
  final a = mod.act;
  final rigInst = rig ?? RigRasterizer.instance;
  final w = mod.meta.width;
  final h = mod.meta.height;
  final ox = mod.meta.originX;
  final oy = mod.meta.originY;
  var x0 = -ox;
  var y0 = -oy;
  var x1 = w - ox;
  var y1 = h - oy;

  void see(Pose p) {
    final r = rigInst.posed(p);
    final x = (p.x ?? 0.0).round();
    final y = (p.y ?? 0.0).round();
    x0 = math.min(x0, r.x0 + x - 1);
    x1 = math.max(x1, r.x1 + x + 1);
    y0 = math.min(y0, r.y0 + y - 1);
    y1 = math.max(y1, r.y1 + y + 1);
  }

  final k = a?.poses;
  if (k != null && k.isNotEmpty) {
    for (var t = k.first.t; t <= k.last.t; t += 1.0 / 12.0) {
      see(poseAt(k, t));
    }
    for (final key in k) {
      see(key.pose);
    }
  } else {
    see(kStand);
  }
  if (a != null) {
    for (final g in a.effectiveTargets) {
      final tx = g.x.round();
      x0 = math.min(x0, tx - 30);
      x1 = math.max(x1, tx + 36);
      y0 = math.min(y0, -56);
    }
  }
  return ActBounds(x0, y0, x1, y1);
}
