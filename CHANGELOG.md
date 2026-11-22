## 0.1.0

- Initial release: 1:1 pure-Dart port of dual-buffer `PixelFrame` (`color` + additive `light`), `Painter` (with `NaN` guard on `add` and `blendPx`), 120 Hz physics (`Particles`, `Bits`, `Lights`, `Blazes`), 3D IK `RigRasterizer`, `ActSpec`, `chain`, and multi-domain extension SPI (`PixelFxRegistry`, `PixelFxExtension`, `AssetArchetype`, `PostProcessor`, `AssetExporter`, `CheckRule`).
- Configured standalone GitHub Actions CI & pub.dev OIDC automated publishing workflows using `_ci_workspace` isolation.
