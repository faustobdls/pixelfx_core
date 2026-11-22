## Unreleased

- Guard `Painter.add` and `Painter.blendPx` against `NaN` alpha/intensity values (`!(value > 0.004)`), preventing integer conversion crashes in catalog effects.
- Update standalone GitHub Actions CI & pub.dev OIDC publish workflows using `_ci_workspace` isolation so `dart pub publish --dry-run` keeps `git status` clean, plus `workflow_dispatch` `dry_run` support and `CHANGELOG.md` release checks.

## 0.1.0

- Initial Wave 0 release: 1:1 pure-Dart port of dual-buffer `PixelFrame` (`color` + additive `light`), `Painter`, 120 Hz physics (`Particles`, `Bits`, `Lights`, `Blazes`), 3D IK `RigRasterizer`, `ActSpec`, `chain`, and multi-domain extension SPI (`PixelFxRegistry`, `PixelFxExtension`, `AssetArchetype`, `PostProcessor`, `AssetExporter`, `CheckRule`).
