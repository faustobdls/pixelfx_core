// Post-processing filters applied to PixelFrame buffers between draw() and composite().

import '../core/frame.dart';

abstract class PostProcessor {
  String get id;
  void apply(PixelFrame frame, double t, Map<String, Object?> options);
}

class PostFxPipeline {
  final List<PostProcessor> processors;

  const PostFxPipeline(this.processors);

  void applyAll(
    PixelFrame frame,
    double t, [
    Map<String, Object?> options = const {},
  ]) {
    for (final p in processors) {
      p.apply(frame, t, options);
    }
  }
}

/// Built-in post-processor that smoothly fades light buffers near canvas edges.
class EdgeFadePostFx extends PostProcessor {
  final int margin;

  EdgeFadePostFx({this.margin = 8});

  @override
  String get id => 'edge-fade';

  @override
  void apply(PixelFrame frame, double t, Map<String, Object?> options) {
    edgeFade(frame, margin);
  }
}
