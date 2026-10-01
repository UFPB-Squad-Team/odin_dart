import 'package:flutter/material.dart';

abstract final class OdinColors {
  static const zinc50 = Color(0xFFFAFAFA);
  static const zinc100 = Color(0xFFF4F4F5);
  static const zinc200 = Color(0xFFE4E4E7);
  static const zinc300 = Color(0xFFD4D4D8);
  static const zinc400 = Color(0xFFA1A1AA);
  static const zinc500 = Color(0xFF71717A);
  static const zinc600 = Color(0xFF52525B);
  static const zinc700 = Color(0xFF3F3F46);
  static const zinc800 = Color(0xFF27272A);
  static const zinc900 = Color(0xFF18181B);
  static const zinc950 = Color(0xFF09090B);

  static const cyan50 = Color(0xFFECFEFF);
  static const cyan300 = Color(0xFF67E8F9);
  static const cyan400 = Color(0xFF22D3EE);
  static const cyan500 = Color(0xFF06B6D4);
  static const cyan600 = Color(0xFF0891B2);
  static const cyan700 = Color(0xFF0E7490);
  static const cyan950 = Color(0xFF083344);

  static const brandViolet = Color(0xFF694FF0);
  static const brandBlue = Color(0xFF2A98B9);
  static const brandGreen = Color(0xFF16AC87);

  static const educacao = Color(0xFF06B6D4);
  static const socioeconomico = Color(0xFFA78BFA);
  static const selection = Color(0xFFFBBF24);

  static const white = Color(0xFFFFFFFF);

  static const brandGradient = LinearGradient(
    begin: Alignment.centerLeft,
    end: Alignment.centerRight,
    colors: [brandViolet, brandBlue, brandGreen],
  );
}
