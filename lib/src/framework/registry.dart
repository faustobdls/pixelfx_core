// Composable registry uniting extensions, built-in resources, search, and act instantiation.

import '../core/act.dart';
import '../core/act_spec.dart';
import '../core/color.dart';
import '../core/fx.dart';
import '../core/rig.dart';
import 'archetype.dart';
import 'asset.dart';
import 'exporter.dart';
import 'extension.dart';
import 'post_fx.dart';
import 'validator.dart';

class RegisteredAsset {
  final PixelAsset asset;
  final String extensionId;

  const RegisteredAsset(this.asset, this.extensionId);
}

class PixelFxRegistry {
  final List<PixelFxExtension> _extensions = [];
  final Map<String, CategoryMeta> _categories = {};
  final Map<String, RegisteredAsset> _assets = {};
  final Map<String, AssetArchetype> _archetypes = {};
  final Map<String, List<String>> _palettes = {...Pal.all};
  final Map<String, PostProcessor> _postProcessors = {};
  final Map<String, AssetExporter> _exporters = {};
  final List<CheckRule> _globalCheckRules = [];

  final WeaponRegistry weapons = WeaponRegistry();
  final SkinRegistry skins = SkinRegistry();
  late final RigRasterizer rig = RigRasterizer(weapons);

  PixelFxRegistry({bool registerBuiltIns = true}) {
    if (registerBuiltIns) {
      registerArchetype(EffectArchetype());
      registerArchetype(ActArchetype());
      registerPostProcessor(EdgeFadePostFx());
    }
  }

  void register(PixelFxExtension extension) {
    final extId = extension.manifest.id;
    if (_extensions.any((e) => e.manifest.id == extId)) {
      throw StateError('Extension "$extId" is already registered.');
    }
    _extensions.add(extension);

    for (final cat in extension.categories) {
      _categories[cat.id] = cat;
    }
    for (final asset in extension.assets) {
      _assets[asset.meta.id] = RegisteredAsset(asset, extId);
    }
    for (final arch in extension.archetypes) {
      _archetypes[arch.id] = arch;
    }
    weapons.registerAll(extension.weapons);
    skins.registerAll(extension.skins);
    _palettes.addAll(extension.palettes);
    _postProcessors.addAll(extension.postProcessors);
    _exporters.addAll(extension.exporters);
    _globalCheckRules.addAll(extension.globalCheckRules);
  }

  void registerAsset(PixelAsset asset, {String extensionId = 'local'}) {
    _assets[asset.meta.id] = RegisteredAsset(asset, extensionId);
  }

  void registerArchetype(AssetArchetype archetype) {
    _archetypes[archetype.id] = archetype;
  }

  void registerPostProcessor(PostProcessor processor) {
    _postProcessors[processor.id] = processor;
  }

  List<PixelFxExtension> get extensions => List.unmodifiable(_extensions);
  List<CategoryMeta> get categories => _categories.values.toList(growable: false);
  List<PixelAsset> get assets =>
      _assets.values.map((e) => e.asset).toList(growable: false);
  Map<String, AssetArchetype> get archetypes => Map.unmodifiable(_archetypes);
  Map<String, List<String>> get palettes => Map.unmodifiable(_palettes);
  Map<String, PostProcessor> get postProcessors =>
      Map.unmodifiable(_postProcessors);
  Map<String, AssetExporter> get exporters => Map.unmodifiable(_exporters);

  PixelAsset? getAsset(String id) => _assets[id]?.asset;

  PixelEffect? getEffect(String id) {
    final a = getAsset(id);
    return a is PixelEffect ? a : null;
  }

  String? extensionIdForAsset(String id) => _assets[id]?.extensionId;

  List<CheckRule> allCheckRulesFor(PixelAsset asset) {
    final out = <CheckRule>[..._globalCheckRules];
    final archId = asset.meta.extra['archetype'] as String? ?? asset.meta.kind.name;
    final arch = _archetypes[archId];
    if (arch != null) out.addAll(arch.checkRules);
    return out;
  }

  List<PixelAsset> search(
    List<String> terms, {
    AssetKind? kind,
    String? category,
    String? extensionId,
  }) {
    final lowerTerms = [for (final t in terms) t.toLowerCase()];
    final out = <PixelAsset>[];
    for (final entry in _assets.values) {
      if (extensionId != null && entry.extensionId != extensionId) continue;
      final a = entry.asset;
      final m = a.meta;
      if (kind != null && m.kind != kind) continue;
      if (category != null && m.category != category) continue;
      if (lowerTerms.isNotEmpty) {
        final hay =
            '${m.id} ${m.name} ${m.desc} ${m.category} ${m.tags.join(' ')}'
                .toLowerCase();
        if (!lowerTerms.every(hay.contains)) continue;
      }
      out.add(a);
    }
    return out;
  }

  ActInstance createActFor(
    PixelEffect effect, [
    Map<String, Object?> options = const {},
  ]) =>
      createAct(effect, options, rig, skins);

  ActBounds actBoundsFor(PixelEffect effect) => actBounds(effect, rig);
}
