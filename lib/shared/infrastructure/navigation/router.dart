import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/injections.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/ble_diagnostics_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_bloc.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/ble_diagnostics/bloc/ble_diagnostics_event.dart';
import 'package:rumbo_mobile_application/navigation/domain/entities/destination.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/destination/destination_detail_screen.dart';
import '../../../iam/application/session_facade.dart';
import '../../../iam/presentation/auth_screens.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/home/home_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/route/route_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/search_screen.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_screen.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/rumbo_shell.dart';

GoRouter buildRouter(SessionFacade session) => GoRouter(
  initialLocation: '/session',
  refreshListenable: session,
  redirect: (context, route) {
    final state = session.state;
    final path = route.uri.path;
    if (state is SessionLoading || state is RetryableError) {
      return path == '/session' ? null : '/session';
    }
    if (state is SessionExpired) {
      return path == '/sign-in' ? null : '/sign-in';
    }
    if (state is Unauthenticated) {
      return ['/welcome', '/sign-in', '/sign-up'].contains(path)
          ? null
          : '/welcome';
    }
    if (state is Authenticated) {
      if (!state.profileConfigured) {
        return path == '/profile' ? null : '/profile';
      }
      if (['/session', '/welcome', '/sign-in', '/sign-up'].contains(path)) {
        return '/home';
      }
    }
    return null;
  },
  routes: [
    if (kDebugMode &&
        !kIsWeb &&
        defaultTargetPlatform == TargetPlatform.android)
      GoRoute(
        path: '/developer/ble',
        builder: (context, state) => BlocProvider<BleDiagnosticsBloc>(
          create: (_) =>
              serviceLocator<BleDiagnosticsBloc>()
                ..add(const BleDiagnosticsStarted()),
          child: const BleDiagnosticsScreen(),
        ),
      ),
    GoRoute(
      path: '/session',
      builder: (_, _) => SessionGateScreen(session: session),
    ),
    GoRoute(path: '/welcome', builder: (_, _) => const WelcomeScreen()),
    GoRoute(
      path: '/sign-in',
      builder: (_, _) =>
          AuthScreen(key: const ValueKey('sign-in'), session: session),
    ),
    GoRoute(
      path: '/sign-up',
      builder: (_, _) => AuthScreen(
        key: const ValueKey('sign-up'),
        session: session,
        signUp: true,
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
              routes: [
                GoRoute(
                  path: 'destination/:id',
                  builder: (context, state) => DestinationDetailScreen(
                    destination: state.extra is Destination
                        ? state.extra as Destination
                        : null,
                  ),
                ),
              ],
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
