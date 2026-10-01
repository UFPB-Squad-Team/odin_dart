import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/theme/odin_theme.dart';

class OdinApp extends ConsumerWidget {
  const OdinApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'ODIN',
      debugShowCheckedModeBanner: false,
      theme: OdinTheme.light(),
      darkTheme: OdinTheme.dark(),
      themeMode: ThemeMode.system,
      routerConfig: router,
    );
  }
}
