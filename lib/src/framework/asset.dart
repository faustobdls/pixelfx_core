// Core asset abstractions shared by built-in effects and multi-domain extensions.

import '../core/frame.dart';
import '../core/painter.dart';
import '../core/scene.dart';

enum DrawLayer { back, front, both }

enum AssetKind {
  effect,
  act,
  move,
  character,
  tileset,
  prop,
  uiElement,
  custom,
}

class AssetMeta {
  final String id;
  final String name;
  final String desc;
  final AssetKind kind;
  final String category;
  final List<String> tags;
  final (int w, int h) size;
  final (int ox, int oy) origin;
  final double duration;
  final bool loop;
  final int fps;
  final BackdropKind bg;
  final int actorScale;
  final Map<String, Object?> defaultOptions;
  final Map<String, Object?> extra;

  const AssetMeta({
    required this.id,
    required this.name,
    required this.desc,
    required this.kind,
    required this.category,
    this.tags = const [],
    required this.size,
    required this.origin,
    this.duration = 1.0,
    this.loop = false,
    this.fps = 30,
    this.bg = BackdropKind.dark,
    this.actorScale = 0,
    this.defaultOptions = const {},
    this.extra = const {},
  });

  bool get hasActor => actorScale > 0;
  int get width => size.$1;
  int get height => size.$2;
  int get originX => origin.$1;
  int get originY => origin.$2;
}

abstract interface class AssetInstance {
  double get t;
  Map<String, Object?> get options;
  void update(double dt);
  void draw(PixelFrame frame, [DrawLayer layer = DrawLayer.both]);
  void stop();
  bool get done;
}

abstract interface class PixelAsset {
  AssetMeta get meta;
  AssetInstance createInstance([Map<String, Object?> options = const {}]);
}

/// Base class for static (or single-frame) programmatic pixel assets such as
/// tilesets, props, sprites, and UI badges (`duration: 0`, `loop: false`).
abstract class StaticPixelAsset implements PixelAsset {
  const StaticPixelAsset();

  void drawStatic(Painter p, Map<String, Object?> options);

  @override
  AssetInstance createInstance([Map<String, Object?> options = const {}]) =>
      _StaticAssetInstance(this, options);
}

class _StaticAssetInstance implements AssetInstance {
  final StaticPixelAsset asset;
  @override
  final Map<String, Object?> options;
  double _t = 0.0;

  _StaticAssetInstance(this.asset, Map<String, Object?> opts)
      : options = {
          ...asset.meta.defaultOptions,
          ...opts,
        };

  @override
  double get t => _t;

  @override
  void update(double dt) => _t += dt;

  @override
  void draw(PixelFrame frame, [DrawLayer layer = DrawLayer.both]) {
    if (layer == DrawLayer.back) return;
    final p = painterFor(frame);
    final x = (options['x'] as num?)?.toDouble() ?? 0.0;
    final y = (options['y'] as num?)?.toDouble() ?? 0.0;
    final flip = (options['flip'] as bool?) ?? false;
    final angle = (options['angle'] as num?)?.toDouble() ?? 0.0;
    p.place(x, y, flip: flip, angle: angle);
    asset.drawStatic(p, options);
  }

  @override
  void stop() {}

  @override
  bool get done => true;
}
