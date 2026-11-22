## 0.2.0

- Add `BackdropKind.isoGrid` with crisp 2:1 dimetric diamond tiles and subtle vignette.
- Add `kIsoCameraPitch`, optional `pitch` projection support in `RigRasterizer` (`posed`, `skeleton`, `posedParts`), and per-pitch cache keys while preserving 100% bit-exact 2D output when `pitch == 0.0`.

## 0.1.0

- Initial release: 1:1 pure-Dart port of dual-buffer `PixelFrame` (`color` + additive `light`), `Painter` (with `NaN` guard on `add` and `blendPx`), 120 Hz physics (`Particles`, `Bits`, `Lights`, `Blazes`), 3D IK `RigRasterizer`, `ActSpec`, `chain`, and multi-domain extension SPI (`PixelFxRegistry`, `PixelFxExtension`, `AssetArchetype`, `PostProcessor`, `AssetExporter`, `CheckRule`).
