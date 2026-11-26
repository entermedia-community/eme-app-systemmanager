import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'features/auth/auth_controller.dart';
import 'features/auth/login_page.dart';
import 'features/database/database_page.dart';
import 'features/groups/groups_page.dart';
import 'features/parameters/parameters_page.dart';
import 'features/permissions/permissions_page.dart';
import 'features/server/server_page.dart';
import 'features/shell/app_shell.dart';
import 'features/users/users_page.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = ValueNotifier(0);
  ref.listen(authProvider, (_, _) => refresh.value++);
  ref.onDispose(refresh.dispose);

  return GoRouter(
    initialLocation: '/server',
    refreshListenable: refresh,
    redirect: (context, state) {
      final auth = ref.read(authProvider);
      final loc = state.matchedLocation;
      const gates = {'/splash', '/login', '/'};
      // The page the user asked for, kept through the splash and login screens.
      final from = gates.contains(loc)
          ? state.uri.queryParameters['from']
          : state.uri.toString();
      String gate(String path) => from == null || !from.startsWith('/')
          ? path
          : '$path?from=${Uri.encodeQueryComponent(from)}';
      if (auth.isRestoring) return loc == '/splash' ? null : gate('/splash');
      if (!auth.isAuthenticated) return loc == '/login' ? null : gate('/login');
      if (gates.contains(loc)) {
        return from != null &&
                from.startsWith('/') &&
                !gates.contains(Uri.parse(from).path)
            ? from
            : '/server';
      }
      return null;
    },
    routes: [
      GoRoute(path: '/splash', builder: (_, _) => const _Splash()),
      GoRoute(path: '/login', builder: (_, _) => const LoginPage()),
      ShellRoute(
        builder: (_, state, child) =>
            AppShell(location: state.matchedLocation, child: child),
        routes: [
          GoRoute(
            path: '/server',
            pageBuilder: (_, _) => const NoTransitionPage(child: ServerPage()),
          ),
          GoRoute(
            path: '/database',
            pageBuilder: (_, s) => NoTransitionPage(
              child: DatabasePage(table: s.uri.queryParameters['table']),
            ),
          ),
          GoRoute(
            path: '/parameters',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: ParametersPage()),
          ),
          GoRoute(
            path: '/users',
            pageBuilder: (_, _) => const NoTransitionPage(child: UsersPage()),
          ),
          GoRoute(
            path: '/groups',
            pageBuilder: (_, _) => const NoTransitionPage(child: GroupsPage()),
          ),
          GoRoute(
            path: '/permissions',
            pageBuilder: (_, _) =>
                const NoTransitionPage(child: PermissionsPage()),
          ),
        ],
      ),
    ],
  );
});

class _Splash extends StatelessWidget {
  const _Splash();
  @override
  Widget build(BuildContext context) => const Scaffold(
    body: Center(
      child: SizedBox.square(
        dimension: 28,
        child: CircularProgressIndicator(strokeWidth: 2.5),
      ),
    ),
  );
}
