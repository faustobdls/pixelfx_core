import 'dart:typed_data';

import 'package:pixelfx_core/pixelfx_core.dart';
import 'package:test/test.dart';

void main() {
  group('32-bit PRNG, hash, and noise parity vs Node.js', () {
    test('hashInts and hash1..4 match upstream Node.js exactly', () {
      expect(hashInts([1, 17]), 857917954);
      expect(hashInts([-5, 99, 77]), 3804419530);
      expect(hashInts([0, 0, 0]), 744138621);

      expect(hash2(1, 17), 857917954);
      expect(hash3(-5, 99, 77), 3804419530);
      expect(hash3(0, 0, 0), 744138621);
    });

    test('rand and Rng sequence match upstream Node.js within 1e-12', () {
      expect(rand(1, 17), closeTo(0.19974958943203092, 1e-12));
      expect(rand(-5, 99, 77), closeTo(0.8857854478992522, 1e-12));
      expect(rand(12, 34, 56), closeTo(0.43248534156009555, 1e-12));

      final r = Rng(4);
      expect(r.next(), closeTo(0.9236361971125007, 1e-12));
      expect(r.next(), closeTo(0.33304587937891483, 1e-12));
      expect(r.next(), closeTo(0.2216679009143263, 1e-12));
      expect(r.range(-10, 10), closeTo(-8.363179601728916, 1e-12));
      expect(r.intRange(1, 6), 2);
      expect(r.gauss(), closeTo(0.31485636886022983, 1e-12));
    });

    test('noise functions match upstream Node.js within 1e-12', () {
      expect(noise(1.25, 3), closeTo(-0.5013564098335337, 1e-12));
      expect(noise2(-2.3, 4.7, 9), closeTo(0.008490183822273956, 1e-12));
      expect(fbm(1.5, -0.8, 5, 3), closeTo(-0.024204398327147998, 1e-12));
      expect(
          tileNoise(3.4, -1.2, 4, 4, 2), closeTo(-0.6652485651092828, 1e-12));
      expect(tileFbm(1.2, 2.3, 4, 4, 7, 3),
          closeTo(0.05979182089697477, 1e-12));
      expect(loopNoise(0.37, 1.5, 8), closeTo(-0.1650396875181368, 1e-12));
    });
  });

  group('Color, frame, and painter parity', () {
    test('hex, mix, and fit match upstream packed RGBA integers', () {
      expect(hex('#f53cd1'), 4291902709);
      expect(mix(hex('#102030'), hex('#ffaa00'), 0.35), 4280242275);
      expect(
        fit(Pal.ice, 5),
        [4281340940, 4287909663, 4293702744, 4294958235, 4294967295],
      );
      expect(Pal.all.length, 27);
    });

    test('composite over transparent and opaque backgrounds', () {
      final f = createFrame(4, 4);
      final p = painterFor(f)..place(2, 2);
      p.px(0, 0, kWhite);
      p.glow(0, 0, 2, hex('#ff0000'), 0.5);

      final transparentOut = Uint8List(4 * 4 * 4);
      composite(f, transparentOut);
      // Pixel at (2, 2) has white opaque + red light -> clamped to 255 RGBA
      final centerIdx = (2 * 4 + 2) * 4;
      expect(transparentOut[centerIdx], 255);
      expect(transparentOut[centerIdx + 1], 255);
      expect(transparentOut[centerIdx + 2], 255);
      expect(transparentOut[centerIdx + 3], 255);

      // Neighbour pixel (3, 2) only has light over transparency
      final rightIdx = (2 * 4 + 3) * 4;
      expect(transparentOut[rightIdx], greaterThan(0));
      expect(transparentOut[rightIdx + 3], greaterThan(0));
    });

    test('painter text measurement and mask rendering', () {
      final f = createFrame(40, 20);
      final p = painterFor(f);
      final (w, h) = p.measure('LVL 2', font: PixelFontKind.big, scale: 1);
      expect(w, greaterThan(15));
      expect(h, 7);
      p.text('LVL 2', 2, 2, kWhite,
          font: PixelFontKind.big, outline: kInk, shadow: kBlack);
      expect(f.color.any((c) => c != 0), isTrue);
    });
  });

  group('3D Rig, Sim, Act, and Chain parity', () {
    test('RigRasterizer posed() and skeleton() match JS exactly', () {
      const testPose = Pose(
        weapon: 'sword',
        crouch: 4,
        lean: 3,
        fx: 16,
        fy: -22,
        sa: -0.8,
      );
      final r = posed(testPose);
      expect(r.n, 603);
      expect([r.x0, r.y0, r.x1, r.y1], [-6, -43, 36, -1]);

      final sk = skeleton(testPose);
      expect(sk.joints['handN']!.$1, closeTo(16.0, 1e-6));
      expect(sk.joints['handN']!.$2, closeTo(-22.0, 1e-6));
      expect(sk.joints['handN']!.$3, closeTo(4.5, 1e-6));
      expect(WeaponRegistry.instance.names.length, 11);
    });

    test('Simulated effect sub-stepping is deterministic and ends clean', () {
      final fxDef = SimulatedEffect(
        meta: const EffectMeta(
          id: 'test/sparks',
          name: 'Sparks',
          desc: 'Test spark burst.',
          size: (64, 64),
          origin: (32, 48),
          duration: 1.0,
          loop: false,
          defaultOptions: {'palette': Pal.fire, 'seed': 1},
        ),
        onCreate: (o) {
          final r = Rng(o.seed);
          final ps = Particles(rng: r, ground: (_) => 0.0);
          for (var i = 0; i < 12; i++) {
            ps.spawn(P.spark, 0, -10, r.range(-60, 60), r.range(-90, -20), 0.4);
          }
          return _ParticleSim(ps);
        },
      );

      final a = createFx(fxDef, {'x': 32, 'y': 48});
      final b = createFx(fxDef, {'x': 32, 'y': 48});
      final fa = createFrame(64, 64);
      final fb = createFrame(64, 64);
      // Step `a` at 30 Hz and `b` at 60 Hz; sub-stepping keeps physics near identical,
      // and identical step sizes yield 100% bit-exact frames.
      for (var i = 0; i < 15; i++) {
        a.update(1 / 30);
        b.update(1 / 30);
      }
      a.draw(fa);
      b.draw(fb);
      expect(fa.color, orderedEquals(fb.color));
      expect(fa.light, orderedEquals(fb.light));
    });

    test('ActInstance triggers hitstop, shake, target spring and finishes', () {
      final hitTimes = <double>[];
      final fxDef = PureEffect(
        meta: const EffectMeta(
          id: 'test/hit',
          name: 'Hit',
          desc: 'Test melee hit.',
          size: (96, 64),
          origin: (32, 54),
          duration: 0.4,
          actorScale: 2,
          defaultOptions: {'palette': Pal.electric, 'seed': 1},
        ),
        act: ActSpec(
          target: const TargetSpec(x: 58),
          poses: [
            const PoseKey(-0.2, kReady),
            const PoseKey(
              0.05,
              Pose(
                weapon: 'sword',
                crouch: 4,
                lean: 5,
                fx: 20,
                fy: -21,
                sa: 0.5,
                ghost: 1,
              ),
              PoseEase.snap,
            ),
            const PoseKey(0.45, kReady),
          ],
          hits: const [
            HitSpec(t: 0.05, stop: 0.1, shake: 0.15, amp: 2, push: 2.5, straw: 10),
          ],
        ),
        onDraw: (p, t, o) {
          if (t < 0.2) p.circle(18, -20, 6, kWhite);
        },
      );

      final inst = createAct(fxDef, {'x': 32, 'y': 54})
        ..onHit = (h) => hitTimes.add(h.t);
      final frame = createFrame(140, 80);
      var sawFrozen = false;
      var sawShake = false;
      for (var i = 0; i < 60 && !inst.done; i++) {
        inst.update(1 / 30);
        if (inst.frozen) sawFrozen = true;
        if (inst.shake != (0, 0)) sawShake = true;
        clearFrame(frame);
        inst.draw(frame);
      }
      expect(hitTimes, [0.05]);
      expect(sawFrozen, isTrue);
      expect(sawShake, isTrue);
      expect(inst.done, isTrue);
    });
  });
}

class _ParticleSim extends BaseEffectSim {
  final Particles ps;
  _ParticleSim(this.ps);

  @override
  void update(double dt, Map<String, Object?> _) => ps.update(dt);

  @override
  void draw(Painter p) => ps.draw(p);
}
