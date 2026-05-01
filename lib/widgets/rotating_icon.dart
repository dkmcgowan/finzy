import 'package:flutter/material.dart';

import 'app_icon.dart';

/// An icon that continuously rotates while [spin] is true.
///
/// Used for reconnect / sync indicators where the icon itself communicates
/// activity, so we don't need to swap the icon out for a CircularProgressIndicator
/// (which causes layout shifts when the icon and indicator have different sizes).
class RotatingIcon extends StatefulWidget {
  final IconData icon;
  final bool spin;
  final double size;
  final Color? color;
  final Duration period;

  const RotatingIcon({
    super.key,
    required this.icon,
    required this.spin,
    this.size = 22,
    this.color,
    this.period = const Duration(milliseconds: 900),
  });

  @override
  State<RotatingIcon> createState() => _RotatingIconState();
}

class _RotatingIconState extends State<RotatingIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: widget.period);
    if (widget.spin) _controller.repeat();
  }

  @override
  void didUpdateWidget(RotatingIcon oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.spin && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.spin && _controller.isAnimating) {
      _controller.stop();
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return RotationTransition(
      turns: _controller,
      child: AppIcon(widget.icon, fill: 1, size: widget.size, color: widget.color),
    );
  }
}
