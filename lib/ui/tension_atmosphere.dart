import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme.dart';

/// A slow edge tint; never flashes or intercepts cards/buttons.
class TensionAtmosphere extends StatefulWidget {
  final int level;
  const TensionAtmosphere({super.key, required this.level});
  @override
  State<TensionAtmosphere> createState() => _TensionAtmosphereState();
}

class _TensionAtmosphereState extends State<TensionAtmosphere>
    with SingleTickerProviderStateMixin {
  late final AnimationController _breath = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 2400));
  int _lastLevel = 0;
  void _sync() {
    if (widget.level == 0 || MediaQuery.disableAnimationsOf(context)) {
      _breath.stop();
    } else if (_lastLevel != widget.level) {
      // One slow breath per transition, then a static tint. No perpetual loop.
      _breath.forward(from: 0);
    }
    _lastLevel = widget.level;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant TensionAtmosphere oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: ExcludeSemantics(
            child: AnimatedBuilder(
          animation: _breath,
          builder: (_, __) {
            final reduced = MediaQuery.disableAnimationsOf(context);
            final opacity = widget.level == 0
                ? 0.0
                : .08 +
                    .035 * widget.level +
                    (reduced ? 0 : .025 * math.sin(math.pi * _breath.value));
            return DecoratedBox(
                decoration: BoxDecoration(
                    gradient: RadialGradient(
              radius: .9,
              colors: [Colors.transparent, SS.rojo.withValues(alpha: opacity)],
              stops: const [.45, 1],
            )));
          },
        )),
      );
}
