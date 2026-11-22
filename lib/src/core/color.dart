// Colors are 32-bit integers laid out as (R, G, B, A) bytes in little-endian memory:
// 0xAABBGGRR, compatible directly with RGBA8888 buffers (Flutter ui.Image & PNG).

import 'dart:math' as math;

import 'math.dart';

/// Pack 0..255 R, G, B channels into an opaque 0xFFBBGGRR integer.
@pragma('vm:prefer-inline')
int rgb(num r, num g, num b) {
  final ri = r.toInt() & 255;
  final gi = g.toInt() & 255;
  final bi = b.toInt() & 255;
  return ((255 << 24) | (bi << 16) | (gi << 8) | ri) & 0xffffffff;
}

/// Pack 0..255 R, G, B, A channels into 0xAABBGGRR.
@pragma('vm:prefer-inline')
int rgba(int r, int g, int b, int a) =>
    (((a & 255) << 24) | ((b & 255) << 16) | ((g & 255) << 8) | (r & 255)) &
    0xffffffff;

@pragma('vm:prefer-inline')
int red(int c) => c & 255;

@pragma('vm:prefer-inline')
int green(int c) => (c >>> 8) & 255;

@pragma('vm:prefer-inline')
int blue(int c) => (c >>> 16) & 255;

@pragma('vm:prefer-inline')
int alpha(int c) => (c >>> 24) & 255;

/// "#rgb" or "#rrggbb" (or an `int` color number, passed through) to a packed 32-bit color.
int hex(Object value) {
  if (value is int) return value & 0xffffffff;
  if (value is! String) {
    throw ArgumentError('Expected int or hex String, got ${value.runtimeType}');
  }
  var s = value.startsWith('#') ? value.substring(1) : value;
  if (s.length == 3) {
    s = '${s[0]}${s[0]}${s[1]}${s[1]}${s[2]}${s[2]}';
  }
  final v = int.parse(s.substring(0, 6), radix: 16);
  return rgb((v >> 16) & 255, (v >> 8) & 255, v & 255);
}

String toHex(int c) =>
    '#${red(c).toRadixString(16).padLeft(2, '0')}'
    '${green(c).toRadixString(16).padLeft(2, '0')}'
    '${blue(c).toRadixString(16).padLeft(2, '0')}';

/// Linear mix of two packed colors.
int mix(int a, int b, double t) {
  final u = clamp(t);
  return rgb(
    red(a) + (red(b) - red(a)) * u,
    green(a) + (green(b) - green(a)) * u,
    blue(a) + (blue(b) - blue(a)) * u,
  );
}

/// Multiply a color's brightness by [k].
int scaleColor(int c, double k) => rgb(
      math.min(255.0, red(c) * k),
      math.min(255.0, green(c) * k),
      math.min(255.0, blue(c) * k),
    );

/// Perceived brightness 0..1.
double luma(int c) =>
    (0.299 * red(c) + 0.587 * green(c) + 0.114 * blue(c)) / 255.0;

/// Convert a list of hex strings or color numbers (dark to bright) to packed color numbers.
List<int> ramp(List<Object> list) =>
    list.map(hex).toList(growable: false);

/// Resample a ramp to exactly [n] steps, keeping its ends (darkest and brightest stay put).
List<int> fit(List<Object> r, int n) {
  final parsed = r.map(hex).toList(growable: false);
  if (parsed.length == n) return parsed;
  final denom = math.max(1, n - 1);
  return List<int>.generate(
    n,
    (i) => parsed[((i * (parsed.length - 1)) / denom).round()],
    growable: false,
  );
}

/// The ramp step for [t] in 0..1, no blending: pixel art picks a color rather than fading between two.
@pragma('vm:prefer-inline')
int at(List<int> r, double t) =>
    r[clampInt((t * r.length).floor(), 0, r.length - 1)];

/// Blended color along a ramp (for light, where smooth is right).
int blendRamp(List<int> r, double t) {
  final x = clamp(t) * (r.length - 1);
  final i = math.min(r.length - 2, x.floor());
  return mix(r[i], r[i + 1], x - i);
}

/// Checks if a dynamic option value is a color ramp (`List` of `int` or `#rgb`/`#rrggbb` strings).
bool isColorRamp(Object? v) {
  if (v is! List || v.isEmpty) return false;
  for (final item in v) {
    if (item is int) continue;
    if (item is String && _hexPattern.hasMatch(item)) continue;
    return false;
  }
  return true;
}

final RegExp _hexPattern = RegExp(r'^#[0-9a-f]{3,8}$', caseSensitive: false);

/// Hue-shifted ramps, dark to bright: shadows lean cool or deep, highlights lean warm or white.
abstract final class Pal {
  static const List<String> fire = [
    '#1f0b10', '#4a1118', '#8c1d1c', '#cc3a1a',
    '#f2701f', '#ffae35', '#ffe27a', '#fff8d6',
  ];
  static const List<String> ember = [
    '#1a0a0e', '#3d1012', '#701a14', '#a8301a',
    '#e0561e', '#ff8a2a', '#ffc46a',
  ];
  static const List<String> lava = [
    '#14060a', '#380a10', '#6e1210', '#ac2410',
    '#e8501a', '#ff8c2a', '#ffd25a',
  ];
  static const List<String> smoke = [
    '#0e0c12', '#1d1a22', '#2e2a35', '#433e4b',
    '#5c5664', '#7b7484', '#a39cab',
  ];
  static const List<String> dust = [
    '#1c1610', '#33281c', '#4f3f2c', '#6e5a40',
    '#927a58', '#b89f78', '#dcc8a2',
  ];
  static const List<String> ice = [
    '#0c1430', '#162c5c', '#1f4f94', '#2f7fcc',
    '#58b4ec', '#9bdcff', '#d8f4ff', '#ffffff',
  ];
  static const List<String> water = [
    '#081830', '#0e2e5a', '#14508c', '#1c76bc',
    '#36a2e0', '#78ccf4', '#c4ecff', '#ffffff',
  ];
  static const List<String> electric = [
    '#0a0f2e', '#172a78', '#2550d0', '#3f8cff',
    '#7cc8ff', '#c8f0ff', '#ffffff',
  ];
  static const List<String> volt = [
    '#24160a', '#5e3a0c', '#a8680f', '#e8a218',
    '#ffd23c', '#fff08a', '#ffffff',
  ];
  static const List<String> poison = [
    '#0d1a0c', '#173a14', '#265e18', '#3f8a1e',
    '#6cb82a', '#a8e04a', '#e0ff8a',
  ];
  static const List<String> holy = [
    '#2a1c08', '#5a3e10', '#9a6c18', '#d8a428',
    '#ffd84a', '#fff09a', '#fffbe6', '#ffffff',
  ];
  static const List<String> heal = [
    '#08201a', '#0f3f2c', '#17663e', '#24924e',
    '#3ec466', '#7ee88a', '#c8ffc4', '#ffffff',
  ];
  static const List<String> arcane = [
    '#140a26', '#2b1252', '#481c88', '#6b2cc0',
    '#9a48ec', '#c684ff', '#ecc8ff', '#ffffff',
  ];
  static const List<String> shadow = [
    '#050308', '#0f0a18', '#1c1230', '#2c1a4a',
    '#432468', '#5e3290', '#8048b8', '#a970e0',
  ];
  static const List<String> blood = [
    '#14040a', '#3a0a14', '#6a101c', '#a01824',
    '#d42a30', '#ff5a50', '#ff9a8a',
  ];
  static const List<String> earth = [
    '#140e0a', '#2a1e14', '#47321e', '#69492a',
    '#8e6638', '#b88a52', '#dcb47c',
  ];
  static const List<String> stone = [
    '#0e0e12', '#1c1c24', '#2c2c38', '#42424f',
    '#5c5c6b', '#7d7d8c', '#a4a4b2', '#d0d0da',
  ];
  static const List<String> gold = [
    '#1e1206', '#4a2c08', '#86520c', '#c48412',
    '#f0b424', '#ffe066', '#fff6c4', '#ffffff',
  ];
  static const List<String> leaf = [
    '#0c1a0e', '#163418', '#225224', '#357530',
    '#4f9a3a', '#7cc048', '#b4e070', '#e4ffb0',
  ];
  static const List<String> wood = [
    '#160c06', '#2e1a0c', '#4a2c14', '#6a421e',
    '#8e5c2c', '#b47c40', '#d8a464',
  ];
  static const List<String> metal = [
    '#0c0e14', '#1c2230', '#2e3648', '#4a5468',
    '#6e7a90', '#9aa6ba', '#d0d8e6', '#ffffff',
  ];
  static const List<String> bone = [
    '#1a1814', '#3a352c', '#5e5648', '#8a806c',
    '#b8ad96', '#e4dcc8', '#fffaf0',
  ];
  static const List<String> neon = [
    '#1a0516', '#3d0a33', '#701560', '#b0228f',
    '#f53cd1', '#ff86e6', '#ffd2f6', '#ffffff',
  ];
  static const List<String> cyber = [
    '#041418', '#08303a', '#0c5260', '#108088',
    '#18b4b0', '#4ce8d8', '#b4fff0', '#ffffff',
  ];
  static const List<String> matrix = [
    '#020a04', '#05200c', '#0a3c16', '#106624',
    '#1a9a34', '#3cd650', '#a4ffa8', '#e8ffe8',
  ];
  static const List<String> candy = [
    '#ff4a5a', '#ff9a2a', '#ffe03c', '#5ad84a',
    '#3cc8ff', '#7a6cff', '#f53cd1',
  ];
  static const List<String> night = [
    '#07060d', '#0c0a18', '#131026', '#1b1734',
    '#241f44', '#2f2956',
  ];

  static const Map<String, List<String>> all = {
    'fire': fire,
    'ember': ember,
    'lava': lava,
    'smoke': smoke,
    'dust': dust,
    'ice': ice,
    'water': water,
    'electric': electric,
    'volt': volt,
    'poison': poison,
    'holy': holy,
    'heal': heal,
    'arcane': arcane,
    'shadow': shadow,
    'blood': blood,
    'earth': earth,
    'stone': stone,
    'gold': gold,
    'leaf': leaf,
    'wood': wood,
    'metal': metal,
    'bone': bone,
    'neon': neon,
    'cyber': cyber,
    'matrix': matrix,
    'candy': candy,
    'night': night,
  };
}

/// The same ramps pre-converted to packed 32-bit color numbers.
final Map<String, List<int>> palRamps = {
  for (final entry in Pal.all.entries) entry.key: ramp(entry.value),
};

final int kWhite = hex('#ffffff');
final int kBlack = hex('#000000');
final int kInk = hex('#0b0a10');
final int kPatch = hex('#f53cd1');
