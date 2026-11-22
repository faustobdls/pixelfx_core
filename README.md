# pixelfx_core

Deterministic, zero-dependency pure-Dart engine for dual-buffer (`color` + additive `light`) procedural pixel art VFX, 3D IK pixel rig, acted combat choreography (`ActSpec`), 120 Hz particle/debris physics, and a multi-domain asset extension SPI (`PixelFxRegistry`, `PixelFxExtension`).

Ported 1:1 from [`patch-gg/pixelfx`](https://github.com/patch-gg/pixelfx) (MIT).

## Usage

```dart
import 'package:pixelfx_core/pixelfx_core.dart';

final frame = createFrame(64, 64);
final p = painterFor(frame)..place(32, 48);
p.circle(0, -10, 6, hex('#ffae35'));
p.glow(0, -10, 16, hex('#ff701f'), 0.6);
```

See the root workspace documentation and [`NOTICE.md`](NOTICE.md) for MIT attributions.
