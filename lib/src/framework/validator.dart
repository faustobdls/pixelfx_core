// Validation contracts for `pixelfx check` and custom extension archetype rules.

import 'dart:typed_data';

import 'asset.dart';

enum CheckSeverity { error, warning }

class CheckIssue {
  final CheckSeverity severity;
  final String code;
  final String message;

  const CheckIssue(this.severity, this.code, this.message);

  bool get isError => severity == CheckSeverity.error;
  bool get isWarning => severity == CheckSeverity.warning;

  @override
  String toString() => '[$code] $message';
}

class CheckReport {
  final String assetId;
  final List<CheckIssue> issues;
  final double? medianFrameMs;

  const CheckReport(
    this.assetId,
    this.issues, {
    this.medianFrameMs,
  });

  List<CheckIssue> get errors =>
      issues.where((i) => i.isError).toList(growable: false);

  List<CheckIssue> get warnings =>
      issues.where((i) => i.isWarning).toList(growable: false);

  bool get hasErrors => issues.any((i) => i.isError);
  bool get hasWarnings => issues.any((i) => i.isWarning);
  bool get passed => !hasErrors;
}

class CheckContext {
  final PixelAsset asset;
  final List<Uint32List> rawColorFrames;
  final List<Uint32List> rawLightFrames;
  final double medianFrameMs;
  final String? sourceCode;

  const CheckContext({
    required this.asset,
    required this.rawColorFrames,
    required this.rawLightFrames,
    required this.medianFrameMs,
    this.sourceCode,
  });
}

abstract class CheckRule {
  String get id;
  List<CheckIssue> validate(CheckContext ctx);
}
