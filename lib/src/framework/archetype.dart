// Archetypes allow extensions to introduce entirely new programmatic asset domains
// (e.g. tilesets, 2D character sheets, props, UI elements) with tailored checks & templates.

import 'asset.dart';
import 'exporter.dart';
import 'validator.dart';

class ContactSheetLayout {
  final int maxFrames;
  final int? defaultCols;
  final int? defaultZoom;
  final bool showGrid;
  final int cellPadding;

  const ContactSheetLayout({
    this.maxFrames = 16,
    this.defaultCols,
    this.defaultZoom,
    this.showGrid = false,
    this.cellPadding = 8,
  });
}

abstract class AssetArchetype {
  String get id;
  AssetKind get kind;
  String get description;
  List<CheckRule> get checkRules => const [];
  ContactSheetLayout get previewLayout => const ContactSheetLayout();
  AssetExporter? get defaultExporter => null;

  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  });
}

class EffectArchetype extends AssetArchetype {
  @override
  String get id => 'effect';

  @override
  AssetKind get kind => AssetKind.effect;

  @override
  String get description =>
      'Code-driven dual-buffer pixel art VFX (pure time-function or 120 Hz simulated).';

  @override
  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  }) {
    final loop = params['loop'] == 'true';
    final cat = id.contains('/') ? id.split('/').first : 'custom';
    final title = id.split('/').last.replaceAll('-', ' ');
    return '''
import 'package:pixelfx_core/pixelfx_core.dart';

final $className = PureEffect(
  meta: EffectMeta(
    id: '$id',
    name: '$title',
    desc: 'One line: what it is, how it moves.',
    category: '$cat',
    tags: const ['$cat', '${loop ? 'loop' : 'one-shot'}'],
    size: (48, 48),
    origin: (24, 32),
    duration: ${loop ? 1.2 : 0.7},
    loop: $loop,
    fps: 30,
    bg: BackdropKind.dark,
    defaultOptions: {'palette': Pal.arcane, 'seed': 1},
  ),
  onDraw: (p, t, o) {
    final c = ramp(o.palette);
    p.circle(0, -8, 6, c[4]);
    p.glow(0, -8, 18, c[4], 0.4);
  },
);
''';
  }
}

class ActArchetype extends EffectArchetype {
  @override
  String get id => 'act';

  @override
  AssetKind get kind => AssetKind.act;

  @override
  String get description =>
      'Effect performed with a 3D skeletal actor, wind-up, hit-stop, shake and target reaction.';
}
