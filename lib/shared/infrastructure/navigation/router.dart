import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/ble_diagnostics_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_event.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/home/home_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/route/route_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/search_screen.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_screen.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/rumbo_shell.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    if (kDebugMode && defaultTargetPlatform == TargetPlatform.android)
      GoRoute(
        path: '/developer/ble',
        builder: (context, state) => BlocProvider<BleDiagnosticsBloc>(
          create: (_) =>
              serviceLocator<BleDiagnosticsBloc>()
                ..add(const BleDiagnosticsStarted()),
          child: const BleDiagnosticsScreen(),
        ),
      ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          RumboShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/home',
              builder: (context, state) => const HomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/search',
              builder: (context, state) => const SearchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/route',
              builder: (context, state) => const RouteScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/profile',
              builder: (context, state) => const ProfileScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);
