import 'package:go_router/go_router.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/home/home_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/route/route_screen.dart';
import 'package:rumbo_mobile_application/navigation/presentation/views/search/search_screen.dart';
import 'package:rumbo_mobile_application/profiles/presentation/views/profile/profile_screen.dart';
import 'package:rumbo_mobile_application/shared/presentation/widgets/rumbo_shell.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/home',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, navigationShell) =>
          RumboShell(navigationShell: navigationShell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/home', builder: (context, state) => const HomeScreen()),
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
            GoRoute(path: '/route', builder: (context, state) => const RouteScreen()),
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
