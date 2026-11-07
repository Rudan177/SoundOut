import 'dart:math' as math;

import 'package:flutter/material.dart';

class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    required this.color,
    this.size = 18,
    this.active = true,
  });

  final Color color;
  final double size;
  final bool active;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1000),
  );

  @override
  void initState() {
    super.initState();
    if (widget.active) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(3, (index) {
              final phase = _controller.value * math.pi * 2 + index * 1.5;
              final factor = widget.active
                  ? 0.32 + 0.68 * ((math.sin(phase) + 1) / 2)
                  : 0.4 + index * 0.12;
              return Container(
                width: widget.size * 0.2,
                height: widget.size * factor.clamp(0.3, 1.0),
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(widget.size),
                ),
              );
            }),
          );
        },
      ),
    );
  }
}
