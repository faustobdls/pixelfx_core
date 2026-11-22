// Simulated particles, debris and lights, for effects that want real physics.
// Adapted from Sprite Fusion's open-source pixel art VFX
// (https://www.spritefusion.com/pixel-art-vfx), MIT License, Copyright (c) 2026 Hugo Duprez.

import 'dart:math' as math;

import 'color.dart';
import 'math.dart';
import 'painter.dart';

const double kGravity = 950.0; // px/s^2

const List<(int, int)> _cross = [(1, 0), (-1, 0), (0, 1), (0, -1)];
const List<(int, int)> _diag = [(1, 1), (1, -1), (-1, 1), (-1, -1)];

final List<int> _hot = ramp(['#fff3a6', '#ffe26b', '#ff8a2a', '#f2561d']);

/// Fire from white-hot to smouldering, and smoke from fresh to thin.
final List<int> kFireRamp = ramp([
  '#ffffff', '#fff3a6', '#ffe26b', '#ffc23d', '#ff8a2a',
  '#f2561d', '#c9281f', '#8a1f17', '#4a1712',
]);

final List<int> kSmokeRamp = ramp([
  '#7b6f72', '#5d5660', '#433d48', '#2b2630', '#1a171e',
]);

int _rampAt(List<int> r, double t) =>
    r[clampInt((t * r.length).floor(), 0, r.length - 1)];

/// Particle kinds.
enum ParticleKind {
  spark,
  mote,
  streak,
  flake,
  vapour,
  dust,
  star,
  ember,
  smoke,
  fire,
  brand,
  grit,
}

/// Alias matching upstream JS `P` ergonomics.
typedef P = ParticleKind;

/// Particle flags: SMOKES (FIRE leaves smoke on death), BIG (bigger slower smoke), BACK (draw behind).
abstract final class PF {
  static const int smokes = 1;
  static const int big = 2;
  static const int back = 4;
}

const Set<ParticleKind> _softKinds = {
  ParticleKind.vapour,
  ParticleKind.dust,
  ParticleKind.smoke,
};

class SimParticle {
  final ParticleKind k;
  double x;
  double y;
  double vx;
  double vy;
  double life;
  final double max;
  final int col;
  final double size;
  final double seed;
  double delay;
  final int flag;

  SimParticle({
    required this.k,
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    required this.max,
    required this.col,
    required this.size,
    required this.seed,
    required this.delay,
    required this.flag,
  });
}

class Particles {
  final Rng r;
  final List<SimParticle> list = [];
  double t = 0.0;
  final double Function(double x) ground;
  final List<int> sparks;
  final int? haze;
  final void Function(double x, double y)? onLand;

  Particles({
    Rng? rng,
    int seed = 1,
    double Function(double x)? ground,
    List<Object>? sparks,
    Object? haze,
    this.onLand,
  })  : r = rng ?? Rng(seed),
        ground = ground ?? ((_) => double.infinity),
        sparks = (sparks ?? _hot).map(hex).toList(growable: false),
        haze = haze == null ? null : hex(haze);

  void spawn(
    ParticleKind k,
    double x,
    double y,
    double vx,
    double vy,
    double life, [
    Object? col,
    double size = 1.0,
    double delay = 0.0,
    int flag = 0,
  ]) {
    final parsedCol = col == null ? kWhite : (col == 0 ? 0 : hex(col));
    list.add(SimParticle(
      k: k,
      x: x,
      y: y,
      vx: vx,
      vy: vy,
      life: life,
      max: life,
      col: parsedCol,
      size: size,
      seed: r.next() * 100.0,
      delay: delay,
      flag: flag,
    ));
  }

  int get count => list.length;

  void update(double dt) {
    t += dt;
    final rng = r;
    final curT = t;
    for (var i = list.length - 1; i >= 0; i--) {
      final p = list[i];
      if (p.delay > 0.0) {
        p.delay -= dt;
        continue;
      }
      p.life -= dt;
      if (p.life <= 0.0) {
        if (p.k == ParticleKind.fire && (p.flag & PF.smokes) != 0) {
          final big = (p.flag & PF.big) != 0;
          spawn(
            ParticleKind.smoke,
            p.x,
            p.y,
            p.vx * 0.6,
            p.vy * 0.6 - 6.0,
            big ? rng.range(1.3, 2.3) : rng.range(0.8, 1.4),
            0,
            p.size * (big ? 0.85 : 0.7),
            0.0,
            big ? PF.big : 0,
          );
        }
        list.removeAt(i);
        continue;
      }
      switch (p.k) {
        case ParticleKind.fire:
          p.vy -= 95.0 * dt;
          p.vx += math.sin(curT * 17.0 + p.seed) * 30.0 * dt;
          p.vx -= p.vx * 5.0 * dt;
          p.vy -= p.vy * 3.2 * dt;
        case ParticleKind.grit:
          p.vy += kGravity * dt;
          p.vx -= p.vx * 0.8 * dt;
          final g = ground(p.x);
          final ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0.0 && p.y <= g && ny >= g) {
            p.y = g - 0.25;
            if (p.vy > 130.0 && rng.chance(0.4)) {
              p.vy = -p.vy * 0.25;
              p.vx = p.vx * 0.5 + rng.range(-10.0, 10.0);
            } else {
              p.vx = 0.0;
              p.vy = 0.0;
              p.life = math.min(p.life, 0.5);
            }
          } else {
            p.y = ny;
          }
          continue;
        case ParticleKind.brand:
          p.vy += kGravity * 0.8 * dt;
          p.vx -= p.vx * 0.9 * dt;
          if (rng.chance(0.9 * math.min(1.0, dt * 60.0))) {
            spawn(
              ParticleKind.fire,
              p.x,
              p.y,
              p.vx * 0.1 + rng.range(-7.0, 7.0),
              p.vy * 0.1 - 10.0,
              rng.range(0.16, 0.32),
              0,
              rng.range(0.9, 1.7) * (0.5 + (p.life / p.max) * 0.6),
              0.0,
              rng.chance(0.4) ? PF.smokes : 0,
            );
          }
          final g = ground(p.x);
          final ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0.0 && p.y <= g && ny >= g) {
            onLand?.call(p.x, g);
            list.removeAt(i);
          } else {
            p.y = ny;
          }
          continue;
        case ParticleKind.spark:
          p.vy += kGravity * 0.45 * dt;
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt;
          final g = ground(p.x);
          final ny = p.y + p.vy * dt;
          p.x += p.vx * dt;
          if (p.vy > 0.0 && p.y <= g && ny >= g) {
            p.vy = -p.vy * 0.45;
            p.vx *= 0.7;
            p.y = g - 0.25;
          } else {
            p.y = ny;
          }
          continue;
        case ParticleKind.streak:
          p.vx += p.vx * 3.0 * dt;
          p.vy += p.vy * 3.0 * dt;
        case ParticleKind.flake:
          p.vx -= p.vx * 2.2 * dt;
          p.vy -= p.vy * 2.2 * dt - 35.0 * dt;
          p.x += math.sin(t * 2.5 + p.seed) * 7.0 * dt;
        case ParticleKind.ember:
          p.vy += (-30.0 + math.sin(curT * 3.0 + p.seed) * 20.0) * dt;
          p.vx += math.cos(curT * 2.3 + p.seed) * 45.0 * dt;
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.6 * dt;
        case ParticleKind.smoke:
          final big = (p.flag & PF.big) != 0;
          p.vy -= (big ? 23.0 : 16.0) * dt;
          p.vx += math.sin(curT * 1.3 + p.seed) * 8.0 * dt;
          p.vx -= p.vx * 1.6 * dt;
          p.vy -= p.vy * 1.2 * dt;
        case ParticleKind.mote:
          p.vx -= p.vx * 0.6 * dt;
          p.vy -= p.vy * 0.6 * dt;
        case ParticleKind.vapour:
        case ParticleKind.dust:
        case ParticleKind.star:
          final drag = _softKinds.contains(p.k) ? 4.0 : 1.6;
          p.vx -= p.vx * drag * dt;
          p.vy -= p.vy * drag * dt + 5.0 * dt;
      }
      p.x += p.vx * dt;
      p.y += p.vy * dt;
    }
  }

  void draw(Painter p, [String? layer]) {
    for (final q in list) {
      if (q.delay > 0.0) continue;
      final qLayer =
          (_softKinds.contains(q.k) || (q.flag & PF.back) != 0) ? 'back' : 'front';
      if (layer != null && qLayer != layer) continue;
      final k = q.life / q.max;
      final x = q.x;
      final y = q.y;
      final rawSp = hypot(q.vx, q.vy);
      final sp = rawSp == 0.0 ? 1.0 : rawSp;
      final ux = q.vx / sp;
      final uy = q.vy / sp;
      switch (q.k) {
        case ParticleKind.spark:
          final s = sparks;
          final head = k > 0.6 ? s[0] : (k > 0.3 ? s[1] : s[2]);
          final len = math.min(9.0, 1.0 + sp * 0.022);
          p.line(x - ux * len, y - uy * len, x - ux * len * 0.4,
              y - uy * len * 0.4, k > 0.5 ? head : s[s.length - 1]);
          p.line(x - ux * len * 0.45, y - uy * len * 0.45, x, y, head);
          p.glow(x, y, 3, head, 0.45 * k);
        case ParticleKind.mote:
          final len = math.min(16.0, 0.5 + sp * 0.026) * q.size;
          final a = k < 0.35 ? k / 0.35 : 1.0;
          p.line(x - ux * len, y - uy * len, x - ux * len * 0.35,
              y - uy * len * 0.35, scaleColor(q.col, 0.55), a);
          p.line(x - ux * len * 0.4, y - uy * len * 0.4, x, y, q.col, a);
          p.glow(x, y, 2.5 + q.size, q.col, 0.4 * k);
        case ParticleKind.streak:
          final l = clamp(sp / 30.0, 1.0, 7.0);
          for (var d = l; d >= 0.0; d -= 0.5) {
            p.dot(
              x - ux * d,
              y - uy * d,
              d < 1.0
                  ? kWhite
                  : (d < l * 0.5 ? q.col : scaleColor(q.col, 0.6)),
              d < l * 0.5 ? 1.0 : 1.2 - d / l,
            );
          }
          p.glow(x, y, 4, q.col, 0.4);
        case ParticleKind.flake:
          final a = math.min(1.0, k * 3.0);
          p.dot(x, y, q.col, a);
          if (q.size > 1.3) {
            for (final (dx, dy) in _cross) {
              p.dot(x + dx, y + dy, scaleColor(q.col, 0.8), a * 0.8);
            }
          }
        case ParticleKind.vapour:
          final rad = q.size * (0.6 + (1.0 - k) * 0.9);
          p.disc(x, y, rad, q.col, math.pow(k, 1.3).toDouble() * 0.45);
          final hz = haze;
          if (hz != null) p.glow(x, y, rad * 1.8, hz, 0.16 * k);
        case ParticleKind.dust:
          p.disc(x, y, q.size * (0.6 + (1.0 - k) * 0.9), q.col,
              math.pow(k, 1.3).toDouble() * 0.7);
        case ParticleKind.smoke:
          final age = 1.0 - k;
          final big = (q.flag & PF.big) != 0;
          final rad = q.size *
              (0.65 +
                  math.min(1.0, age * 2.5) * 0.45 +
                  age * (big ? 0.5 : 0.4));
          final a = math.min(1.0, age * 12.0) *
              math.min(1.0, k * 2.4) *
              (big ? 0.7 : 0.58);
          final c = q.col != 0
              ? mix(q.col, _rampAt(kSmokeRamp, age), age)
              : _rampAt(kSmokeRamp, age * 1.05);
          p.disc(x, y, rad, c, a * 0.45);
          p.disc(x + rad * 0.05, y + rad * 0.06, rad * 0.74, c, a * 0.62);
          if (age < 0.5) {
            p.disc(x - rad * 0.22, y - rad * 0.3, rad * 0.5,
                mix(c, kWhite, 0.12), a * 0.4 * (1.0 - age * 2.0));
          }
        case ParticleKind.fire:
          final age = 1.0 - k;
          final heat = math.min(
            0.999,
            math.pow(age, 0.62).toDouble() + (q.seed % 1.0) * 0.1,
          );
          final f = kFireRamp;
          final n = f.length;
          final idx = math.min(n - 2, (heat * (n - 1)).floor());
          final rad = q.size *
              (0.55 + 0.45 * math.min(1.0, age * 7.0)) *
              (1.0 - age * 0.55);
          final c = f[idx];
          if (idx >= n - 2) {
            p.disc(x, y, rad, c, math.min(1.0, k * 3.0) * 0.85);
          } else {
            p.circle(x, y, rad, f[math.min(n - 1, idx + 2)]);
            p.circle(x - rad * 0.16, y - rad * 0.22, rad * 0.78, c);
            if (rad > 1.6) p.circle(x, y - rad * 0.9, rad * 0.42, c);
            if (idx <= 3 && rad > 1.8) {
              p.circle(x - rad * 0.28, y - rad * 0.34, rad * 0.36,
                  f[math.max(0, idx - 1)]);
            }
            if (idx < 6) p.glow(x, y, rad * 2.4 + 2.0, c, 0.18 * k);
          }
        case ParticleKind.brand:
          p.circle(x, y, 1.6, _hot[3]);
          p.px(x, y, math.sin(t * 40.0 + q.seed) > 0.0 ? _hot[0] : _hot[1]);
          p.px(x + 1, y, _hot[1]);
          p.glow(x, y, 7, _hot[2], 0.45);
        case ParticleKind.grit:
          if (k > 0.25 || k * 4.0 > 0.5) {
            p.px(x, y, q.col);
            if (q.size >= 2.0) {
              p.px(x + 1, y, q.col);
              p.px(x, y + 1, scaleColor(q.col, 0.8));
              p.px(x + 1, y + 1, scaleColor(q.col, 0.7));
            }
          }
        case ParticleKind.ember:
          final c = k > 0.6 ? sparks[0] : (k > 0.3 ? sparks[1] : sparks[2]);
          if (k < 0.25 && math.sin(t * 40.0 + q.seed) < 0.0) break;
          p.px(x, y, c);
          if (q.size > 1.5) p.px(x, y + 1, sparks[sparks.length - 1]);
          p.glow(x, y, 3.0 + q.size, c, 0.35 * k);
        case ParticleKind.star:
          final tw = 0.6 + 0.4 * math.sin(t * (8.0 + (q.seed % 5.0)) + q.seed);
          if (q.size < 1.0) {
            if (tw * k > 0.25) p.px(x, y, tw > 0.8 ? kWhite : q.col);
            p.glow(x, y, 3, q.col, 0.4 * k * tw);
            break;
          }
          sparkle(p, x, y, q.size * tw * math.min(1.0, k * 3.0), q.col,
              scaleColor(q.col, 0.75), 0.5 * k * tw);
      }
    }
  }
}

class SimBlaze {
  final double x;
  final double y;
  double life;
  final double max;
  double acc;
  final double power;

  SimBlaze(this.x, this.y, this.life, this.acc, this.power) : max = life;
}

class Blazes {
  final Particles ps;
  final List<SimBlaze> list = [];

  Blazes(this.ps);

  void add(double x, double y, double life, double power) {
    list.add(SimBlaze(x, y, life, ps.r.next(), power));
  }

  int get count => list.length;

  void update(double dt) {
    final r = ps.r;
    for (var i = list.length - 1; i >= 0; i--) {
      final b = list[i];
      b.life -= dt;
      if (b.life <= 0.0) {
        list.removeAt(i);
        continue;
      }
      final k = b.life / b.max;
      final intensity =
          b.power * (k > 0.7 ? 1.0 : 0.35 + (k / 0.7) * 0.65);
      for (b.acc += dt * (6.0 + 16.0 * intensity); b.acc > 1.0; b.acc -= 1.0) {
        final s = r.range(1.2, 2.8) * intensity;
        ps.spawn(
          ParticleKind.fire,
          b.x + r.range(-1.5, 1.5),
          b.y - s * 0.6,
          r.range(-6.0, 6.0),
          r.range(-30.0, -12.0),
          r.range(0.28, 0.6),
          0,
          s,
          0.0,
          PF.back | (r.chance(0.3) ? PF.smokes : 0),
        );
        if (r.chance(0.06)) {
          ps.spawn(
            ParticleKind.ember,
            b.x,
            b.y - 1.5,
            r.range(-15.0, 15.0),
            r.range(-45.0, -15.0),
            r.range(0.6, 1.4),
            _hot[2],
            1.0,
            0.0,
            PF.back,
          );
        }
      }
    }
  }

  void drawBack(Painter p) {
    for (final b in list) {
      final k = b.life / b.max;
      p.px(
        b.x,
        b.y,
        k > 0.4
            ? (math.sin(b.life * 31.0 + b.x) > 0.0 ? _hot[1] : _hot[2])
            : _hot[3],
      );
      p.glow(b.x, b.y, 6.0 + 5.0 * k * b.power, _hot[2], 0.3 * k * b.power);
    }
  }
}

enum DebrisKind { shard, chunk, drip }

typedef B = DebrisKind;

class DebrisBit {
  final DebrisKind kind;
  double x;
  double y;
  double vx;
  double vy;
  double a;
  double va;
  final double s;
  final int c;
  final List<int>? rampColors;
  final double g;
  final double drag;
  final double bounce;
  double life;
  final double max;
  bool rest = false;

  DebrisBit({
    this.kind = DebrisKind.shard,
    required this.x,
    required this.y,
    this.vx = 0.0,
    this.vy = 0.0,
    this.a = 0.0,
    this.va = 0.0,
    this.s = 1.0,
    int? c,
    List<Object>? rampColors,
    this.g = 1.0,
    this.drag = 0.0,
    this.bounce = 0.0,
    this.life = 1.0,
  })  : c = c ?? kWhite,
        rampColors = rampColors?.map(hex).toList(growable: false),
        max = life;
}

class Bits {
  static final List<int> _defaultChunkRamp = ramp([
    '#1c2030', '#3a4a66', '#6e86a8', '#a8c0dc', '#e8f2ff',
  ]);

  final List<DebrisBit> list = [];
  final double Function(double x) ground;

  Bits({double Function(double x)? ground})
      : ground = ground ?? ((_) => double.infinity);

  void add(DebrisBit bit) => list.add(bit);

  int get count => list.length;

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      final b = list[i];
      b.life -= dt;
      if (b.life <= 0.0) {
        list.removeAt(i);
        continue;
      }
      if (b.rest) continue;
      b.vy += kGravity * b.g * dt;
      b.vx -= b.vx * b.drag * dt;
      b.vy -= b.vy * b.drag * dt;
      b.x += b.vx * dt;
      b.y += b.vy * dt;
      b.a += b.va * dt;
      final floor = ground(b.x);
      final sp = b.vy;
      if (b.g <= 0.0 || b.y < floor || sp <= 0.0) continue;
      b.y = floor - 0.01;
      if (b.kind == DebrisKind.drip) {
        b.life = 0.0;
      } else if (b.bounce > 0.0 && sp > 70.0) {
        b.vy = -sp * b.bounce;
        b.vx *= 0.7;
        b.va *= 0.6;
      } else {
        b.rest = true;
        b.vx = 0.0;
        b.vy = 0.0;
      }
    }
  }

  void draw(Painter p) {
    for (final b in list) {
      final a = math.min(1.0, b.life / 0.4);
      final ca = math.cos(b.a);
      final sa = math.sin(b.a);
      if (b.kind == DebrisKind.shard) {
        for (var d = -b.s / 2.0; d <= b.s / 2.0; d += 0.5) {
          p.dot(b.x + ca * d, b.y + sa * d,
              d > b.s / 2.0 - 0.6 ? kWhite : b.c, a);
        }
      } else if (b.kind == DebrisKind.drip) {
        p.dot(b.x, b.y, b.c, a);
        p.dot(b.x, b.y - 1.0, b.c, a * 0.5);
      } else {
        final rList = b.rampColors ?? _defaultChunkRamp;
        final n = rList.length;
        final x = b.x.round();
        final y = b.y.round();
        final rad = b.s.ceil() + 1;
        for (var py = -rad; py <= rad; py++) {
          for (var px = -rad; px <= rad; px++) {
            final u = (px + 0.5) * ca + (py + 0.5) * sa;
            final v = -(px + 0.5) * sa + (py + 0.5) * ca;
            final d = u.abs() / b.s + v.abs() / (b.s * 0.62);
            if (d > 1.3) continue;
            final col = d > 1.0
                ? rList[0]
                : (v < 0.0
                    ? (u < 0.0 ? rList[n - 1] : rList[n - 2])
                    : (u < 0.0
                        ? rList[n - 3]
                        : rList[math.max(1, n - 4)]));
            p.dot(x + px, y + py, col, a);
          }
        }
      }
    }
  }
}

class SimLight {
  final double x;
  final double y;
  final double r;
  final int color;
  final double k;
  double life;
  final double max;

  SimLight(this.x, this.y, this.r, this.color, this.k, this.life) : max = life;
}

class Lights {
  final List<SimLight> list = [];

  void add(
    double x,
    double y,
    double r,
    Object color,
    double k,
    double life,
  ) {
    list.add(SimLight(x, y, r, hex(color), k, life));
  }

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      list[i].life -= dt;
      if (list[i].life <= 0.0) list.removeAt(i);
    }
  }

  void draw(Painter p) {
    for (final l in list) {
      final k = l.life / l.max;
      p.glow(l.x, l.y, l.r * (0.55 + 0.45 * k), l.color, l.k * k * k);
    }
  }
}

/// A star glint: arms of length [arm] in [c] with tips in [tip], a white heart, light.
void sparkle(
  Painter p,
  double x,
  double y,
  double arm,
  int c, [
  int? tip,
  double k = 0.6,
]) {
  final n = arm.round();
  if (n < 1) return;
  final tipC = tip ?? c;
  final cx = x.floor();
  final cy = y.floor();
  for (var d = 1; d <= n; d++) {
    final cc = d > n * 0.6 ? tipC : c;
    for (final (dx, dy) in _cross) {
      p.px(cx + dx * d, cy + dy * d, cc);
    }
  }
  if (n >= 3) {
    for (final (dx, dy) in _diag) {
      p.px(cx + dx, cy + dy, c);
    }
  }
  if (n >= 6) {
    for (final (dx, dy) in _diag) {
      p.px(cx + dx * 2, cy + dy * 2, tipC);
    }
  }
  p.px(cx, cy, kWhite);
  p.glow(x, y, 4.0 + n * 2.0, c, k);
}

/// An 8-ray flare: long rays on the axes, shorter between, fading out along their length.
void flare(
  Painter p,
  double x,
  double y,
  double length,
  double k,
  List<Object> rampColors,
) {
  if (length < 1.0) return;
  final rList = rampColors.map(hex).toList(growable: false);
  final n = rList.length;
  for (var i = 0; i < 8; i++) {
    final an = (i * math.pi) / 4.0;
    final len =
        i % 4 == 0 ? length : (i % 2 == 0 ? length * 0.6 : length * 0.3);
    final ca = math.cos(an);
    final sa = math.sin(an);
    for (var d = 0.0; d <= len; d += 0.5) {
      final u = d / len;
      p.dot(
        x + ca * d,
        y + sa * d,
        u < 0.35 ? kWhite : (u < 0.7 ? rList[n - 2] : rList[n - 3]),
        u < 0.6 ? 1.0 : k * 1.5 * (1.0 - u) + 0.2,
      );
    }
  }
}

/// A ring on a tilted plane (sy squashes it: 0.16 lies on the floor, 1 stands up).
void band(
  Painter p,
  double cx,
  double cy,
  double r,
  double sy,
  double th,
  double k,
  List<Object> rampColors, {
  bool Function(double angle)? keep,
  bool hot = false,
}) {
  if (r <= 0.0 || k <= 0.0) return;
  final rList = rampColors.map(hex).toList(growable: false);
  final n = rList.length;
  final m = (r * tau * 1.2).ceil();
  for (var j = 0; j < m; j++) {
    final ang = (j / m) * tau;
    final ca = math.cos(ang);
    final sa = math.sin(ang);
    if (keep != null && !keep(ang)) continue;
    for (var o = th; o >= 0.0; o -= 0.5) {
      final u = o / th;
      final c = u < 0.15
          ? (hot ? kWhite : rList[n - 1])
          : (u < 0.4
              ? rList[n - 2]
              : (u < 0.7 ? rList[n - 3] : rList[n - 4]));
      p.dot(
        cx + ca * (r - o),
        cy + sa * (r - o) * sy,
        c,
        k * (u < 0.4 ? 1.2 : 1.15 - u),
      );
    }
  }
}

/// A faceted crystal spike standing on (x, base), height [h], base width [w], leaning [lean] px at tip.
void crystal(
  Painter p,
  double x,
  double base,
  double h,
  double w,
  double lean,
  List<Object> rampColors, {
  double a = 1.0,
  bool white = false,
  double glint = -1.0,
}) {
  if (h < 1.5) return;
  final rList = rampColors.map(hex).toList(growable: false);
  final n = rList.length;
  int step(int i) => rList[math.max(0, n - 1 - i)];
  final top = base - h;
  final ridge0 = x - w * 0.14;

  bool inside(int px, int py) {
    final u = (base - (py + 0.5)) / h;
    return u >= 0.0 &&
        u <= 1.0 &&
        (px + 0.5 - (x + lean * u)).abs() <= (w / 2.0) * (1.0 - u) + 0.35;
  }

  final py0 = top.floor() - 1;
  final py1 = base.ceil();
  final px0 = (x - w / 2.0 - lean.abs() - 2.0).floor();
  final px1 = (x + w / 2.0 + lean.abs() + 2.0).ceil();

  for (var py = py0; py < py1; py++) {
    for (var px = px0; px <= px1; px++) {
      if (!inside(px, py)) {
        if (inside(px - 1, py) ||
            inside(px + 1, py) ||
            inside(px, py + 1) ||
            (inside(px, py - 1) && py < base - 1.0)) {
          p.dot(px, py, rList[0], a);
        }
        continue;
      }
      if (white) {
        p.dot(px, py, kWhite, a);
        continue;
      }
      final u = (base - (py + 0.5)) / h;
      final rx = ridge0 + (x + lean - ridge0) * u;
      final c = x + lean * u;
      final hw = (w / 2.0) * (1.0 - u) + 0.35;
      final fx = px + 0.5;
      int col;
      if (u > 0.9) {
        col = kWhite;
      } else if ((fx - rx).abs() < 0.55) {
        col = step(1);
      } else if (fx < rx) {
        if (fx - (c - hw) < 1.0) {
          col = step(1);
        } else {
          col = (fx - (c - hw)) / math.max(1.0, rx - (c - hw)) > 0.55
              ? step(2)
              : step(3);
        }
      } else {
        if (c + hw - fx < 1.2) {
          col = step(math.min(n - 2, 6));
        } else {
          col = (fx - rx) / math.max(1.0, c + hw - rx) > 0.5
              ? step(5)
              : step(4);
        }
      }
      if (glint >= 0.0 && fx <= rx + 0.6) {
        final g = (u - glint).abs();
        if (g < 0.05) {
          col = kWhite;
        } else if (g < 0.1) {
          col = step(1);
        }
      }
      p.dot(px, py, col, a);
    }
  }
}
