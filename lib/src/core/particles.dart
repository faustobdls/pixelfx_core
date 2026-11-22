// Particles without a simulation: closed-form functions of age so an effect
// can be drawn at any time t, scrubbed, looped and rendered frame by frame.

import 'dart:math' as math;

import 'math.dart';

typedef Point2 = (double x, double y);

/// Where a particle is after [t] seconds, launched from (x, y) at (vx, vy) px/s,
/// under gravity [g] (px/s^2, positive is down) and linear [drag] (1/s).
Point2 fly(
  double x,
  double y,
  double vx,
  double vy,
  double t, [
  double g = 0.0,
  double drag = 0.0,
]) {
  if (drag <= 0.0) {
    return (x + vx * t, y + vy * t + 0.5 * g * t * t);
  }
  final f = (1.0 - math.exp(-drag * t)) / drag;
  final vt = g / drag;
  return (x + vx * f, y + vt * t + (vy - vt) * f);
}

/// Its velocity at [t], for streaks that point along the motion.
Point2 flyV(
  double vx,
  double vy,
  double t, [
  double g = 0.0,
  double drag = 0.0,
]) {
  if (drag <= 0.0) return (vx, vy + g * t);
  final e = math.exp(-drag * t);
  final vt = g / drag;
  return (vx * e, vt + (vy - vt) * e);
}

/// [n] one-shot particles: [fn] gets a repeatable [Rng] per particle.
void burst(int n, int seed, void Function(Rng r, int i) fn) {
  for (var i = 0; i < n; i++) {
    fn(rng(seed, i), i);
  }
}

/// Particles that repeat every [period] seconds, for loops with no seam.
void cycle(
  double t,
  double period,
  int count,
  int seed,
  double Function(Rng r) life,
  void Function(double age, double life, Rng r, int i) fn,
) {
  for (var i = 0; i < count; i++) {
    final g = rng(seed, i, 911);
    final born = g.next() * period;
    final lifeVal = life(g);
    var age = (((t - born) % period) + period) % period;
    for (; age < lifeVal; age += period) {
      fn(age, lifeVal, rng(seed, i), i);
    }
  }
}

/// Convenience overload with a fixed [life] duration.
void cycleFixed(
  double t,
  double period,
  int count,
  int seed,
  double life,
  void Function(double age, double life, Rng r, int i) fn,
) =>
    cycle(t, period, count, seed, (_) => life, fn);

/// Particles born at a steady [rate] (per second) between [t0] and [t1].
void stream(
  double t,
  double t0,
  double t1,
  double rate,
  int seed,
  double Function(Rng r) life,
  void Function(double age, double life, Rng r, int i) fn,
) {
  final n = ((math.min(t, t1) - t0) * rate).floor();
  for (var i = 0; i <= n; i++) {
    final born = t0 + i / rate;
    final g = rng(seed, i, 911);
    final lifeVal = life(g);
    final age = t - born;
    if (age >= 0.0 && age < lifeVal) {
      fn(age, lifeVal, rng(seed, i), i);
    }
  }
}

class SimpleParticle {
  double x;
  double y;
  double vx;
  double vy;
  double life;
  double g;
  double drag;
  double? ground;
  double bounce;
  double age = 0.0;
  Object? tag;

  SimpleParticle({
    required this.x,
    required this.y,
    required this.vx,
    required this.vy,
    required this.life,
    this.g = 0.0,
    this.drag = 0.0,
    this.ground,
    this.bounce = 0.3,
    this.tag,
  });

  double get k => clamp(1.0 - age / life);
}

/// Simple simulated particle list for effects that export `create()` and keep state.
class SimpleParticles {
  final List<SimpleParticle> list = [];

  SimpleParticle add(SimpleParticle p) {
    p.age = 0.0;
    list.add(p);
    return p;
  }

  void update(double dt) {
    for (var i = list.length - 1; i >= 0; i--) {
      final p = list[i];
      p.age += dt;
      if (p.age >= p.life) {
        list.removeAt(i);
        continue;
      }
      p.vx -= p.vx * p.drag * dt;
      p.vy += p.g * dt - p.vy * p.drag * dt;
      p.x += p.vx * dt;
      p.y += p.vy * dt;
      final floorY = p.ground;
      if (floorY != null && p.y > floorY) {
        p.y = floorY;
        p.vy = -p.vy.abs() * p.bounce;
        p.vx *= 0.7;
      }
    }
  }
}
