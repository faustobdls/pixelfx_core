// Frames, effect metadata, and live effect instances with 120 Hz deterministic sub-stepping.

import 'dart:math' as math;

import '../framework/asset.dart';
import 'act_spec.dart';
import 'actor.dart';
import 'color.dart';
import 'frame.dart';
import 'math.dart';
import 'painter.dart';
import 'scene.dart';

const double _fadeDuration = 0.3;

class EffectMeta extends AssetMeta {
  const EffectMeta({
    required super.id,
    required super.name,
    required super.desc,
    super.kind = AssetKind.effect,
    super.category = '',
    super.tags = const [],
    required super.size,
    required super.origin,
    super.duration = 1.0,
    super.loop = false,
    super.fps = 30,
    super.bg = BackdropKind.dark,
    super.actorScale = 0,
    super.defaultOptions = const {},
    super.extra = const {},
  });

  String get effectiveCategory =>
      category.isNotEmpty ? category : (id.contains('/') ? id.split('/').first : '');
}

/// Stateful simulation instance created by a [SimulatedEffect].
abstract interface class EffectSim {
  void update(double dt, Map<String, Object?> options);
  void draw(Painter p);
  void drawBack(Painter p) {}
}

/// Convenience base class for simulated effects where `drawBack` is optional.
abstract class BaseEffectSim implements EffectSim {
  @override
  void drawBack(Painter p) {}
}

/// Base class for all pixel effects (pure or simulated), implementing [PixelAsset].
abstract class PixelEffect implements PixelAsset {
  const PixelEffect();

  @override
  EffectMeta get meta;

  ActSpec? get act => null;

  bool get isSimulated => false;

  double actorAlpha(double t, Map<String, Object?> options) => 1.0;

  @override
  EffectInstance createInstance([Map<String, Object?> options = const {}]) =>
      createFx(this, options);
}

/// Pure stateless effect: frame at time `t` is computed solely from `(p, t, o)`.
class PureEffect extends PixelEffect {
  @override
  final EffectMeta meta;

  @override
  final ActSpec? act;

  final void Function(Painter p, double t, Map<String, Object?> o) onDraw;
  final void Function(Painter p, double t, Map<String, Object?> o)? onDrawBack;
  final double Function(double t, Map<String, Object?> o)? onActorAlpha;

  const PureEffect({
    required this.meta,
    required this.onDraw,
    this.onDrawBack,
    this.act,
    this.onActorAlpha,
  });

  @override
  double actorAlpha(double t, Map<String, Object?> options) =>
      onActorAlpha?.call(t, options) ?? 1.0;
}

/// Simulated stateful effect: spawns state via `create(options)` and steps at >= 120 Hz.
class SimulatedEffect extends PixelEffect {
  @override
  final EffectMeta meta;

  @override
  final ActSpec? act;

  final EffectSim Function(Map<String, Object?> o) onCreate;
  final double Function(double t, Map<String, Object?> o)? onActorAlpha;

  const SimulatedEffect({
    required this.meta,
    required this.onCreate,
    this.act,
    this.onActorAlpha,
  });

  @override
  bool get isSimulated => true;

  @override
  double actorAlpha(double t, Map<String, Object?> options) =>
      onActorAlpha?.call(t, options) ?? 1.0;
}

/// Resolve an effect's options: defaults with caller's overrides on top.
/// Any color ramp of a different length than its default is resampled to the default's length.
Map<String, Object?> resolveOptions(
  AssetMeta meta, [
  Map<String, Object?> o = const {},
]) {
  final opts = <String, Object?>{...meta.defaultOptions, ...o};
  for (final entry in meta.defaultOptions.entries) {
    final k = entry.key;
    final def = entry.value;
    final passed = o[k];
    if (isColorRamp(def) &&
        isColorRamp(passed) &&
        (passed as List).length != (def as List).length) {
      opts[k] = fit(passed.cast<Object>(), def.length)
          .map(toHex)
          .toList(growable: false);
    }
  }
  if (meta.hasActor && opts['actor'] == null) {
    opts['actor'] = stockActor(meta.actorScale == 2 ? 2 : 1);
  }
  return opts;
}

double actorAlphaOf(
  PixelEffect mod,
  double t,
  Map<String, Object?> options,
) =>
    mod.actorAlpha(t, options);

/// A live instance of a [PixelEffect].
class EffectInstance implements AssetInstance {
  final PixelEffect effect;
  final EffectMeta meta;
  @override
  final Map<String, Object?> options;

  final EffectSim? _sim;
  final PureEffect? _pure;
  final double _duration;

  double _t = 0.0;
  double _stopAt = double.infinity;

  EffectInstance._({
    required this.effect,
    required this.meta,
    required this.options,
    this._sim,
    this._pure,
  }) : _duration = meta.duration;

  @override
  double get t => _t;

  @override
  void update(double dt) {
    _t += dt;
    final sim = _sim;
    if (sim == null) return;
    // Simulations step at 120 Hz or finer whatever the caller's frame rate.
    final n = math.max(1, (dt * 120.0 - 1e-9).ceil());
    final step = dt / n;
    for (var i = 0; i < n; i++) {
      sim.update(step, options);
    }
  }

  @override
  void draw(PixelFrame frame, [DrawLayer layer = DrawLayer.both]) {
    final p = painterFor(frame);
    final x = (options['x'] as num?)?.toDouble() ?? 0.0;
    final y = (options['y'] as num?)?.toDouble() ?? 0.0;
    final flip = (options['flip'] as bool?) ?? false;
    final angle = (options['angle'] as num?)?.toDouble() ?? 0.0;
    p.place(x, y, flip: flip, angle: angle);
    p.fade = _stopAt.isInfinite
        ? 1.0
        : clamp(1.0 - (_t - _stopAt) / _fadeDuration);
    p.lightK = (options['light'] as num?)?.toDouble() ?? 1.0;

    final tt = meta.loop ? (_t % _duration) : math.min(_t, _duration);
    final sim = _sim;
    final pure = _pure;

    if (sim != null) {
      if (layer != DrawLayer.front) {
        p.layer = 'back';
        sim.drawBack(p);
      }
      if (layer != DrawLayer.back) {
        p.layer = 'front';
        sim.draw(p);
      }
    } else if (pure != null) {
      if (layer != DrawLayer.front && pure.onDrawBack != null) {
        p.layer = 'back';
        pure.onDrawBack!(p, tt, options);
      }
      if (layer != DrawLayer.back) {
        p.layer = 'front';
        pure.onDraw(p, tt, options);
      }
    }
  }

  @override
  void stop() {
    if (_stopAt.isInfinite) _stopAt = _t;
  }

  @override
  bool get done =>
      (_t - _stopAt >= _fadeDuration) || (!meta.loop && _t >= _duration);
}

EffectInstance createFx(
  PixelEffect mod, [
  Map<String, Object?> options = const {},
]) {
  final meta = mod.meta;
  final opts = resolveOptions(meta, options);
  if (mod is SimulatedEffect) {
    return EffectInstance._(
      effect: mod,
      meta: meta,
      options: opts,
      sim: mod.onCreate(opts),
    );
  }
  if (mod is PureEffect) {
    return EffectInstance._(
      effect: mod,
      meta: meta,
      options: opts,
      pure: mod,
    );
  }
  throw ArgumentError('Unsupported PixelEffect subtype: ${mod.runtimeType}');
}

/// Helper extension for concise typed option access inside effects.
extension FxOptionsExt on Map<String, Object?> {
  int get seed => (this['seed'] as num?)?.toInt() ?? 1;
  List<Object> get palette => (this['palette'] as List).cast<Object>();
  ActorDefinition get actor => this['actor'] as ActorDefinition;
  double numOpt(String key, [double fallback = 0.0]) =>
      (this[key] as num?)?.toDouble() ?? fallback;
  int intOpt(String key, [int fallback = 0]) =>
      (this[key] as num?)?.toInt() ?? fallback;
  bool boolOpt(String key, [bool fallback = false]) =>
      (this[key] as bool?) ?? fallback;
  String strOpt(String key, [String fallback = '']) =>
      (this[key] as String?) ?? fallback;
  List<Object> rampOpt(String key) => (this[key] as List).cast<Object>();
}
