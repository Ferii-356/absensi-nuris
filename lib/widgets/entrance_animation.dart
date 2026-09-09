import 'dart:async';
import 'package:flutter/material.dart';

class EntranceAnimation extends StatefulWidget {
  final Widget child;
  final int delayMilliseconds;
  final Offset slideOffset;
  final double beginScale;
  final Duration duration;
  final Curve curve;

  const EntranceAnimation({
    super.key,
    required this.child,
    this.delayMilliseconds = 0,
    this.slideOffset = const Offset(0, 24),
    this.beginScale = 0.97,
    this.duration = const Duration(milliseconds: 520),
    this.curve = Curves.easeOutCubic,
  });

  @override
  State<EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<EntranceAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<double> _entrance;
  Timer? _delayTimer;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.duration);
    _opacity = CurvedAnimation(parent: _controller, curve: Curves.easeOut);
    _entrance = CurvedAnimation(parent: _controller, curve: widget.curve);

    if (widget.delayMilliseconds <= 0) {
      _controller.forward();
    } else {
      _delayTimer = Timer(Duration(milliseconds: widget.delayMilliseconds), () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delayTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final scale =
            widget.beginScale + (1 - widget.beginScale) * _entrance.value;
        return Opacity(
          opacity: _opacity.value,
          child: Transform.translate(
            offset: widget.slideOffset * (1 - _entrance.value),
            child: Transform.scale(scale: scale, child: child),
          ),
        );
      },
      child: widget.child,
    );
  }
}