import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/about/about_page.dart';
import '../../features/observatorio/presentation/observatorio_page.dart';
import '../../features/observatorio/presentation/schools/school_detail_page.dart';
import '../../features/observatorio/presentation/schools/schools_page.dart';
import '../../features/splash/splash_page.dart';

abstract final class AppRoutes {
  static const splash = '/';
  static const observatorio = '/observatorio';
  static const sobre = '/sobre';
  static const escolasPath = '/municipio/:id/escolas';
  static const escolaPath = '/escola/:inep';

  static String escolas(String municipioId, String nome) =>
      '/municipio/$municipioId/escolas?nome=${Uri.encodeQueryComponent(nome)}';

  static String escola(String inep) => '/escola/$inep';
}

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.splash,
    routes: [
      GoRoute(
        path: AppRoutes.splash,
        builder: (context, state) => const SplashPage(),
      ),
      GoRoute(
        path: AppRoutes.observatorio,
        builder: (context, state) => const ObservatorioPage(),
      ),
      GoRoute(
        path: AppRoutes.sobre,
        builder: (context, state) => const AboutPage(),
      ),
      GoRoute(
        path: AppRoutes.escolasPath,
        builder: (context, state) => SchoolsPage(
          municipioId: state.pathParameters['id']!,
          municipioNome: state.uri.queryParameters['nome'] ?? 'Município',
        ),
      ),
      GoRoute(
        path: AppRoutes.escolaPath,
        builder: (context, state) => SchoolDetailPage(
          inep: state.pathParameters['inep']!,
        ),
      ),
    ],
  );
});
