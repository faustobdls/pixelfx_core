// Exporter abstractions and pure-Dart Aseprite JSON formatter.

import 'dart:convert';
import 'dart:typed_data';

import '../core/act.dart';
import '../core/fx.dart';
import 'asset.dart';

class ExportArtifact {
  final String filename;
  final Uint8List bytes;
  final String mimeType;

  const ExportArtifact({
    required this.filename,
    required this.bytes,
    required this.mimeType,
  });
}

class AssetExportFrame {
  final double t;
  final Uint8List clearRgba;
  final Uint8List compositedRgba;

  const AssetExportFrame({
    required this.t,
    required this.clearRgba,
    required this.compositedRgba,
  });
}

class AssetExportInput {
  final PixelAsset asset;
  final String shortName;
  final int width;
  final int height;
  final int fps;
  final int columns;
  final List<AssetExportFrame> frames;

  const AssetExportInput({
    required this.asset,
    required this.shortName,
    required this.width,
    required this.height,
    required this.fps,
    required this.columns,
    required this.frames,
  });
}

abstract class AssetExporter {
  String get id;
  List<ExportArtifact> export(AssetExportInput input);
}

/// Formats Aseprite-compatible sprite-sheet metadata JSON matching `patch-gg/pixelfx`.
abstract final class AsepriteJsonFormatter {
  static Map<String, Object?> build({
    required PixelAsset asset,
    required String name,
    required int frameWidth,
    required int frameHeight,
    required int frameCount,
    required int fps,
    required int columns,
    (int, int)? pivotOverride,
  }) {
    final rows = (frameCount / columns).ceil();
    final meta = asset.meta;
    final frameDur = (1000.0 / fps).round();
    final framesList = <Map<String, Object?>>[];
    for (var i = 0; i < frameCount; i++) {
      final x = (i % columns) * frameWidth;
      final y = (i ~/ columns) * frameHeight;
      framesList.add({
        'filename': '$name $i',
        'frame': {'x': x, 'y': y, 'w': frameWidth, 'h': frameHeight},
        'rotated': false,
        'trimmed': false,
        'spriteSourceSize': {'x': 0, 'y': 0, 'w': frameWidth, 'h': frameHeight},
        'sourceSize': {'w': frameWidth, 'h': frameHeight},
        'duration': frameDur,
      });
    }

    final pivot = pivotOverride ?? meta.origin;
    final actData = asset is PixelEffect ? actTiming(asset) : null;

    return {
      'frames': framesList,
      'meta': {
        'app': 'https://github.com/faustobdls/pixelfx_flutter',
        'version': '1',
        'image': '$name.png',
        'format': 'RGBA8888',
        'size': {'w': columns * frameWidth, 'h': rows * frameHeight},
        'scale': '1',
        'frameTags': [
          {
            'name': name,
            'from': 0,
            'to': frameCount - 1,
            'direction': 'forward',
          },
        ],
        'pixelfx': {
          'id': meta.id,
          'name': meta.name,
          'fps': fps,
          'loop': meta.loop,
          'frames': frameCount,
          'frameSize': [frameWidth, frameHeight],
          'pivot': [pivot.$1, pivot.$2],
          'columns': columns,
          if (actData != null) 'act': actData.toJson(),
          if (meta.extra.isNotEmpty) 'extra': meta.extra,
        },
      },
    };
  }

  static String encodePretty({
    required PixelAsset asset,
    required String name,
    required int frameWidth,
    required int frameHeight,
    required int frameCount,
    required int fps,
    required int columns,
    (int, int)? pivotOverride,
  }) =>
      const JsonEncoder.withIndent(' ').convert(
        build(
          asset: asset,
          name: name,
          frameWidth: frameWidth,
          frameHeight: frameHeight,
          frameCount: frameCount,
          fps: fps,
          columns: columns,
          pivotOverride: pivotOverride,
        ),
      );
}
