// Extension contract for adding packs of effects, archetypes, 3D weapons, skins,
// palettes, post-processors, exporters, and check rules in a single cohesive module.

import '../core/act_spec.dart';
import '../core/rig.dart';
import 'archetype.dart';
import 'asset.dart';
import 'exporter.dart';
import 'post_fx.dart';
import 'validator.dart';

class ExtensionManifest {
  final String id;
  final String name;
  final String version;
  final String description;
  final String? author;
  final List<String> tags;

  const ExtensionManifest({
    required this.id,
    required this.name,
    this.version = '0.1.0',
    required this.description,
    this.author,
    this.tags = const [],
  });
}

class CategoryMeta {
  final String id;
  final String name;
  final String blurb;

  const CategoryMeta({
    required this.id,
    required this.name,
    required this.blurb,
  });
}

abstract class PixelFxExtension {
  ExtensionManifest get manifest;

  List<CategoryMeta> get categories => const [];
  List<PixelAsset> get assets => const [];
  List<AssetArchetype> get archetypes => const [];
  Map<String, WeaponSpec> get weapons => const {};
  Map<String, SkinSpec> get skins => const {};
  Map<String, List<String>> get palettes => const {};
  Map<String, PostProcessor> get postProcessors => const {};
  Map<String, AssetExporter> get exporters => const {};
  List<CheckRule> get globalCheckRules => const [];
}
