import 'package:flutter/material.dart';

import '../../../../core/theme/odin_colors.dart';

class OdinLogoBadge extends StatelessWidget {
  const OdinLogoBadge({super.key, this.size = 44});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: OdinColors.white,
        shape: BoxShape.circle,
        border: Border.all(color: OdinColors.zinc300),
        boxShadow: const [
          BoxShadow(color: Color(0x1F000000), blurRadius: 8, offset: Offset(0, 2)),
        ],
      ),
      child: ClipOval(
        child: Padding(
          padding: EdgeInsets.all(size * 0.04),
          child: Image.asset('assets/images/odin_logo.png', fit: BoxFit.contain),
        ),
      ),
    );
  }
}
