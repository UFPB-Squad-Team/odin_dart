import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/odin_colors.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(const Duration(milliseconds: 1600), () {
      if (mounted) context.go(AppRoutes.observatorio);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: OdinColors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset('assets/images/odin_logo.png', width: 220, height: 220),
              const SizedBox(height: 20),
              const Text(
                'ODIN',
                style: TextStyle(
                  fontSize: 30,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: OdinColors.zinc900,
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Observatório de Dados Integrados do Nordeste',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 14, color: OdinColors.zinc600),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: 120,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    minHeight: 3,
                    color: OdinColors.cyan600,
                    backgroundColor: OdinColors.zinc200,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
