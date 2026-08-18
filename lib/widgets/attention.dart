/// Ways of drawing an eye to one control without shouting.
///
/// Both of these run forever on a screen the user sits on, so they are built
/// to be cheap and interruptible: a single controller each, nothing rebuilt
/// but the painted layer, and a long quiet gap between beats — a thing that
/// moves constantly stops being noticed within about ten seconds, and starts
/// being irritating shortly after.
///
/// Both also stop entirely when the platform asks for reduced motion, and
/// while the screen is not the visible route (Flutter mutes tickers under an
/// inactive [TickerMode] on its own).
library;

import 'package:flutter/material.dart';

/// A band of light that crosses the child every [period], the way a highlight
/// travels across foil when a card is tilted.
class ShimmerSweep extends StatefulWidget {
  const ShimmerSweep({
    super.key,
    required this.child,
    this.period = const Duration(milliseconds: 3600),
    this.highlight = Colors.white,
    this.strength = .55,
    this.enabled = true,
  });

  final Widget child;

  /// Time from one sweep to the next. The sweep itself takes about a quarter
  /// of it; the rest is deliberately still.
  final Duration period;

  final Color highlight;

  /// How bright the band is at its centre, 0–1.
  final double strength;

  final bool enabled;

  @override
  State<ShimmerSweep> createState() => _ShimmerSweepState();
}

class _ShimmerSweepState extends State<ShimmerSweep>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _running = false;

  // Built here, not with a `late` initialiser: a lazy controller that no build
  // ever touched would be constructed for the first time inside dispose(),
  // where creating a ticker looks up an ancestor on a deactivated element and
  // throws. Any disabled instance hit that — including the wallet pill in its
  // ordinary, unclaimable state.
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.period);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(ShimmerSweep old) {
    super.didUpdateWidget(old);
    if (old.period != widget.period) _c.duration = widget.period;
    _sync();
  }

  /// Idle instances hold no ticker at all rather than spinning invisibly.
  void _sync() {
    final should = widget.enabled && !_reduced;
    if (should == _running) return;
    _running = should;
    should ? _c.repeat() : _c.stop();
  }

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduced) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      // The child is built once and reused: only the shader moves.
      child: widget.child,
      builder: (context, child) {
        // The band spends the first quarter of the cycle crossing, then waits.
        final t = (_c.value * 4).clamp(0.0, 1.0);
        final x = -1.4 + t * 2.8;
        return ShaderMask(
          blendMode: BlendMode.srcATop,
          shaderCallback: (rect) => LinearGradient(
            begin: Alignment(x - .55, -1),
            end: Alignment(x + .55, 1),
            colors: [
              widget.highlight.withValues(alpha: 0),
              widget.highlight.withValues(alpha: widget.strength),
              widget.highlight.withValues(alpha: 0),
            ],
            stops: const [0, .5, 1],
          ).createShader(rect),
          child: child,
        );
      },
    );
  }
}

/// A single soft beat — grow, settle — separated by a long pause.
///
/// Motion in the corner of the eye is what gets noticed; motion that never
/// stops is what gets tuned out. [rest] is therefore several times [beat].
class NudgePulse extends StatefulWidget {
  const NudgePulse({
    super.key,
    required this.child,
    this.beat = const Duration(milliseconds: 620),
    this.rest = const Duration(milliseconds: 3000),
    this.scale = .045,
    this.enabled = true,
  });

  final Widget child;
  final Duration beat;
  final Duration rest;

  /// Peak growth, as a fraction. .045 reads as «alive», .15 reads as broken.
  final double scale;

  final bool enabled;

  @override
  State<NudgePulse> createState() => _NudgePulseState();
}

class _NudgePulseState extends State<NudgePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _running = false;

  late final double _share =
      widget.beat.inMilliseconds / (widget.beat + widget.rest).inMilliseconds;

  // See the note in [_ShimmerSweepState.initState] — same trap, same fix.
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.beat + widget.rest);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(NudgePulse old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final should = widget.enabled && !_reduced;
    if (should == _running) return;
    _running = should;
    should ? _c.repeat() : _c.stop();
  }

  bool get _reduced => MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled || _reduced) return widget.child;

    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final v = _c.value;
        // One up-and-down inside the beat, flat for the whole rest.
        final beat = v >= _share ? 0.0 : Curves.easeInOut.transform(
            v < _share / 2 ? v / (_share / 2) : 1 - (v - _share / 2) / (_share / 2));
        return Transform.scale(scale: 1 + widget.scale * beat, child: child);
      },
    );
  }
}
