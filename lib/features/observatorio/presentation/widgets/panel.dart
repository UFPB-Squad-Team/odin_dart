import 'package:flutter/material.dart';

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(12),
    this.opacity = 1,
    this.radius = 16,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surface.withAlpha((opacity * 255).round()),
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: scheme.outline),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}
