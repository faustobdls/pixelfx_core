// Plain-data specification of an Act: targets, pose track, hit-stops, dust kicks, and skins.

import 'color.dart';
import 'poses.dart';

class SkinSpec {
  final int color;
  final double mixAmount;

  const SkinSpec(this.color, this.mixAmount);
}

/// Extensible skin registry for hit reactions (`char`, `ice`, `shock`, etc.).
class SkinRegistry {
  final Map<String, SkinSpec> _skins = {};

  SkinRegistry({bool includeBuiltIns = true}) {
    if (includeBuiltIns) {
      registerAll({
        'flash': SkinSpec(kWhite, 1.0),
        'char': SkinSpec(hex('#1a0c0e'), 0.72),
        'ice': SkinSpec(hex('#a8e8ff'), 0.72),
        'shadow': SkinSpec(hex('#3a1a70'), 0.5),
        'holy': SkinSpec(hex('#fff4c0'), 0.5),
        'red': SkinSpec(hex('#ff2040'), 0.45),
        'shock': SkinSpec(hex('#8fd6ff'), 0.6),
        'poison': SkinSpec(hex('#58c43a'), 0.5),
      });
    }
  }

  void register(String name, SkinSpec spec) => _skins[name] = spec;
  void registerAll(Map<String, SkinSpec> map) => _skins.addAll(map);
  SkinSpec? operator [](String? name) => name == null ? null : _skins[name];
  Iterable<String> get names => _skins.keys;

  static final SkinRegistry instance = SkinRegistry();
}

class TargetSpec {
  final double x;
  const TargetSpec({this.x = 66.0});
}

class HitSpec {
  final double t;
  final double stop;
  final double shake;
  final double amp;
  final double push;
  final int straw;
  final double flash;
  final double y;

  /// Null leaves the current skin untouched; set [clearSkin] to true to reset to null (like JS `skin: null`).
  final String? skin;
  final bool clearSkin;
  final double shiver;
  final int? at;
  final bool target;

  const HitSpec({
    required this.t,
    this.stop = 0.0,
    this.shake = 0.0,
    this.amp = 2.0,
    this.push = 1.2,
    this.straw = 8,
    this.flash = 0.05,
    this.y = -26.0,
    this.skin,
    this.clearSkin = false,
    this.shiver = 0.0,
    this.at,
    this.target = true,
  });

  HitSpec shifted(double dt) => HitSpec(
        t: t + dt,
        stop: stop,
        shake: shake,
        amp: amp,
        push: push,
        straw: straw,
        flash: flash,
        y: y,
        skin: skin,
        clearSkin: clearSkin,
        shiver: shiver,
        at: at,
        target: target,
      );
}

class DustSpec {
  final double t;
  final double x;
  final int n;
  final int? dir;
  final Object? color;

  const DustSpec({
    required this.t,
    required this.x,
    this.n = 6,
    this.dir,
    this.color,
  });
}

class ActSpec {
  final TargetSpec? target;
  final List<TargetSpec>? targets;
  final List<PoseKey> poses;
  final List<HitSpec> hits;
  final List<DustSpec> dust;
  final bool onBody;
  final double follow;
  final Object? ghost;

  const ActSpec({
    this.target,
    this.targets,
    required this.poses,
    this.hits = const [],
    this.dust = const [],
    this.onBody = false,
    this.follow = 1.0,
    this.ghost,
  });

  List<TargetSpec> get effectiveTargets =>
      targets ?? (target != null ? [target!] : const []);
}

class ActHitTiming {
  final double t;
  final double freeze;
  final double shake;
  final double amp;
  final double push;
  final String? skin;
  final int? at;

  const ActHitTiming({
    required this.t,
    required this.freeze,
    required this.shake,
    required this.amp,
    required this.push,
    this.skin,
    this.at,
  });

  Map<String, Object?> toJson() => {
        't': t,
        'freeze': freeze,
        'shake': shake,
        'amp': amp,
        'push': push,
        if (skin != null) 'skin': skin,
        if (at != null) 'at': at,
      };
}

class ActPoseTiming {
  final double t;
  final String how;
  final Pose pose;

  const ActPoseTiming({
    required this.t,
    required this.how,
    required this.pose,
  });

  Map<String, Object?> toJson() => {
        't': t,
        'how': how,
        'pose': pose.toJson(),
      };
}

class ActTiming {
  final double windup;
  final double recovery;
  final bool onBody;
  final List<double> targets;
  final List<ActHitTiming> hits;
  final List<ActPoseTiming> poses;

  const ActTiming({
    required this.windup,
    required this.recovery,
    required this.onBody,
    required this.targets,
    required this.hits,
    required this.poses,
  });

  Map<String, Object?> toJson() => {
        'windup': windup,
        'recovery': recovery,
        'onBody': onBody,
        'targets': targets,
        'hits': [for (final h in hits) h.toJson()],
        'poses': [for (final p in poses) p.toJson()],
      };
}
