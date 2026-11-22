// Moves: several effects played as one. A cue says which effect, when, where and for how long.

import '../framework/asset.dart';
import 'act_spec.dart';
import 'fx.dart';
import 'painter.dart';
import 'poses.dart';

class ChainCue {
  final PixelEffect fx;
  final double t;
  final double until;
  final double Function(double t) x;
  final double Function(double t) y;
  final bool flip;
  final Map<String, Object?> options;

  ChainCue({
    required this.fx,
    this.t = 0.0,
    this.until = double.infinity,
    Object x = 0.0,
    Object y = 0.0,
    this.flip = false,
    this.options = const {},
  })  : x = _asPosFn(x),
        y = _asPosFn(y);

  static double Function(double t) _asPosFn(Object v) {
    if (v is double Function(double)) return v;
    if (v is num) {
      final val = v.toDouble();
      return (_) => val;
    }
    throw ArgumentError('ChainCue position must be num or double Function(double)');
  }
}

class _CueState {
  final ChainCue cue;
  final Map<String, Object?> opts;
  EffectInstance? inst;
  bool over = false;

  _CueState(this.cue, this.opts);
}

class _ChainSim implements EffectSim {
  final List<_CueState> list;
  double t = 0.0;

  _ChainSim(this.list);

  void _each(Painter p, DrawLayer layer) {
    final frame = p.frame;
    final tx = p.tx;
    final ty = p.ty;
    final sign = p.fx;
    final cs = p.cs;
    final sn = p.sn;
    final fade = p.fade;
    final lightK = p.lightK;

    for (final c in list) {
      final inst = c.inst;
      if (inst == null || c.over) continue;
      inst.options['x'] = tx + sign * c.cue.x(t);
      inst.options['y'] = ty + c.cue.y(t);
      inst.options['flip'] = (sign < 0) != c.cue.flip;
      inst.draw(frame, layer);
    }

    p
      ..tx = tx
      ..ty = ty
      ..fx = sign
      ..cs = cs
      ..sn = sn
      ..fade = fade
      ..lightK = lightK;
  }

  @override
  void update(double dt, Map<String, Object?> _) {
    t += dt;
    for (final c in list) {
      if (c.over || t < c.cue.t) continue;
      final inst = c.inst;
      if (inst == null) {
        c.inst = createFx(c.cue.fx, c.opts);
      } else {
        inst.update(dt);
      }
      if (t >= c.cue.until || (c.inst!.done && !c.cue.fx.meta.loop)) {
        c.over = true;
      }
    }
  }

  @override
  void drawBack(Painter p) => _each(p, DrawLayer.back);

  @override
  void draw(Painter p) => _each(p, DrawLayer.front);
}

/// Builds a `create(o)` function playing a list of [ChainCue]s as one composite effect.
EffectSim Function(Map<String, Object?> options) chain(List<ChainCue> cues) {
  return (o) {
    final seed = o.seed;
    final list = [
      for (var i = 0; i < cues.length; i++)
        _CueState(cues[i], <String, Object?>{
          ...cues[i].options,
          'seed': seed + i,
        }),
    ];
    return _ChainSim(list);
  };
}

/// Reuse an act's keys in a longer move: later by [dt], moved along by [dx], with [over] laid over.
List<PoseKey> shiftKeys(
  List<PoseKey> keys,
  double dt, {
  double dx = 0.0,
  Pose? over,
}) =>
    [
      for (final k in keys)
        PoseKey(
          k.t + dt,
          (over != null ? k.pose.merge(over) : k.pose)
              .copyWith(x: (k.pose.x ?? 0.0) + dx),
          k.how,
        ),
    ];

List<HitSpec> shiftHits(List<HitSpec> hits, double dt) =>
    [for (final h in hits) h.shifted(dt)];
