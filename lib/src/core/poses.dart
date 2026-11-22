// Poses, key tracks and pose interpolation (12 fps stepped limbs, smooth feet).

import 'dart:math' as math;

enum PoseEase { smooth, out, inEase, line, snap }

class Pose {
  final double? x;
  final double? y;
  final double? crouch;
  final double? lean;
  final double? twist;
  final double? turn;
  final double? yaw;
  final double? hx;
  final double? hy;
  final double? fx;
  final double? fy;
  final double? fz;
  final double? bx;
  final double? by;
  final double? bz;
  final double? ffx;
  final double? ffy;
  final double? fbx;
  final double? fby;
  final double? fzz;
  final double? bzz;
  final String? weapon;
  final double? sa;
  final bool? two;
  final String? offWeapon;
  final double? sb;
  final bool? armsFront;
  final bool? toeF;
  final bool? toeB;
  final int? face;
  final int? ghost;
  final double? wl;
  final double? wz;
  final bool? pull;
  final bool? nocked;

  const Pose({
    this.x,
    this.y,
    this.crouch,
    this.lean,
    this.twist,
    this.turn,
    this.yaw,
    this.hx,
    this.hy,
    this.fx,
    this.fy,
    this.fz,
    this.bx,
    this.by,
    this.bz,
    this.ffx,
    this.ffy,
    this.fbx,
    this.fby,
    this.fzz,
    this.bzz,
    this.weapon,
    this.sa,
    this.two,
    this.offWeapon,
    this.sb,
    this.armsFront,
    this.toeF,
    this.toeB,
    this.face,
    this.ghost,
    this.wl,
    this.wz,
    this.pull,
    this.nocked,
  });

  Pose copyWith({
    double? x,
    double? y,
    double? crouch,
    double? lean,
    double? twist,
    double? turn,
    double? yaw,
    double? hx,
    double? hy,
    double? fx,
    double? fy,
    double? fz,
    double? bx,
    double? by,
    double? bz,
    double? ffx,
    double? ffy,
    double? fbx,
    double? fby,
    double? fzz,
    double? bzz,
    String? weapon,
    double? sa,
    bool? two,
    String? offWeapon,
    double? sb,
    bool? armsFront,
    bool? toeF,
    bool? toeB,
    int? face,
    int? ghost,
    double? wl,
    double? wz,
    bool? pull,
    bool? nocked,
  }) =>
      Pose(
        x: x ?? this.x,
        y: y ?? this.y,
        crouch: crouch ?? this.crouch,
        lean: lean ?? this.lean,
        twist: twist ?? this.twist,
        turn: turn ?? this.turn,
        yaw: yaw ?? this.yaw,
        hx: hx ?? this.hx,
        hy: hy ?? this.hy,
        fx: fx ?? this.fx,
        fy: fy ?? this.fy,
        fz: fz ?? this.fz,
        bx: bx ?? this.bx,
        by: by ?? this.by,
        bz: bz ?? this.bz,
        ffx: ffx ?? this.ffx,
        ffy: ffy ?? this.ffy,
        fbx: fbx ?? this.fbx,
        fby: fby ?? this.fby,
        fzz: fzz ?? this.fzz,
        bzz: bzz ?? this.bzz,
        weapon: weapon ?? this.weapon,
        sa: sa ?? this.sa,
        two: two ?? this.two,
        offWeapon: offWeapon ?? this.offWeapon,
        sb: sb ?? this.sb,
        armsFront: armsFront ?? this.armsFront,
        toeF: toeF ?? this.toeF,
        toeB: toeB ?? this.toeB,
        face: face ?? this.face,
        ghost: ghost ?? this.ghost,
        wl: wl ?? this.wl,
        wz: wz ?? this.wz,
        pull: pull ?? this.pull,
        nocked: nocked ?? this.nocked,
      );

  /// Merges [other] on top of `this` (equivalent to `{ ...a, ...b }` in JS).
  Pose merge(Pose other) => Pose(
        x: other.x ?? x,
        y: other.y ?? y,
        crouch: other.crouch ?? crouch,
        lean: other.lean ?? lean,
        twist: other.twist ?? twist,
        turn: other.turn ?? turn,
        yaw: other.yaw ?? yaw,
        hx: other.hx ?? hx,
        hy: other.hy ?? hy,
        fx: other.fx ?? fx,
        fy: other.fy ?? fy,
        fz: other.fz ?? fz,
        bx: other.bx ?? bx,
        by: other.by ?? by,
        bz: other.bz ?? bz,
        ffx: other.ffx ?? ffx,
        ffy: other.ffy ?? ffy,
        fbx: other.fbx ?? fbx,
        fby: other.fby ?? fby,
        fzz: other.fzz ?? fzz,
        bzz: other.bzz ?? bzz,
        weapon: other.weapon ?? weapon,
        sa: other.sa ?? sa,
        two: other.two ?? two,
        offWeapon: other.offWeapon ?? offWeapon,
        sb: other.sb ?? sb,
        armsFront: other.armsFront ?? armsFront,
        toeF: other.toeF ?? toeF,
        toeB: other.toeB ?? toeB,
        face: other.face ?? face,
        ghost: other.ghost ?? ghost,
        wl: other.wl ?? wl,
        wz: other.wz ?? wz,
        pull: other.pull ?? pull,
        nocked: other.nocked ?? nocked,
      );

  Map<String, Object?> toJson() => {
        if (x != null) 'x': x,
        if (y != null) 'y': y,
        if (crouch != null) 'crouch': crouch,
        if (lean != null) 'lean': lean,
        if (twist != null) 'twist': twist,
        if (turn != null) 'turn': turn,
        if (yaw != null) 'yaw': yaw,
        if (hx != null) 'hx': hx,
        if (hy != null) 'hy': hy,
        if (fx != null) 'fx': fx,
        if (fy != null) 'fy': fy,
        if (fz != null) 'fz': fz,
        if (bx != null) 'bx': bx,
        if (by != null) 'by': by,
        if (bz != null) 'bz': bz,
        if (ffx != null) 'ffx': ffx,
        if (ffy != null) 'ffy': ffy,
        if (fbx != null) 'fbx': fbx,
        if (fby != null) 'fby': fby,
        if (fzz != null) 'fzz': fzz,
        if (bzz != null) 'bzz': bzz,
        if (weapon != null) 'weapon': weapon,
        if (sa != null) 'sa': sa,
        if (two != null) 'two': two,
        if (offWeapon != null) 'offWeapon': offWeapon,
        if (sb != null) 'sb': sb,
        if (armsFront != null) 'armsFront': armsFront,
        if (toeF != null) 'toeF': toeF,
        if (toeB != null) 'toeB': toeB,
        if (face != null) 'face': face,
        if (ghost != null) 'ghost': ghost,
        if (wl != null) 'wl': wl,
        if (wz != null) 'wz': wz,
        if (pull != null) 'pull': pull,
        if (nocked != null) 'nocked': nocked,
      };
}

/// Standing easy, in screen terms: hands and feet are where they should end up, y negative is up.
const Pose kStand = Pose(
  lean: 0.0,
  crouch: 0.0,
  yaw: 0.0,
  fx: -3.0,
  fy: -15.0,
  bx: 5.0,
  by: -15.0,
  ffx: -2.0,
  ffy: -4.0,
  fbx: 3.0,
  fby: -4.0,
);

/// Combat-ready stance that most action acts start from.
const Pose kReady = Pose(
  crouch: 3.0,
  fx: 11.0,
  fy: -21.0,
  bx: 9.0,
  by: -21.0,
  ffx: 7.0,
  fbx: -7.0,
);

class PoseKey {
  final double t;
  final Pose pose;
  final PoseEase how;

  const PoseKey(this.t, this.pose, [this.how = PoseEase.smooth]);
}

double _lerpN(double a, double b, double u) => a + (b - a) * u;

double? _easeBackZero(double? a, double? bInRaw, double u) {
  if (bInRaw == null && a != null) return _lerpN(a, 0.0, u);
  return a;
}

/// Between two poses: numbers move, discrete attributes switch at the later key.
/// Fields omitted in [b] (`hx`, `hy`, `lean`, `crouch`) ease back to 0, and `wl` eases back to 1.
Pose lerpPose(Pose a, Pose b, double u) {
  final out = kStand.merge(a);
  final bFull = kStand.merge(b);

  double? numField(double? av, double? bv) {
    if (bv != null && av != null) return _lerpN(av, bv, u);
    return av ?? bv;
  }

  return Pose(
    x: numField(out.x, bFull.x),
    y: numField(out.y, bFull.y),
    crouch: b.crouch == null && out.crouch != null
        ? _lerpN(out.crouch!, 0.0, u)
        : numField(out.crouch, bFull.crouch),
    lean: b.lean == null && out.lean != null
        ? _lerpN(out.lean!, 0.0, u)
        : numField(out.lean, bFull.lean),
    twist: numField(out.twist, bFull.twist),
    turn: numField(out.turn, bFull.turn),
    yaw: numField(out.yaw, bFull.yaw),
    hx: _easeBackZero(numField(out.hx, bFull.hx), b.hx, u),
    hy: _easeBackZero(numField(out.hy, bFull.hy), b.hy, u),
    fx: numField(out.fx, bFull.fx),
    fy: numField(out.fy, bFull.fy),
    fz: numField(out.fz, bFull.fz),
    bx: numField(out.bx, bFull.bx),
    by: numField(out.by, bFull.by),
    bz: numField(out.bz, bFull.bz),
    ffx: numField(out.ffx, bFull.ffx),
    ffy: numField(out.ffy, bFull.ffy),
    fbx: numField(out.fbx, bFull.fbx),
    fby: numField(out.fby, bFull.fby),
    fzz: numField(out.fzz, bFull.fzz),
    bzz: numField(out.bzz, bFull.bzz),
    sa: numField(out.sa, bFull.sa),
    sb: numField(out.sb, bFull.sb),
    wl: b.wl == null && out.wl != null
        ? _lerpN(out.wl!, 1.0, u)
        : numField(out.wl, bFull.wl),
    wz: numField(out.wz, bFull.wz),
    face: out.face ?? bFull.face,
    ghost: out.ghost ?? bFull.ghost,
    weapon: out.weapon,
    two: out.two,
    offWeapon: out.offWeapon,
    armsFront: out.armsFront,
    toeF: out.toeF,
    toeB: out.toeB,
    pull: out.pull,
    nocked: out.nocked,
  );
}

double _easePose(PoseEase how, double u) => switch (how) {
      PoseEase.out => 1.0 - (1.0 - u) * (1.0 - u),
      PoseEase.inEase => u * u,
      PoseEase.line => u,
      PoseEase.smooth || PoseEase.snap => u * u * (3.0 - 2.0 * u),
    };

/// The pose at time [t] on a track of [PoseKey]s: limbs step at 12 fps while feet `(x, y)` stay smooth.
Pose poseAt(List<PoseKey> track, double t) {
  if (t <= track.first.t) return track.first.pose;
  for (var i = 0; i < track.length - 1; i++) {
    final t0 = track[i].t;
    final a = track[i].pose;
    final t1 = track[i + 1].t;
    final b = track[i + 1].pose;
    final how = track[i + 1].how;
    if (t >= t1) continue;
    if (how == PoseEase.snap) return a;
    final stepped = t0 + ((t - t0) * 12.0 + 1e-6).floorToDouble() / 12.0;
    final span = math.max(1e-9, t1 - t0);
    final out = lerpPose(a, b, _easePose(how, (stepped - t0) / span));
    final u = _easePose(how, (t - t0) / span);
    return out.copyWith(
      x: _lerpN(a.x ?? 0.0, b.x ?? 0.0, u),
      y: _lerpN(a.y ?? 0.0, b.y ?? 0.0, u),
    );
  }
  return track.last.pose;
}

/// Checks if a pose is nearly stationary between surrounding keys (used for idle breathing).
bool isPoseHeld(List<PoseKey> track, double t) {
  if (t >= track.last.t || t < track.first.t) return true;
  for (var i = 0; i < track.length - 1; i++) {
    if (t >= track[i + 1].t) continue;
    if (track[i + 1].t - track[i].t <= 0.4) return false;
    final a = kStand.merge(track[i].pose);
    final b = kStand.merge(track[i + 1].pose);
    return ((a.fx ?? 0.0) - (b.fx ?? 0.0)).abs() < 1.5 &&
        ((a.fy ?? 0.0) - (b.fy ?? 0.0)).abs() < 1.5 &&
        ((a.bx ?? 0.0) - (b.bx ?? 0.0)).abs() < 1.5 &&
        ((a.by ?? 0.0) - (b.by ?? 0.0)).abs() < 1.5 &&
        ((a.crouch ?? 0.0) - (b.crouch ?? 0.0)).abs() < 1.5 &&
        ((a.lean ?? 0.0) - (b.lean ?? 0.0)).abs() < 1.5 &&
        ((a.x ?? 0.0) - (b.x ?? 0.0)).abs() < 1.5 &&
        ((a.y ?? 0.0) - (b.y ?? 0.0)).abs() < 1.5;
  }
  return true;
}
