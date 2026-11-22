// The character who acts: a real 3D skeleton rasterized down to pixels with flat tones and
// one clean ink line, the way Dead Cells makes its sprites. Bones have fixed lengths;
// depth decides what is in front; every rendered pixel tracks its standing-body origin (`src`).

import 'dart:math' as math;
import 'dart:typed_data';

import 'actor.dart';
import 'color.dart';
import 'poses.dart';

typedef Vec3 = (double x, double y, double z);
typedef Mat3 = List<double>; // length 9, row-major

const double _deg = math.pi / 180.0;

/// Classic 2:1 dimetric isometric camera pitch (`atan(0.5)` ≈ 26.565 deg).
const double kIsoCameraPitch = 0.4636476090008061;
const int _w0 = 24;
const int _h0 = 38;

@pragma('vm:prefer-inline')
Vec3 _add(Vec3 a, Vec3 b) => (a.$1 + b.$1, a.$2 + b.$2, a.$3 + b.$3);

@pragma('vm:prefer-inline')
Vec3 _sub(Vec3 a, Vec3 b) => (a.$1 - b.$1, a.$2 - b.$2, a.$3 - b.$3);

@pragma('vm:prefer-inline')
Vec3 _mul(Vec3 a, double s) => (a.$1 * s, a.$2 * s, a.$3 * s);

@pragma('vm:prefer-inline')
double _dot(Vec3 a, Vec3 b) => a.$1 * b.$1 + a.$2 * b.$2 + a.$3 * b.$3;

@pragma('vm:prefer-inline')
Vec3 _cross(Vec3 a, Vec3 b) => (
      a.$2 * b.$3 - a.$3 * b.$2,
      a.$3 * b.$1 - a.$1 * b.$3,
      a.$1 * b.$2 - a.$2 * b.$1,
    );

@pragma('vm:prefer-inline')
double _len(Vec3 a) => math.sqrt(a.$1 * a.$1 + a.$2 * a.$2 + a.$3 * a.$3);

@pragma('vm:prefer-inline')
Vec3 _unit(Vec3 a) {
  final l = _len(a);
  return _mul(a, 1.0 / (l == 0.0 ? 1e-6 : l));
}

Mat3 _rotX(double t) {
  final c = math.cos(t);
  final s = math.sin(t);
  return [1, 0, 0, 0, c, -s, 0, s, c];
}

Mat3 _rotY(double t) {
  final c = math.cos(t);
  final s = math.sin(t);
  return [c, 0, s, 0, 1, 0, -s, 0, c];
}

Mat3 _rotZ(double t) {
  final c = math.cos(t);
  final s = math.sin(t);
  return [c, -s, 0, s, c, 0, 0, 0, 1];
}

Mat3 _mm(Mat3 a, Mat3 b) {
  final o = List<double>.filled(9, 0.0);
  for (var r = 0; r < 3; r++) {
    for (var c = 0; c < 3; c++) {
      o[r * 3 + c] = a[r * 3] * b[c] +
          a[r * 3 + 1] * b[3 + c] +
          a[r * 3 + 2] * b[6 + c];
    }
  }
  return o;
}

Vec3 _mv(Mat3 m, Vec3 v) => (
      m[0] * v.$1 + m[1] * v.$2 + m[2] * v.$3,
      m[3] * v.$1 + m[4] * v.$2 + m[5] * v.$3,
      m[6] * v.$1 + m[7] * v.$2 + m[8] * v.$3,
    );

Vec3 _tv(Mat3 m, Vec3 v) => (
      m[0] * v.$1 + m[3] * v.$2 + m[6] * v.$3,
      m[1] * v.$1 + m[4] * v.$2 + m[7] * v.$3,
      m[2] * v.$1 + m[5] * v.$2 + m[8] * v.$3,
    );

double _clamp01(double v) => v < 0.0 ? 0.0 : (v > 1.0 ? 1.0 : v);

// Body measurements in pixels
abstract final class _Measurements {
  static const double pelvis = 19.7;
  static const double spine1 = 2.8;
  static const double spine2 = 4.6;
  static const double shoulderUp = 2.5;
  static const double shoulderOut = 5.9;
  static const double neckUp = 4.0;
  static const double headUp = 3.1;
  static const double hipDown = 1.1;
  static const double hipOut = 2.8;
  static const double thigh = 8.6;
  static const double shin = 8.3;
  static const double upper = 7.6;
  static const double fore = 7.4;
  static const double turn = 36.0 * _deg;
}

class _IkResult {
  Vec3 joint;
  Vec3 end;
  final Vec3 u;
  final Vec3 v;

  _IkResult(this.joint, this.end, this.u, this.v);
}

_IkResult _ik(Vec3 a, Vec3 target, double l1, double l2, Vec3 pole) {
  var to = _sub(target, a);
  var d = _len(to);
  final reach = l1 + l2 - 0.02;
  if (d > reach) {
    to = _mul(to, reach / d);
    d = reach;
  }
  final u = _unit(to);
  final along = (l1 * l1 - l2 * l2 + d * d) / (2.0 * (d == 0.0 ? 1e-6 : d));
  final h = math.sqrt(math.max(0.0, l1 * l1 - along * along));
  var v = _sub(pole, _mul(u, _dot(pole, u)));
  v = _len(v) < 1e-4 ? _unit(_cross(u, (0.0, 0.0, 1.0))) : _unit(v);
  return _IkResult(
    _add(a, _add(_mul(u, along), _mul(v, h))),
    _add(a, to),
    u,
    v,
  );
}

class BoneFrame {
  Vec3 t;
  Mat3 r;

  BoneFrame(this.t, this.r);
}

BoneFrame _boneFrame(Vec3 a, Vec3 b, Vec3 pole) {
  final x = _unit(_sub(b, a));
  var y = _sub(pole, _mul(x, _dot(pole, x)));
  y = _len(y) < 1e-4 ? _unit(_cross(x, (0.0, 0.0, 1.0))) : _unit(y);
  final z = _cross(x, y);
  return BoneFrame(a, [x.$1, y.$1, z.$1, x.$2, y.$2, z.$2, x.$3, y.$3, z.$3]);
}

/// Callback interface passed to `WeaponSpec.draw`, keeping custom weapons ergonomic and fast.
abstract interface class WeaponPlotter {
  void call(double i, double k, int color, [double lift = 0.0]);
  Vec3 at(double i, double k);
  void plotPoint(Vec3 point, int color);
}

class WeaponSpec {
  final double? twoHandOffset;
  final bool across;
  final void Function(WeaponPlotter t, Pose q, Vec3 offHand) draw;

  const WeaponSpec({
    this.twoHandOffset,
    this.across = false,
    required this.draw,
  });
}

/// Extensible weapon registry. Starts with the 11 upstream weapons and accepts new ones from extensions.
class WeaponRegistry {
  final Map<String, WeaponSpec> _weapons = {};

  WeaponRegistry({bool includeBuiltIns = true}) {
    if (includeBuiltIns) _registerBuiltIns();
  }

  void register(String name, WeaponSpec spec) {
    _weapons[name] = spec;
  }

  void registerAll(Map<String, WeaponSpec> specs) {
    _weapons.addAll(specs);
  }

  WeaponSpec? operator [](String? name) => name == null ? null : _weapons[name];

  Iterable<String> get names => _weapons.keys;

  static final WeaponRegistry instance = WeaponRegistry();

  void _registerBuiltIns() {
    final s = _SteelPalette();

    void blade(WeaponPlotter t, double from, double length, double w) {
      for (var i = from; i <= from + length + 0.01; i += 0.4) {
        final r = i - from;
        final wd =
            r > length - 5.0 ? math.max(0.0, ((length - r) / 5.0) * w) : w;
        for (var k = -wd; k <= wd + 0.01; k += 0.4) {
          t(i, k, k < -w * 0.4 ? s.hi : (k > w * 0.4 ? s.d : s.a));
        }
      }
    }

    void haft(
      WeaponPlotter t,
      double from,
      double to,
      int a,
      int d, [
      double r = 0.8,
    ]) {
      for (var i = from; i <= to; i += 0.4) {
        for (var k = -r; k <= r + 0.01; k += 0.4) {
          t(i, k, k > 0.1 ? d : a);
        }
      }
    }

    register(
      'sword',
      WeaponSpec(
        twoHandOffset: -4.4,
        draw: (t, q, _) {
          final end = q.two == true ? -6.5 : -2.6;
          haft(t, end, 2.2, s.grip, s.gripD);
          for (var k = -1.4; k <= 1.4; k += 0.4) {
            t(end - 0.4, k, s.gold);
          }
          for (var k = -4.6; k <= 4.6; k += 0.4) {
            t(2.6, k, k.abs() > 3.8 ? s.goldD : s.gold);
            t(3.0, k, s.goldD);
          }
          blade(t, 3.2, 25.0, 2.2);
        },
      ),
    );

    register(
      'greatsword',
      WeaponSpec(
        twoHandOffset: -4.8,
        draw: (t, _, _) {
          haft(t, -7.2, 2.2, s.grip, s.gripD);
          for (var k = -1.8; k <= 1.8; k += 0.4) {
            t(-7.6, k, s.gold);
          }
          for (var k = -6.6; k <= 6.6; k += 0.4) {
            t(2.6, k, k.abs() > 5.6 ? s.goldD : s.gold);
            t(3.0, k, s.goldD);
          }
          blade(t, 3.2, 31.0, 3.0);
          for (var i = 4.0; i <= 28.0; i += 0.4) {
            t(i, 0.0, s.b);
          }
        },
      ),
    );

    register(
      'dagger',
      WeaponSpec(
        draw: (t, _, _) {
          haft(t, -2.4, 1.8, s.grip, s.gripD);
          for (var k = -2.6; k <= 2.6; k += 0.4) {
            t(2.2, k, s.goldD);
          }
          blade(t, 2.6, 10.0, 1.3);
        },
      ),
    );

    register(
      'spear',
      WeaponSpec(
        twoHandOffset: -12.0,
        draw: (t, _, _) {
          haft(t, -18.0, 36.0, s.wood, s.woodD, 0.5);
          blade(t, 36.0, 11.0, 2.0);
          for (var k = -2.4; k <= 2.4; k += 0.4) {
            t(36.0, k, s.goldD);
          }
        },
      ),
    );

    register(
      'hammer',
      WeaponSpec(
        twoHandOffset: -7.0,
        draw: (t, _, _) {
          for (final lift in [-0.8, 0.0, 0.8]) {
            for (var i = -10.0; i <= 18.0; i += 0.4) {
              for (var k = -0.8; k <= 0.81; k += 0.4) {
                t(i, k, k > 0.1 ? s.woodD : s.wood, lift);
              }
            }
          }
          for (var i = 18.0; i <= 28.0; i += 0.4) {
            for (var k = -9.0; k <= 9.0; k += 0.4) {
              final face = k.abs() > 7.4
                  ? (k < 0.0 ? s.a : s.d)
                  : (i < 20.0
                      ? s.hi
                      : (i > 26.4
                          ? s.d
                          : (k.abs() < 2.0 ? s.gold : s.b)));
              t(i, k, face, 4.5);
              t(i, k, face, -4.5);
              if (i < 18.4 || i > 27.6 || k.abs() > 8.6) {
                for (var l = -4.0; l <= 4.0; l += 0.4) {
                  t(i, k, k < 0.0 ? s.a : (i > 27.6 ? s.d : s.b), l);
                }
              }
            }
          }
        },
      ),
    );

    register(
      'scythe',
      WeaponSpec(
        twoHandOffset: -11.0,
        draw: (t, _, _) {
          haft(t, -16.0, 31.0, s.dark, s.darkD, 0.5);
          for (var j = 0.0; j <= 28.0; j += 0.4) {
            final u = j / 28.0;
            final w = 3.2 * (1.0 - u) + 0.3;
            final b = 31.5 - u * u * 12.0;
            for (var k = -w; k <= w; k += 0.4) {
              t(b + k, j + 0.8, k > w * 0.3 ? s.hi : (k < -w * 0.4 ? s.d : s.b));
            }
          }
        },
      ),
    );

    register(
      'claw',
      WeaponSpec(
        draw: (t, _, _) {
          for (final q0 in [-2.4, 0.0, 2.4]) {
            for (var i = 2.0; i <= 9.5; i += 0.4) {
              final u = (i - 2.0) / 7.5;
              final k = q0 + u * u * 1.8;
              t(i, k, u > 0.55 ? s.hi : s.a);
              if (u < 0.6) t(i, k + 0.8, s.d);
            }
          }
        },
      ),
    );

    register(
      'bow',
      WeaponSpec(
        across: true,
        draw: (t, q, off) {
          for (var u = -1.0; u <= 1.001; u += 0.025) {
            final k = u * 17.0;
            final i = 6.0 * (1.0 - u * u) - 1.0;
            t(i, k, u.abs() > 0.85 ? s.goldD : s.wood);
            t(i + 0.8, k, s.woodD);
          }
          final tipA = t.at(-1.0, -17.0);
          final tipB = t.at(-1.0, 17.0);
          final mid = q.pull == true ? off : t.at(-1.0, 0.0);
          void drawLine(Vec3 a, Vec3 b, [int? c]) {
            final n = math.max(2, (_len(_sub(b, a)) / 0.4).ceil());
            for (var k = 0; k <= n; k++) {
              final pt = _add(a, _mul(_sub(b, a), k / n));
              t.plotPoint(pt, c ?? s.a);
            }
          }
          drawLine(tipA, mid);
          drawLine(tipB, mid);
          if (q.nocked == true) {
            final tip = t.at(13.0, 0.0);
            drawLine(mid, tip, s.wood);
            for (var i = 9.0; i <= 13.0; i += 0.4) {
              for (var k = -(13.0 - i) * 0.45; k <= (13.0 - i) * 0.45; k += 0.4) {
                t(i, k, s.hi);
              }
            }
          }
        },
      ),
    );

    register(
      'pistol',
      WeaponSpec(
        across: true,
        draw: (t, _, _) {
          for (var i = -1.0; i <= 9.5; i += 0.4) {
            for (var k = -4.2; k <= -2.4; k += 0.4) {
              t(i, k, k < -3.6 ? s.a : (k > -2.9 ? s.d : s.b));
            }
          }
          for (var i = -1.2; i <= 1.2; i += 0.4) {
            for (var k = -2.4; k <= 2.4; k += 0.4) {
              t(i, k, s.gripD);
            }
          }
          t(9.0, -4.6, s.hi);
        },
      ),
    );

    register(
      'launcher',
      WeaponSpec(
        twoHandOffset: -9.0,
        draw: (t, _, _) {
          for (var i = -14.0; i <= 22.0; i += 0.4) {
            for (var k = -6.0; k <= -1.0; k += 0.4) {
              t(
                i,
                k,
                k < -4.8
                    ? s.oliveA
                    : (k > -2.2
                        ? s.oliveD
                        : ((i - 3.0).abs() < 1.4 ? s.gold : s.olive)),
              );
            }
          }
          for (var k = -6.8; k <= -0.2; k += 0.4) {
            t(22.4, k, s.b);
            t(-14.4, k, s.d);
          }
        },
      ),
    );

    register(
      'handle',
      WeaponSpec(
        draw: (t, _, _) {
          haft(t, -2.6, 6.0, s.grip, s.gripD);
          for (var k = -1.6; k <= 1.6; k += 0.4) {
            t(-3.0, k, s.gold);
            t(6.4, k, s.gold);
          }
        },
      ),
    );
  }
}

class _SteelPalette {
  final int hi = hex('#ffffff');
  final int a = hex('#e8edf6');
  final int b = hex('#a4afc6');
  final int d = hex('#68748f');
  final int gold = hex('#ffd84a');
  final int goldD = hex('#b8862a');
  final int grip = hex('#7a3a2a');
  final int gripD = hex('#4a2018');
  final int wood = hex('#8a5a32');
  final int woodD = hex('#5a3820');
  final int dark = hex('#3a3448');
  final int darkD = hex('#262033');
  final int olive = hex('#58663f');
  final int oliveA = hex('#7d8c58');
  final int oliveD = hex('#3a4529');
}

class _SolvedSkeleton {
  final Map<String, BoneFrame> b;
  final WeaponSpec? w;
  final WeaponSpec? ow;
  final Pose q;
  Vec3 axis;
  Vec3 side;
  final _IkResult armN;
  final _IkResult armF;
  final _IkResult legN;
  final _IkResult legF;
  Vec3 sN;
  Vec3 sF;
  Vec3 hipN;
  Vec3 hipF;
  final double turn;

  _SolvedSkeleton({
    required this.b,
    required this.w,
    required this.ow,
    required this.q,
    required this.axis,
    required this.side,
    required this.armN,
    required this.armF,
    required this.legN,
    required this.legF,
    required this.sN,
    required this.sF,
    required this.hipN,
    required this.hipF,
    required this.turn,
  });
}

_SolvedSkeleton _solve(Pose pose, WeaponRegistry weapons) {
  final q = kStand.merge(pose);
  final lean = q.lean ?? 0.0;
  final wSpec = weapons[q.weapon];
  final owSpec = weapons[q.offWeapon];
  final sa = q.sa ?? 0.0;
  final wl = q.wl ?? 1.0;
  final axisZ = math.sqrt(math.max(0.0, 1.0 - wl * wl)) * (q.wz ?? 1.0);
  final axis = (math.cos(sa) * wl, -math.sin(sa) * wl, axisZ);
  final side = (-math.sin(sa), -math.cos(sa), 0.0);
  final two = q.two == true && wSpec != null;
  final nearZ = q.fz ?? (two ? 3.0 : 4.5);

  final fwd = ((q.fx ?? kStand.fx!) - kStand.fx!) / 24.0;
  final farFwd = two ? 0.0 : ((q.bx ?? kStand.bx!) - kStand.bx!) / 22.0;
  var turn = _Measurements.turn +
      (fwd >= 0.0
          ? -44.0 * _deg * math.min(1.0, fwd)
          : 28.0 * _deg * math.min(1.0, -fwd * 1.8));
  turn += (farFwd > 0.0 ? 34.0 * _deg * math.min(1.0, farFwd) : 0.0) +
      (q.twist ?? 0.0) * 4.0 * _deg;
  if (q.turn != null) turn = q.turn!;

  final hipTurn = _Measurements.turn + (turn - _Measurements.turn) * 0.45;
  final tilt = math.atan2(lean, 13.0);
  final rp = _mm(_rotZ(-tilt * 0.25), _rotY(-hipTurn));
  final rc = _mm(_rotZ(-tilt), _rotY(-turn));

  final ankleN = (q.ffx!, -q.ffy! - 1.8, q.fzz ?? 2.4);
  final ankleF = (q.fbx!, -q.fby! - 1.8, q.bzz ?? -2.4);
  var pelvis = (lean * 0.2, _Measurements.pelvis - (q.crouch ?? 0.0), 0.0);
  Vec3 hipAt(double s) =>
      _add(pelvis, _mv(rp, (0.0, -_Measurements.hipDown, s * _Measurements.hipOut)));
  const maxLeg = (_Measurements.thigh + _Measurements.shin) * 0.995;
  for (final (s, a) in [(1.0, ankleN), (-1.0, ankleF)]) {
    final h = hipAt(s);
    final dx = h.$1 - a.$1;
    final dz = h.$3 - a.$3;
    final flat = dx * dx + dz * dz;
    if (flat < maxLeg * maxLeg) {
      final top = a.$2 + math.sqrt(maxLeg * maxLeg - flat);
      if (h.$2 > top) pelvis = (pelvis.$1, pelvis.$2 - (h.$2 - top), pelvis.$3);
    }
  }
  final waist = _add(
    pelvis,
    (
      math.sin(tilt * 0.45) * _Measurements.spine1,
      math.cos(tilt * 0.45) * _Measurements.spine1,
      0.0,
    ),
  );
  final chest = _add(
    waist,
    (
      math.sin(tilt) * _Measurements.spine2,
      math.cos(tilt) * _Measurements.spine2,
      0.0,
    ),
  );
  final neck = _add(chest, _mv(rc, (0.0, _Measurements.neckUp, 0.0)));
  final headTurn = _Measurements.turn * 0.9 + (turn - _Measurements.turn) * 0.35;
  final nod = tilt * 0.35 + (q.hy ?? 0.0) * 7.0 * _deg;
  final roll = (q.hx ?? 0.0) * 7.0 * _deg;
  final rh = _mm(_rotZ(-nod - roll), _rotY(-headTurn));
  final head = _add(neck, _mv(rh, (0.15, _Measurements.headUp, 0.0)));

  Vec3 pickShoulder(double s, Vec3 target) {
    final base = _add(
      chest,
      _mv(rc, (0.0, _Measurements.shoulderUp, s * _Measurements.shoulderOut)),
    );
    final to = _sub(target, base);
    final d = _len(to);
    return _add(base, _mul(_unit(to), math.min(1.8, math.max(0.0, d - 11.0) * 0.35)));
  }

  final nearT = (q.fx!, -q.fy!, nearZ);
  final twoOff = wSpec?.twoHandOffset ?? 0.0;
  final farT = two
      ? (
          q.fx! + axis.$1 * twoOff,
          -q.fy! + axis.$2 * twoOff,
          nearZ + axis.$3 * twoOff,
        )
      : (
          q.bx!,
          -q.by!,
          q.bz ?? (q.armsFront == true ? 5.5 : -4.5),
        );
  final sN = pickShoulder(1.0, nearT);
  final sF = pickShoulder(-1.0, farT);

  Vec3 pole(double s, Vec3 t, Vec3 shoulder, Vec3? hold) {
    final up = _clamp01((t.$2 - shoulder.$2 + 2.0) / 10.0);
    final base = (-0.55 + up * 1.1, -1.0 + up * 0.9, s * (0.45 + up * 0.5));
    if (hold == null) return base;
    final u = _unit(_sub(t, shoulder));
    var best = base;
    var score = double.infinity;
    for (var i = 0; i < 16; i++) {
      final a = (i / 16.0) * math.pi * 2.0;
      final x = _unit(_cross(u, (0.3, 1.0, 0.2)));
      final y = _cross(u, x);
      final v = _add(_mul(x, math.cos(a)), _mul(y, math.sin(a)));
      final ikRes =
          _ik(shoulder, t, _Measurements.upper, _Measurements.fore, v);
      final f = _unit(_sub(ikRes.end, ikRes.joint));
      final cost = _dot(f, hold).abs() * 0.7 +
          (1.0 - _dot(_unit(base), v)) * 0.55;
      if (cost < score) {
        score = cost;
        best = v;
      }
    }
    return best;
  }

  final holdN = wSpec != null ? (wSpec.across ? side : axis) : null;
  final holdF = two
      ? (wSpec.across ? side : axis)
      : (owSpec != null
          ? (math.cos(q.sb ?? math.pi), -math.sin(q.sb ?? math.pi), 0.0)
          : null);
  final armN = _ik(
      sN, nearT, _Measurements.upper, _Measurements.fore, pole(1.0, nearT, sN, holdN));
  final armF = _ik(
      sF, farT, _Measurements.upper, _Measurements.fore, pole(-1.0, farT, sF, holdF));

  Vec3 kneePole(double s) => _mv(rp, (1.0, 0.0, s * 0.35));
  final hipN = hipAt(1.0);
  final hipF = hipAt(-1.0);
  final legN =
      _ik(hipN, ankleN, _Measurements.thigh, _Measurements.shin, kneePole(1.0));
  final legF =
      _ik(hipF, ankleF, _Measurements.thigh, _Measurements.shin, kneePole(-1.0));

  Vec3 footDir(double s) {
    final t = hipTurn * 0.6 + s * 8.0 * _deg;
    return (math.cos(t), 0.0, math.sin(t));
  }

  final fd1 = footDir(1.0);
  final fd2 = footDir(-1.0);
  final b = <String, BoneFrame>{
    'pelvis': BoneFrame(pelvis, rp),
    'waist': BoneFrame(
        waist, _mm(_rotZ(-tilt * 0.6), _rotY(-(turn + hipTurn) / 2.0))),
    'chest': BoneFrame(chest, rc),
    'head': BoneFrame(head, rh),
    'neck': BoneFrame(neck, rh),
    'upperN': _boneFrame(sN, armN.joint, armN.v),
    'foreN': _boneFrame(armN.joint, armN.end, armN.v),
    'upperF': _boneFrame(sF, armF.joint, armF.v),
    'foreF': _boneFrame(armF.joint, armF.end, armF.v),
    'thighN': _boneFrame(hipN, legN.joint, legN.v),
    'shinN': _boneFrame(legN.joint, legN.end, legN.v),
    'thighF': _boneFrame(hipF, legF.joint, legF.v),
    'shinF': _boneFrame(legF.joint, legF.end, legF.v),
    'footN': BoneFrame(
      legN.end,
      _mm(_rotY(-math.atan2(fd1.$3, fd1.$1)),
          _rotZ(q.toeF == true ? -55.0 * _deg : 0.0)),
    ),
    'footF': BoneFrame(
      legF.end,
      _mm(_rotY(-math.atan2(fd2.$3, fd2.$1)),
          _rotZ(q.toeB == true ? -55.0 * _deg : 0.0)),
    ),
  };

  return _SolvedSkeleton(
    b: b,
    w: wSpec,
    ow: owSpec,
    q: q,
    axis: axis,
    side: side,
    armN: armN,
    armF: armF,
    legN: legN,
    legF: legF,
    sN: sN,
    sF: sF,
    hipN: hipN,
    hipF: hipF,
    turn: turn,
  );
}

void _turnAll(_SolvedSkeleton s, double a) {
  final r = _rotY(-a);
  Vec3 rot(Vec3 v) => _mv(r, v);
  for (final f in s.b.values) {
    f.t = rot(f.t);
    f.r = _mm(r, f.r);
  }
  for (final arm in [s.armN, s.armF, s.legN, s.legF]) {
    arm.joint = rot(arm.joint);
    arm.end = rot(arm.end);
  }
  s.sN = rot(s.sN);
  s.sF = rot(s.sF);
  s.hipN = rot(s.hipN);
  s.hipF = rot(s.hipF);
  s.axis = rot(s.axis);
  s.side = rot(s.side);
}

void _pitchAll(_SolvedSkeleton s, double pitch) {
  final r = _rotX(pitch);
  Vec3 rot(Vec3 v) => _mv(r, v);
  for (final f in s.b.values) {
    f.t = rot(f.t);
    f.r = _mm(r, f.r);
  }
  for (final arm in [s.armN, s.armF, s.legN, s.legF]) {
    arm.joint = rot(arm.joint);
    arm.end = rot(arm.end);
  }
  s.sN = rot(s.sN);
  s.sF = rot(s.sF);
  s.hipN = rot(s.hipN);
  s.hipF = rot(s.hipF);
  s.axis = rot(s.axis);
  s.side = rot(s.side);
}

class PosedFigure {
  final int n;
  final Int16List xs;
  final Int16List ys;
  final Uint32List color;
  final Int16List src;
  final Uint8List ink;
  final int x0;
  final int y0;
  final int x1;
  final int y1;
  final double z;

  const PosedFigure({
    required this.n,
    required this.xs,
    required this.ys,
    required this.color,
    required this.src,
    required this.ink,
    required this.x0,
    required this.y0,
    required this.x1,
    required this.y1,
    required this.z,
  });
}

class PosedPart {
  final String name;
  final int part;
  final int n;
  final Int16List xs;
  final Int16List ys;
  final Uint32List color;
  final double cx;
  final double cy;
  final double z;

  const PosedPart({
    required this.name,
    required this.part,
    required this.n,
    required this.xs,
    required this.ys,
    required this.color,
    required this.cx,
    required this.cy,
    required this.z,
  });
}

class SkeletonView {
  final Map<String, Vec3> joints;
  final List<(String, String)> bones;
  final List<String> handles;

  const SkeletonView({
    required this.joints,
    required this.bones,
    required this.handles,
  });
}

const List<String> _frameIds = [
  'pelvis', 'waist', 'chest', 'head', 'neck',
  'upperN', 'foreN', 'upperF', 'foreF',
  'thighN', 'shinN', 'thighF', 'shinF', 'footN', 'footF',
];

abstract final class _PartId {
  static const int pelvis = 1;
  static const int waist = 2;
  static const int chest = 3;
  static const int neck = 4;
  static const int head = 5;
  static const int face = 6;
  static const int upperN = 7;
  static const int elbowN = 8;
  static const int foreN = 9;
  static const int handN = 10;
  static const int upperF = 11;
  static const int elbowF = 12;
  static const int foreF = 13;
  static const int handF = 14;
  static const int thighN = 15;
  static const int kneeN = 16;
  static const int shinN = 17;
  static const int footN = 18;
  static const int thighF = 19;
  static const int kneeF = 20;
  static const int shinF = 21;
  static const int footF = 22;
  static const int weapon = 23;
  static const int offWeapon = 24;

  static const Map<String, int> all = {
    'pelvis': pelvis, 'waist': waist, 'chest': chest, 'neck': neck,
    'head': head, 'face': face,
    'upperN': upperN, 'elbowN': elbowN, 'foreN': foreN, 'handN': handN,
    'upperF': upperF, 'elbowF': elbowF, 'foreF': foreF, 'handF': handF,
    'thighN': thighN, 'kneeN': kneeN, 'shinN': shinN, 'footN': footN,
    'thighF': thighF, 'kneeF': kneeF, 'shinF': shinF, 'footF': footF,
    'weapon': weapon, 'offWeapon': offWeapon,
  };
}

class _AlongPlotter implements WeaponPlotter {
  final RigRasterizer _rig;
  final Vec3 h;
  final Vec3 axis;
  final Vec3 side;
  final Vec3 n;
  final int part;

  _AlongPlotter(this._rig, this.h, this.axis, this.side, this.part)
      : n = _cross(axis, side);

  @override
  void call(double i, double k, int color, [double lift = 0.0]) {
    final x = h.$1 + axis.$1 * i + side.$1 * k + n.$1 * lift;
    final y = h.$2 + axis.$2 * i + side.$2 * k + n.$2 * lift;
    final z = h.$3 + axis.$3 * i + side.$3 * k + n.$3 * lift;
    plotPoint((x, y, z), color);
  }

  @override
  Vec3 at(double i, double k) => (
        h.$1 + axis.$1 * i + side.$1 * k,
        h.$2 + axis.$2 * i + side.$2 * k,
        h.$3 + axis.$3 * i + side.$3 * k,
      );

  @override
  void plotPoint(Vec3 p, int color) {
    final wx = p.$1.round();
    final wy = p.$2.round();
    if (_rig._clipWeapon && wy < 0) return;
    final idx = (RigRasterizer._oy - wy) * RigRasterizer._bw +
        (RigRasterizer._ox + wx);
    if (idx < 0 || idx >= RigRasterizer._bw * RigRasterizer._bh) return;
    _rig._curFrameIndex = -1;
    _rig._plot(idx, p.$3 + 0.05, 2.0, part, 2, wx, wy, color);
  }
}

/// Isolate-safe 3D character rasterizer + LRU pose cache.
class RigRasterizer {
  static const int _bw = 300;
  static const int _bh = 240;
  static const int _ox = 150;
  static const int _oy = 180;
  static final Vec3 _light = _unit((-0.55, 0.72, 0.5));

  final int _inkColor = hex(kDummyPal['k']!);
  final int _seamColor = hex(kDummyPal['J']!);
  final int _markColor = hex(kDummyPal['m']!);
  final List<int> _shell = [
    hex(kDummyPal['A']!),
    hex(kDummyPal['B']!),
    hex(kDummyPal['C']!),
    hex(kDummyPal['D']!),
  ];
  final List<int> _core = [
    hex(kDummyPal['E']!),
    hex(kDummyPal['F']!),
    hex(kDummyPal['G']!),
    hex(kDummyPal['G']!),
  ];

  final Float32List _zb = Float32List(_bw * _bh);
  final Float32List _tone = Float32List(_bw * _bh);
  final Int8List _part = Int8List(_bw * _bh);
  final Int8List _mat = Int8List(_bw * _bh);
  final Int8List _fr = Int8List(_bw * _bh);
  final Uint32List _col = Uint32List(_bw * _bh);
  final List<int> _touched = [];

  final Map<String, PosedFigure> _cache = {};
  final WeaponRegistry weapons;
  late final Map<String, BoneFrame> _restFrames;

  bool _clipBody = false;
  bool _clipWeapon = false;
  int _curFrameIndex = 0;
  int _onlyPart = 0;

  RigRasterizer([WeaponRegistry? weapons])
      : weapons = weapons ?? WeaponRegistry.instance {
    _restFrames = _solve(const Pose(), this.weapons).b;
  }

  static final RigRasterizer instance = RigRasterizer();

  void _useFrame(String name) {
    _curFrameIndex = _frameIds.indexOf(name);
  }

  void _plot(
    int i,
    double z,
    double toneVal,
    int partId,
    int matId,
    int wx,
    int wy,
    int color,
  ) {
    if (_onlyPart != 0 && partId != _onlyPart) return;
    if (i < 0 || i >= _bw * _bh) return;
    if (_part[i] == 0) {
      _touched.add(i);
    } else if (z <= _zb[i]) {
      return;
    }
    _zb[i] = z;
    _tone[i] = toneVal;
    _part[i] = partId;
    _mat[i] = matId;
    _fr[i] = _curFrameIndex;
    _col[i] = color;
  }

  void _sphere(Vec3 c, double r, int partId, int matId) {
    final x0 = (c.$1 - r).floor();
    final x1 = (c.$1 + r).ceil();
    final y0 = (c.$2 - r).floor();
    final y1 = (c.$2 + r).ceil();
    final r2 = r * r;
    for (var wy = y0; wy <= y1; wy++) {
      for (var wx = x0; wx <= x1; wx++) {
        final dx = wx - c.$1;
        final dy = wy - c.$2;
        final d2 = dx * dx + dy * dy;
        if (d2 > r2 || (_clipBody && wy < 1.5)) continue;
        final dz = math.sqrt(r2 - d2);
        final n = (dx / r, dy / r, dz / r);
        final i = (_oy - wy) * _bw + (_ox + wx);
        _plot(i, c.$3 + dz, _dot(n, _light), partId, matId, wx, wy, 0);
      }
    }
  }

  void _sweep(
    Vec3 a,
    Vec3 b,
    double ra,
    double rb,
    int partId,
    int matId, [
    double bulge = 0.0,
  ]) {
    final n = math.max(2, (_len(_sub(b, a)) / 0.4).ceil());
    final diff = _sub(b, a);
    for (var k = 0; k <= n; k++) {
      final u = k / n;
      _sphere(
        _add(a, _mul(diff, u)),
        ra + (rb - ra) * u + bulge * math.sin(u * math.pi),
        partId,
        matId,
      );
    }
  }

  void _ellipsoid(Vec3 c, Mat3 r, Vec3 rad, int partId, int matId) {
    final big = math.max(rad.$1, math.max(rad.$2, rad.$3));
    final x0 = (c.$1 - big).floor();
    final x1 = (c.$1 + big).ceil();
    final y0 = (c.$2 - big).floor();
    final y1 = (c.$2 + big).ceil();
    final d0 = 1.0 / (rad.$1 * rad.$1);
    final d1 = 1.0 / (rad.$2 * rad.$2);
    final d2 = 1.0 / (rad.$3 * rad.$3);
    final a = List<double>.filled(9, 0.0);
    for (var i = 0; i < 3; i++) {
      for (var j = 0; j < 3; j++) {
        a[i * 3 + j] = r[i * 3] * d0 * r[j * 3] +
            r[i * 3 + 1] * d1 * r[j * 3 + 1] +
            r[i * 3 + 2] * d2 * r[j * 3 + 2];
      }
    }
    for (var wy = y0; wy <= y1; wy++) {
      for (var wx = x0; wx <= x1; wx++) {
        if (_clipBody && wy < 1.5) continue;
        final dx = wx - c.$1;
        final dy = wy - c.$2;
        final qa = a[8];
        final qb = 2.0 * (a[2] * dx + a[5] * dy);
        final qc = a[0] * dx * dx + 2.0 * a[1] * dx * dy + a[4] * dy * dy - 1.0;
        final disc = qb * qb - 4.0 * qa * qc;
        if (disc < 0.0) continue;
        final dz = (-qb + math.sqrt(disc)) / (2.0 * qa);
        final n = _unit((
          a[0] * dx + a[1] * dy + a[2] * dz,
          a[3] * dx + a[4] * dy + a[5] * dz,
          a[6] * dx + a[7] * dy + a[8] * dz,
        ));
        _plot(
          (_oy - wy) * _bw + (_ox + wx),
          c.$3 + dz,
          _dot(n, _light),
          partId,
          matId,
          wx,
          wy,
          0,
        );
      }
    }
  }

  void _drawBody(_SolvedSkeleton s) {
    final b = s.b;
    BoneFrame f(String name) => b[name]!;
    _useFrame('pelvis');
    _ellipsoid(
      _add(f('pelvis').t, _mv(f('pelvis').r, (0.0, -0.2, 0.0))),
      f('pelvis').r,
      (2.9, 2.6, 4.2),
      _PartId.pelvis,
      0,
    );
    _useFrame('waist');
    _sweep(f('pelvis').t, f('chest').t, 3.0, 3.3, _PartId.waist, 1);
    _useFrame('chest');
    _ellipsoid(
      _add(f('chest').t, _mv(f('chest').r, (0.2, 0.9, 0.0))),
      f('chest').r,
      (3.4, 4.2, 5.5),
      _PartId.chest,
      0,
    );
    _useFrame('neck');
    _sweep(
      f('neck').t,
      _add(f('neck').t, _mv(f('head').r, (0.0, 1.6, 0.0))),
      1.25,
      1.15,
      _PartId.neck,
      1,
    );
    _useFrame('head');
    _ellipsoid(f('head').t, f('head').r, (3.0, 3.3, 2.8), _PartId.head, 0);
    _ellipsoid(
      _add(f('head').t, _mv(f('head').r, (0.85, -0.45, 0.0))),
      f('head').r,
      (2.4, 2.7, 2.35),
      _PartId.face,
      0,
    );

    void arm(
      _IkResult a,
      Vec3 sh,
      int up,
      int el,
      int fo,
      int ha,
      String nameU,
      String nameF,
    ) {
      _useFrame(nameU);
      _sphere(sh, 2.5, up, 0);
      _sweep(sh, a.joint, 2.1, 1.6, up, 0);
      _sphere(a.joint, 1.45, el, 1);
      _useFrame(nameF);
      _sweep(a.joint, a.end, 1.6, 1.2, fo, 0, 0.15);
      _sphere(a.end, 1.9, ha, 0);
    }

    arm(s.armN, s.sN, _PartId.upperN, _PartId.elbowN, _PartId.foreN,
        _PartId.handN, 'upperN', 'foreN');
    arm(s.armF, s.sF, _PartId.upperF, _PartId.elbowF, _PartId.foreF,
        _PartId.handF, 'upperF', 'foreF');

    void leg(
      _IkResult l,
      Vec3 hip,
      int th,
      int kn,
      int sh,
      int fo,
      String nameT,
      String nameS,
      String nameFt,
    ) {
      _useFrame(nameT);
      _sweep(hip, l.joint, 3.2, 2.2, th, 0);
      _sphere(l.joint, 1.9, kn, 1);
      _useFrame(nameS);
      _sweep(l.joint, l.end, 2.15, 1.4, sh, 0, 0.4);
      _useFrame(nameFt);
      final r = f(nameFt).r;
      final a = f(nameFt).t;
      _sweep(
        _add(a, _mv(r, (-1.5, -0.6, 0.0))),
        _add(a, _mv(r, (4.6, -1.1, 0.0))),
        1.7,
        1.25,
        fo,
        0,
      );
    }

    leg(s.legN, s.hipN, _PartId.thighN, _PartId.kneeN, _PartId.shinN,
        _PartId.footN, 'thighN', 'shinN', 'footN');
    leg(s.legF, s.hipF, _PartId.thighF, _PartId.kneeF, _PartId.shinF,
        _PartId.footF, 'thighF', 'shinF', 'footF');
  }

  PosedFigure _finish(_SolvedSkeleton s) {
    int dim(int partId) =>
        (partId >= _PartId.upperF && partId <= _PartId.handF) ||
                (partId >= _PartId.thighF && partId <= _PartId.footF)
            ? 1
            : 0;
    int toneOf(double v, int partId) {
      var t = v > 0.8 ? 0 : (v > 0.42 ? 1 : (v > 0.08 ? 2 : 3));
      t = math.min(3, t + dim(partId));
      return t;
    }

    final tones = <int, int>{};
    for (final i in _touched) {
      tones[i] = toneOf(_tone[i], _part[i]);
    }
    const dirs = [-1, 1, -_bw, _bw];
    for (final i in _touched) {
      if (_mat[i] == 2) continue;
      final t = tones[i]!;
      final votes = [0, 0, 0, 0];
      var same = false;
      for (final d in dirs) {
        final j = i + d;
        if (j < 0 || j >= _bw * _bh) continue;
        if (_part[j] != _part[i]) continue;
        final u = tones[j];
        if (u == null) continue;
        votes[u]++;
        if (u == t) same = true;
      }
      if (!same) {
        var bestVote = 0;
        var bestIdx = -1;
        for (var vi = 0; vi < 4; vi++) {
          if (votes[vi] > bestVote) {
            bestVote = votes[vi];
            bestIdx = vi;
          }
        }
        if (bestVote > 0) tones[i] = bestIdx;
      }
    }
    for (final i in _touched) {
      if (_mat[i] == 2) continue;
      _col[i] = (_mat[i] == 1 ? _core : _shell)[tones[i]!];
    }

    final marks = <int, int>{};
    for (final i in _touched) {
      for (final d in const [1, _bw]) {
        final j = i + d;
        if (j >= _bw * _bh || _part[j] == 0 || _part[j] == _part[i]) continue;
        final far = _zb[i] < _zb[j] ? i : j;
        final dz = (_zb[i] - _zb[j]).abs();
        final steel = _mat[i] == 2 || _mat[j] == 2;
        if (_mat[far] == 2 && dz < 1.0) continue;
        final ink = steel || dz > 2.2;
        if (ink) {
          marks[far] = _inkColor;
        } else {
          marks.putIfAbsent(far, () => _seamColor);
        }
      }
    }
    for (final e in marks.entries) {
      _col[e.key] = e.value;
    }

    final b = s.b;
    final chestAt = _add(b['chest']!.t, _mv(b['chest']!.r, (3.0, 1.6, -1.8)));
    if (_mv(b['chest']!.r, (1.0, 0.0, 0.0)).$3 > 0.15) {
      final idx = (_oy - chestAt.$2.round()) * _bw + (_ox + chestAt.$1.round());
      if (idx >= 0 && idx < _bw * _bh && _part[idx] == _PartId.chest) {
        _col[idx] = _markColor;
      }
    }

    final list = _touched.toList(growable: false);
    final ring = <int, int>{};
    for (final i in list) {
      for (final d in dirs) {
        final j = i + d;
        if (j >= 0 && j < _bw * _bh && _part[j] == 0 && !ring.containsKey(j)) {
          ring[j] = i;
        }
      }
    }

    final n = list.length + ring.length;
    final xs = Int16List(n);
    final ys = Int16List(n);
    final colorOut = Uint32List(n);
    final srcOut = Int16List(n);
    final inkOut = Uint8List(n);

    int srcFor(int i) {
      final f = _fr[i];
      if (f < 0) return -1;
      final name = _frameIds[f];
      final a = b[name]!;
      final r0 = _restFrames[name]!;
      final wx = (i % _bw) - _ox;
      final wy = _oy - (i ~/ _bw);
      final p = (wx.toDouble(), wy.toDouble(), _zb[i]);
      final lp = _tv(a.r, _sub(p, a.t));
      final rp = _add(r0.t, _mv(r0.r, lp));
      final c = rp.$1.round() + 12;
      final r = 38 - rp.$2.round();
      return c < 0 || r < 0 || c >= _w0 || r >= _h0 ? -1 : r * _w0 + c;
    }

    var k = 0;
    var x0 = 1000000000;
    var y0 = 1000000000;
    var x1 = -1000000000;
    var y1 = -1000000000;

    void pushPx(int i, int c, int sIdx, bool isInk) {
      final x = (i % _bw) - _ox;
      final y = (i ~/ _bw) - _oy;
      xs[k] = x;
      ys[k] = y;
      colorOut[k] = c;
      srcOut[k] = sIdx;
      inkOut[k] = isInk ? 1 : 0;
      if (x < x0) x0 = x;
      if (x > x1) x1 = x;
      if (y < y0) y0 = y;
      if (y > y1) y1 = y;
      k++;
    }

    var zs = 0.0;
    for (final i in list) {
      pushPx(i, _col[i], srcFor(i), _col[i] == _inkColor);
      zs += _zb[i];
    }
    for (final e in ring.entries) {
      pushPx(e.key, _inkColor, srcFor(e.value), true);
    }
    for (final i in list) {
      _part[i] = 0;
    }
    _touched.clear();

    return PosedFigure(
      n: n,
      xs: xs,
      ys: ys,
      color: colorOut,
      src: srcOut,
      ink: inkOut,
      x0: x0,
      y0: y0,
      x1: x1,
      y1: y1,
      z: list.isNotEmpty ? zs / list.length : 0.0,
    );
  }

  PosedFigure _render(Pose pose, {double pitch = 0.0}) {
    final s = _solve(pose, weapons);
    final q = s.q;
    final whole = (q.yaw ?? 0.0) + (q.face == -1 ? math.pi : 0.0);
    if (whole != 0.0) _turnAll(s, whole);
    if (pitch != 0.0) _pitchAll(s, pitch);
    final air = (q.y ?? 0.0) < -0.5;
    _clipBody = pitch == 0.0 && !air;
    _clipWeapon = pitch == 0.0 && !air;
    _drawBody(s);
    _clipBody = false;
    if (s.w != null) {
      s.w!.draw(
        _AlongPlotter(this, s.armN.end, s.axis, s.side, _PartId.weapon),
        q,
        s.armF.end,
      );
    }
    if (s.ow != null) {
      final sb = q.sb ?? math.pi;
      var ax = (math.cos(sb), -math.sin(sb), 0.0);
      var sd = (-math.sin(sb), -math.cos(sb), 0.0);
      if (whole != 0.0) {
        final r = _rotY(-whole);
        ax = _mv(r, ax);
        sd = _mv(r, sd);
      }
      if (pitch != 0.0) {
        final rx = _rotX(pitch);
        ax = _mv(rx, ax);
        sd = _mv(rx, sd);
      }
      s.ow!.draw(
        _AlongPlotter(this, s.armF.end, ax, sd, _PartId.offWeapon),
        q,
        s.armF.end,
      );
    }
    _clipWeapon = false;
    return _finish(s);
  }

  String _keyOf(Pose p, double pitch) {
    final buf = StringBuffer();
    if (pitch != 0.0) buf.write('pitch${(pitch * 100.0).round()},');
    if ((p.y ?? 0.0) < -0.5) buf.write('air,');
    final map = p.toJson();
    final keys = map.keys.toList()..sort();
    for (final k in keys) {
      if (k == 'x' || k == 'y' || k == 'ghost') continue;
      final v = map[k];
      if (v == null) continue;
      buf.write(k);
      if (v is num) {
        final scaled = (k == 'sa' || k == 'sb' || k == 'wl' || k == 'yaw' || k == 'turn')
            ? (v * 20.0).round()
            : v.round();
        buf.write(scaled);
      } else {
        buf.write(v);
      }
      buf.write(',');
    }
    return buf.toString();
  }

  PosedFigure posed(Pose pose, {double pitch = 0.0}) {
    final key = _keyOf(pose, pitch);
    var r = _cache[key];
    if (r == null) {
      if (_cache.length > 6000) _cache.clear();
      r = _render(pose, pitch: pitch);
      _cache[key] = r;
    }
    return r;
  }

  double shortfall(Pose pose) {
    final s = _solve(pose, weapons);
    final q = s.q;
    final near = _len(_sub(s.armN.end, (q.fx!, -q.fy!, s.armN.end.$3)));
    final far = q.two == true
        ? 0.0
        : _len(_sub(s.armF.end, (q.bx!, -q.by!, s.armF.end.$3)));
    return math.max(near, far);
  }

  SkeletonView skeleton(Pose pose, {double pitch = 0.0}) {
    final s = _solve(pose, weapons);
    final q = s.q;
    final whole = (q.yaw ?? 0.0) + (q.face == -1 ? math.pi : 0.0);
    if (whole != 0.0) _turnAll(s, whole);
    if (pitch != 0.0) _pitchAll(s, pitch);
    final b = s.b;
    Vec3 at(BoneFrame f, Vec3 v) => _add(f.t, _mv(f.r, v));
    final raw = <String, Vec3>{
      'pelvis': b['pelvis']!.t,
      'waist': b['waist']!.t,
      'chest': b['chest']!.t,
      'neck': b['neck']!.t,
      'head': b['head']!.t,
      'crown': at(b['head']!, (0.0, 3.3, 0.0)),
      'shoulderN': s.sN,
      'elbowN': s.armN.joint,
      'handN': s.armN.end,
      'shoulderF': s.sF,
      'elbowF': s.armF.joint,
      'handF': s.armF.end,
      'hipN': s.hipN,
      'kneeN': s.legN.joint,
      'ankleN': s.legN.end,
      'toeN': at(b['footN']!, (4.6, -1.1, 0.0)),
      'hipF': s.hipF,
      'kneeF': s.legF.joint,
      'ankleF': s.legF.end,
      'toeF': at(b['footF']!, (4.6, -1.1, 0.0)),
    };
    final joints = {
      for (final e in raw.entries) e.key: (e.value.$1, -e.value.$2, e.value.$3),
    };
    const bones = [
      ('pelvis', 'waist'), ('waist', 'chest'), ('chest', 'neck'),
      ('neck', 'head'), ('head', 'crown'), ('chest', 'shoulderN'),
      ('shoulderN', 'elbowN'), ('elbowN', 'handN'), ('chest', 'shoulderF'),
      ('shoulderF', 'elbowF'), ('elbowF', 'handF'), ('pelvis', 'hipN'),
      ('hipN', 'kneeN'), ('kneeN', 'ankleN'), ('ankleN', 'toeN'),
      ('pelvis', 'hipF'), ('hipF', 'kneeF'), ('kneeF', 'ankleF'),
      ('ankleF', 'toeF'),
    ];
    return SkeletonView(
      joints: joints,
      bones: bones,
      handles: const ['handN', 'handF', 'ankleN', 'ankleF'],
    );
  }

  List<PosedPart> posedParts(Pose pose, {double pitch = 0.0}) {
    final out = <PosedPart>[];
    for (final e in _PartId.all.entries) {
      _onlyPart = e.value;
      final r = _render(pose, pitch: pitch);
      _onlyPart = 0;
      if (r.n == 0) continue;
      var cx = 0.0;
      var cy = 0.0;
      for (var i = 0; i < r.n; i++) {
        cx += r.xs[i];
        cy += r.ys[i];
      }
      out.add(PosedPart(
        name: e.key,
        part: e.value,
        n: r.n,
        xs: r.xs,
        ys: r.ys,
        color: r.color,
        cx: cx / r.n,
        cy: cy / r.n,
        z: r.z,
      ));
    }
    return out;
  }
}

PosedFigure posed(Pose pose, {double pitch = 0.0}) =>
    RigRasterizer.instance.posed(pose, pitch: pitch);
double shortfall(Pose pose) => RigRasterizer.instance.shortfall(pose);
SkeletonView skeleton(Pose pose, {double pitch = 0.0}) =>
    RigRasterizer.instance.skeleton(pose, pitch: pitch);
List<PosedPart> posedParts(Pose pose, {double pitch = 0.0}) =>
    RigRasterizer.instance.posedParts(pose, pitch: pitch);
