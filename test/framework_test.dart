import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:test/test.dart';

class _TileArchetype extends AssetArchetype {
  @override
  String get id => 'tileset';

  @override
  AssetKind get kind => AssetKind.tileset;

  @override
  String get description => 'Procedural 16x16 game tiles.';

  @override
  List<CheckRule> get checkRules => [
        _NonEmptyRule(),
      ];

  @override
  String scaffoldTemplate({
    required String id,
    required String className,
    Map<String, String> params = const {},
  }) =>
      'class $className {} // $id';
}

class _NonEmptyRule extends CheckRule {
  @override
  String get id => 'tileset-non-empty';

  @override
  List<CheckIssue> validate(CheckContext ctx) {
    final hasAny = ctx.rawColorFrames.any((buf) => buf.any((c) => c != 0));
    if (!hasAny) {
      return const [
        CheckIssue(CheckSeverity.error, 'tileset-empty', 'Tile drew nothing'),
      ];
    }
    return const [];
  }
}

class _GrassTile extends StaticPixelAsset {
  @override
  AssetMeta get meta => const AssetMeta(
        id: 'nordeste/sertão-tile',
        name: 'Sertão Tile',
        desc: '16x16 procedural cracked earth and cactus pixel tile.',
        kind: AssetKind.tileset,
        category: 'tiles',
        tags: ['tile', 'earth'],
        size: (16, 16),
        origin: (0, 0),
        duration: 0,
        loop: false,
        defaultOptions: {'palette': Pal.earth},
        extra: {'archetype': 'tileset', 'tileSize': 16},
      );

  @override
  void drawStatic(Painter p, Map<String, Object?> options) {
    final c = ramp(options.palette);
    p.rect(0, 0, 16, 16, c[2]);
    p.px(4, 4, c[5]);
  }
}

class _InversePostFx extends PostProcessor {
  @override
  String get id => 'warm-tint';

  @override
  void apply(PixelFrame frame, double t, Map<String, Object?> options) {
    for (var i = 0; i < frame.color.length; i++) {
      if (frame.color[i] != 0) {
        frame.light[i] = kWhite;
      }
    }
  }
}

class _DemoExtension extends PixelFxExtension {
  @override
  ExtensionManifest get manifest => const ExtensionManifest(
        id: 'nordeste-pack',
        name: 'Nordeste RPG Pack',
        description: 'Custom weapons, tileset archetype, palettes, and post-fx.',
        author: 'Fausto BDLS',
      );

  @override
  List<CategoryMeta> get categories => const [
        CategoryMeta(id: 'tiles', name: 'tiles', blurb: 'Procedural 16x16 tiles'),
      ];

  @override
  List<AssetArchetype> get archetypes => [_TileArchetype()];

  @override
  List<PixelAsset> get assets => [_GrassTile()];

  @override
  Map<String, List<String>> get palettes => const {
        'sertao': ['#1b0f0a', '#4b2416', '#8b4a24', '#d88234', '#ffd06b'],
      };

  @override
  Map<String, WeaponSpec> get weapons => {
        'peixeira': WeaponSpec(
          draw: (t, q, _) {
            final blade = hex('#e8edf6');
            for (var i = 2.0; i <= 11.0; i += 0.4) {
              t(i, 0, blade);
            }
          },
        ),
      };

  @override
  Map<String, SkinSpec> get skins => {
        'sol': SkinSpec(hex('#ffae35'), 0.6),
      };

  @override
  Map<String, PostProcessor> get postProcessors => {
        'warm-tint': _InversePostFx(),
      };
}

void main() {
  test('PixelFxRegistry integrates multi-domain extensions cleanly', () {
    final registry = PixelFxRegistry()..register(_DemoExtension());

    expect(registry.extensions.length, 1);
    expect(registry.archetypes.containsKey('tileset'), isTrue);
    expect(registry.palettes.containsKey('sertao'), isTrue);
    expect(registry.weapons['peixeira'], isNotNull);
    expect(registry.skins['sol'], isNotNull);
    expect(registry.postProcessors['warm-tint'], isNotNull);

    final tile = registry.getAsset('nordeste/sertão-tile')!;
    final rules = registry.allCheckRulesFor(tile);
    expect(rules.any((r) => r.id == 'tileset-non-empty'), isTrue);

    final inst = tile.createInstance();
    final frame = createFrame(16, 16);
    inst.draw(frame);
    expect(frame.color[0], isNot(0));
    expect(inst.done, isTrue);

    // Ensure the custom weapon actually rasterizes through the registry's RigRasterizer
    final customPose = registry.rig.posed(
      const Pose(weapon: 'peixeira', fx: 12, fy: -20, sa: 0),
    );
    expect(customPose.n, greaterThan(450));

    // Verify Aseprite JSON formatter
    final json = AsepriteJsonFormatter.build(
      asset: tile,
      name: 'sertao-tile',
      frameWidth: 16,
      frameHeight: 16,
      frameCount: 1,
      fps: 30,
      columns: 1,
    );
    expect((json['frames'] as List).length, 1);
  });
}
