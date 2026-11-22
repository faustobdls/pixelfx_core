// Numbers, easing, randomness and noise. Everything here is pure and deterministic,
// so an effect drawn at time t always looks the same across Dart VM, Web JS and Wasm.

import 'dart:math' as math;

const double tau = math.pi * 2.0;

@pragma('vm:prefer-inline')
double clamp(double x, [double a = 0.0, double b = 1.0]) =>
    x < a ? a : (x > b ? b : x);

@pragma('vm:prefer-inline')
int clampInt(int x, int a, int b) => x < a ? a : (x > b ? b : x);

@pragma('vm:prefer-inline')
double lerp(double a, double b, double t) => a + (b - a) * t;

@pragma('vm:prefer-inline')
double invLerp(double a, double b, double x) =>
    b == a ? 0.0 : (x - a) / (b - a);

@pragma('vm:prefer-inline')
double remap(double x, double a0, double a1, double b0, double b1) =>
    lerp(b0, b1, invLerp(a0, a1, x));

@pragma('vm:prefer-inline')
double fract(double x) => x - x.floorToDouble();

@pragma('vm:prefer-inline')
double wrap(double x, double m) => ((x % m) + m) % m;

@pragma('vm:prefer-inline')
int wrapInt(int x, int m) => ((x % m) + m) % m;

/// Progress 0..1 of [t] through the window [t0, t1]: 0 before it, 1 after it.
@pragma('vm:prefer-inline')
double seg(double t, double t0, double t1) => clamp((t - t0) / (t1 - t0));

/// Hermite smoothstep of [x] between [e0] and [e1].
@pragma('vm:prefer-inline')
double smooth(double e0, double e1, double x) {
  final t = seg(x, e0, e1);
  return t * t * (3.0 - 2.0 * t);
}

/// 0 -> 1 -> 0 over the window [t0, t1] (sine bump).
@pragma('vm:prefer-inline')
double bump(double t, double t0, double t1) =>
    (t <= t0 || t >= t1) ? 0.0 : math.sin(math.pi * seg(t, t0, t1));

@pragma('vm:prefer-inline')
double pingpong(double x) => 1.0 - (wrap(x, 2.0) - 1.0).abs();

@pragma('vm:prefer-inline')
double hypot(double dx, double dy) => math.sqrt(dx * dx + dy * dy);

@pragma('vm:prefer-inline')
double dist(double x0, double y0, double x1, double y1) =>
    hypot(x1 - x0, y1 - y0);

@pragma('vm:prefer-inline')
double angleTo(double x0, double y0, double x1, double y1) =>
    math.atan2(y1 - y0, x1 - x0);

/// Easing curves: input 0..1, output 0..1 (back and elastic overshoot).
abstract final class Ease {
  static double linear(double t) => t;
  static double inQuad(double t) => t * t;
  static double outQuad(double t) => 1.0 - (1.0 - t) * (1.0 - t);
  static double inOutQuad(double t) =>
      t < 0.5 ? 2.0 * t * t : 1.0 - math.pow(-2.0 * t + 2.0, 2) / 2.0;
  static double inCubic(double t) => t * t * t;
  static double outCubic(double t) => 1.0 - math.pow(1.0 - t, 3);
  static double inOutCubic(double t) =>
      t < 0.5 ? 4.0 * t * t * t : 1.0 - math.pow(-2.0 * t + 2.0, 3) / 2.0;
  static double inQuart(double t) => t * t * t * t;
  static double outQuart(double t) => 1.0 - math.pow(1.0 - t, 4);
  static double inExpo(double t) =>
      t <= 0.0 ? 0.0 : math.pow(2.0, 10.0 * t - 10.0).toDouble();
  static double outExpo(double t) =>
      t >= 1.0 ? 1.0 : 1.0 - math.pow(2.0, -10.0 * t).toDouble();
  static double inSine(double t) => 1.0 - math.cos((t * math.pi) / 2.0);
  static double outSine(double t) => math.sin((t * math.pi) / 2.0);
  static double inOutSine(double t) => -(math.cos(math.pi * t) - 1.0) / 2.0;

  static double inBack(double t, [double s = 1.70158]) => t <= 0.0
      ? 0.0
      : t >= 1.0
          ? 1.0
          : (s + 1.0) * t * t * t - s * t * t;

  static double outBack(double t, [double s = 1.70158]) => t <= 0.0
      ? 0.0
      : t >= 1.0
          ? 1.0
          : 1.0 +
              (s + 1.0) * math.pow(t - 1.0, 3) +
              s * math.pow(t - 1.0, 2);

  static double outElastic(double t) => t <= 0.0
      ? 0.0
      : t >= 1.0
          ? 1.0
          : math.pow(2.0, -10.0 * t) *
                  math.sin((t * 10.0 - 0.75) * (tau / 3.0)) +
              1.0;

  static double outBounce(double t) {
    const n = 7.5625;
    const d = 2.75;
    if (t < 1.0 / d) return n * t * t;
    if (t < 2.0 / d) {
      final u = t - 1.5 / d;
      return n * u * u + 0.75;
    }
    if (t < 2.5 / d) {
      final u = t - 2.25 / d;
      return n * u * u + 0.9375;
    }
    final u = t - 2.625 / d;
    return n * u * u + 0.984375;
  }
}

/// 32-bit unsigned integer multiplication identical to JS `Math.imul(...) >>> 0`,
/// safe across 64-bit Dart VM and 53-bit double Dart Web/JS.
@pragma('vm:prefer-inline')
int mul32(int a, int b) {
  final aLo = a & 0xffff;
  final aHi = (a >>> 16) & 0xffff;
  final bLo = b & 0xffff;
  final bHi = (b >>> 16) & 0xffff;
  return ((aLo * bLo) + (((aHi * bLo + aLo * bHi) & 0xffff) << 16)) & 0xffffffff;
}

@pragma('vm:prefer-inline')
int u32(int x) => x & 0xffffffff;

@pragma('vm:prefer-inline')
int _hashStep(int h, int n) {
  var out = mul32(h ^ (n & 0xffffffff), 0x85ebca6b);
  out ^= out >>> 13;
  out = mul32(out, 0xc2b2ae35);
  out ^= out >>> 16;
  return out & 0xffffffff;
}

/// 32-bit integer hash of a list of integers.
int hashInts(List<int> ns) {
  var h = 0x9e3779b9;
  for (var i = 0; i < ns.length; i++) {
    h = _hashStep(h, ns[i]);
  }
  return h & 0xffffffff;
}

@pragma('vm:prefer-inline')
int hash1(int a) => _hashStep(0x9e3779b9, a);

@pragma('vm:prefer-inline')
int hash2(int a, int b) => _hashStep(_hashStep(0x9e3779b9, a), b);

@pragma('vm:prefer-inline')
int hash3(int a, int b, int c) =>
    _hashStep(_hashStep(_hashStep(0x9e3779b9, a), b), c);

@pragma('vm:prefer-inline')
int hash4(int a, int b, int c, int d) =>
    _hashStep(_hashStep(_hashStep(_hashStep(0x9e3779b9, a), b), c), d);

/// Deterministic random number in [0, 1) from integers (up to 4 without List allocation).
@pragma('vm:prefer-inline')
double rand(int a, [int? b, int? c, int? d]) {
  var h = _hashStep(0x9e3779b9, a);
  if (b != null) h = _hashStep(h, b);
  if (c != null) h = _hashStep(h, c);
  if (d != null) h = _hashStep(h, d);
  return (h & 0xffffffff) / 4294967296.0;
}

/// Deterministic random number in [0, 1) from an arbitrary integer list.
double randInts(List<int> ns) => hashInts(ns) / 4294967296.0;

/// Seeded random generator (mulberry32), bit-identical to pixelfx JS.
class Rng {
  int _s;

  Rng([int seed = 1]) : _s = (seed & 0xffffffff) == 0 ? 1 : (seed & 0xffffffff);

  int get state => _s;

  double next() {
    _s = (_s + 0x6d2b79f5) & 0xffffffff;
    var t = _s;
    t = mul32(t ^ (t >>> 15), t | 1);
    t = (t ^ ((t + mul32(t ^ (t >>> 7), t | 61)) & 0xffffffff)) & 0xffffffff;
    return ((t ^ (t >>> 14)) & 0xffffffff) / 4294967296.0;
  }

  double range(double a, double b) => a + (b - a) * next();

  int intRange(int a, int b) => range(a.toDouble(), b + 1.0).floor();

  bool chance(double p) => next() < p;

  int sign() => next() < 0.5 ? -1 : 1;

  T pick<T>(List<T> list) => list[(next() * list.length).floor()];

  /// Roughly normal, mean 0, sd 1.
  double gauss() => (next() + next() + next() + next() - 2.0) * 1.732;
}

/// A generator for one particle: `rng(seed, i)` gives the same numbers every frame.
Rng rng(int a, [int? b, int? c, int? d]) {
  var h = _hashStep(0x9e3779b9, a);
  if (b != null) h = _hashStep(h, b);
  if (c != null) h = _hashStep(h, c);
  if (d != null) h = _hashStep(h, d);
  return Rng(h);
}

Rng rngInts(List<int> ns) => Rng(hashInts(ns));

/// Smooth 1D value noise in [-1, 1].
double noise(double x, [int seed = 0]) {
  final i = x.floor();
  final f = x - i;
  final u = f * f * (3.0 - 2.0 * f);
  return lerp(rand(i, seed), rand(i + 1, seed), u) * 2.0 - 1.0;
}

/// Smooth 2D value noise in [-1, 1].
double noise2(double x, double y, [int seed = 0]) {
  final ix = x.floor();
  final iy = y.floor();
  final fx = x - ix;
  final fy = y - iy;
  final ux = fx * fx * (3.0 - 2.0 * fx);
  final uy = fy * fy * (3.0 - 2.0 * fy);
  final a = rand(ix, iy, seed);
  final b = rand(ix + 1, iy, seed);
  final c = rand(ix, iy + 1, seed);
  final d = rand(ix + 1, iy + 1, seed);
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uy) * 2.0 - 1.0;
}

/// Fractal 2D noise in about [-1, 1].
double fbm(double x, double y, [int seed = 0, int octaves = 3]) {
  var s = 0.0;
  var a = 0.5;
  var n = 0.0;
  var xx = x;
  var yy = y;
  for (var o = 0; o < octaves; o++) {
    s += noise2(xx, yy, seed + o * 101) * a;
    n += a;
    xx *= 2.03;
    yy *= 2.03;
    a *= 0.5;
  }
  return s / n;
}

/// 2D value noise whose lattice repeats every [px] cells in x and [py] cells in y (0: no repeat).
double tileNoise(double x, double y, [int px = 0, int py = 0, int seed = 0]) {
  final ix = x.floor();
  final iy = y.floor();
  final fx = x - ix;
  final fy = y - iy;
  final ux = fx * fx * (3.0 - 2.0 * fx);
  final uy = fy * fy * (3.0 - 2.0 * fy);
  final x0 = px != 0 ? wrapInt(ix, px) : ix;
  final x1 = px != 0 ? wrapInt(ix + 1, px) : ix + 1;
  final y0 = py != 0 ? wrapInt(iy, py) : iy;
  final y1 = py != 0 ? wrapInt(iy + 1, py) : iy + 1;
  final a = rand(x0, y0, seed);
  final b = rand(x1, y0, seed);
  final c = rand(x0, y1, seed);
  final d = rand(x1, y1, seed);
  return lerp(lerp(a, b, ux), lerp(c, d, ux), uy) * 2.0 - 1.0;
}

/// Fractal [tileNoise]: every octave keeps the repeat, so scrolled fields still loop.
double tileFbm(
  double x,
  double y, [
  int px = 0,
  int py = 0,
  int seed = 0,
  int octaves = 3,
]) {
  var s = 0.0;
  var a = 0.5;
  var n = 0.0;
  var k = 1;
  for (var o = 0; o < octaves; o++) {
    s += tileNoise(x * k, y * k, px * k, py * k, seed + o * 101) * a;
    n += a;
    a *= 0.5;
    k *= 2;
  }
  return s / n;
}

/// Noise that loops: the same value at phase 0 and phase 1 (for seamless loops).
double loopNoise(double phase, [double radius = 1.0, int seed = 0]) {
  final a = phase * tau;
  return noise2(
    math.cos(a) * radius + 50.0,
    math.sin(a) * radius + 50.0,
    seed,
  );
}
