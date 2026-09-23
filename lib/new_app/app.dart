import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'screens.dart';
import 'state.dart';

class MushroomApp extends ConsumerWidget {
  const MushroomApp({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final router = ref.watch(routerProvider);
    return MaterialApp.router(
      title: 'Quản lý Sản xuất & Nhận diện Nấm',
      debugShowCheckedModeBanner: false,
      themeMode: settings.themeMode,
      locale: settings.locale,
      supportedLocales: const [Locale('vi'), Locale('en')],
      localizationsDelegates: const [GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
      theme: _theme(Brightness.light), darkTheme: _theme(Brightness.dark), routerConfig: router,
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xff28754a), brightness: brightness);
    return ThemeData(colorScheme: scheme, brightness: brightness, useMaterial3: true,
      scaffoldBackgroundColor: scheme.surface,
      inputDecorationTheme: InputDecorationTheme(border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
      cardTheme: CardThemeData(elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        color: scheme.surfaceContainerLow),
      navigationRailTheme: NavigationRailThemeData(indicatorColor: scheme.secondaryContainer));
  }
}

final routerProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);
  final session = auth.asData?.value;
  final loggedIn = session != null;
  return GoRouter(initialLocation: '/login', routes: [
    GoRoute(path: '/login', builder: (_, state) => LoginScreen(returnTo: state.uri.queryParameters['returnTo'])),
    GoRoute(path: '/lookup', builder: (_, __) => const PublicGrowthScreen()),
    GoRoute(path: '/classify', builder: (_, __) => const ClassifierScreen()),
    GoRoute(path: '/forbidden', builder: (_, __) => const ForbiddenScreen()),
    ShellRoute(builder: (_, __, child) => AppShell(child: child), routes: [
      GoRoute(path: '/', builder: (_, __) => const DashboardScreen()),
      GoRoute(path: '/species', builder: (_, __) => const ResourceScreen(title: 'Giống nấm', endpoint: '/mushroom-species', kind: ResourceKind.species)),
      GoRoute(path: '/facilities', builder: (_, __) => const ResourceScreen(title: 'Cơ sở sản xuất', endpoint: '/production-facilities', kind: ResourceKind.facility)),
      GoRoute(path: '/batches', builder: (_, __) => const ResourceScreen(title: 'Lô nuôi trồng', endpoint: '/cultivation-batches', kind: ResourceKind.batch)),
      GoRoute(path: '/users', builder: (_, __) => const ResourceScreen(title: 'Người dùng', endpoint: '/admin/users', kind: ResourceKind.user)),
      GoRoute(path: '/reports', builder: (_, __) => const ReportsScreen()),
      GoRoute(path: '/audit', builder: (_, __) => const AuditScreen()),
      GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    ]),
  ], redirect: (context, state) {
    final location = state.matchedLocation;
    const publicPaths = {'/login', '/lookup', '/classify', '/forbidden'};
    if (auth.isLoading) return null;
    if (!loggedIn && !publicPaths.contains(location)) return '/login?returnTo=${Uri.encodeComponent(state.uri.toString())}';
    if (loggedIn && location == '/login') return state.uri.queryParameters['returnTo'] ?? '/';
    if (location == '/users' && !isAdmin(session!.role)) return '/forbidden';
    if ((location == '/reports' || location == '/audit') && !canManage(session!.role)) return '/forbidden';
    return null;
  });
});
