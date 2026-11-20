import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/auth_provider.dart';
import '../../features/auth/auth_screen.dart';
import '../../features/auth/onboarding_resume_screen.dart';
import '../../features/feed/feed_screen.dart';
import '../../features/feed/models/job_match.dart';
import '../../features/resume/resume_screen.dart';
import '../../features/tracker/tracker_screen.dart';
import '../../features/alerts/alerts_screen.dart';
import '../../features/tailor/tailor_screen.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _feedNavigatorKey = GlobalKey<NavigatorState>();
final _resumeNavigatorKey = GlobalKey<NavigatorState>();
final _trackerNavigatorKey = GlobalKey<NavigatorState>();
final _alertsNavigatorKey = GlobalKey<NavigatorState>();

/// GoRouter configuration with Auth, Onboarding, and 4-tab bottom navigation
final appRouterProvider = Provider<GoRouter>((ref) {
  final authState = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/auth',
    redirect: (context, state) {
      final isAuth = authState.isAuthenticated;
      final isGoingToAuth = state.matchedLocation == '/auth';

      if (!isAuth && !isGoingToAuth) {
        return '/auth';
      }

      if (isAuth && isGoingToAuth) {
        return '/feed';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/onboarding/resume',
        builder: (context, state) => const OnboardingResumeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return ScaffoldWithNestedNavigation(navigationShell: navigationShell);
        },
        branches: [
          // Tab 1: Feed
          StatefulShellBranch(
            navigatorKey: _feedNavigatorKey,
            routes: [
              GoRoute(
                path: '/feed',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: FeedScreen(),
                ),
                routes: [
                  GoRoute(
                    path: 'tailor',
                    parentNavigatorKey: _rootNavigatorKey,
                    builder: (context, state) {
                      final job = state.extra as JobMatchItem?;
                      if (job == null) {
                        return Scaffold(
                          appBar: AppBar(title: const Text('Error')),
                          body: const Center(child: Text('No job details provided.')),
                        );
                      }
                      return TailorScreen(job: job);
                    },
                  ),
                ],
              ),
            ],
          ),
          // Tab 2: Resume
          StatefulShellBranch(
            navigatorKey: _resumeNavigatorKey,
            routes: [
              GoRoute(
                path: '/resume',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: ResumeScreen(),
                ),
              ),
            ],
          ),
          // Tab 3: Tracker
          StatefulShellBranch(
            navigatorKey: _trackerNavigatorKey,
            routes: [
              GoRoute(
                path: '/tracker',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: TrackerScreen(),
                ),
              ),
            ],
          ),
          // Tab 4: Alerts
          StatefulShellBranch(
            navigatorKey: _alertsNavigatorKey,
            routes: [
              GoRoute(
                path: '/alerts',
                pageBuilder: (context, state) => const NoTransitionPage(
                  child: AlertsScreen(),
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

/// Bottom navigation scaffold with Material 3 NavigationBar
class ScaffoldWithNestedNavigation extends StatelessWidget {
  const ScaffoldWithNestedNavigation({
    super.key,
    required this.navigationShell,
  });

  final StatefulNavigationShell navigationShell;

  void _goBranch(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        destinations: const [
          NavigationDestination(
            label: 'Feed',
            icon: Icon(Icons.work_outline),
            selectedIcon: Icon(Icons.work),
          ),
          NavigationDestination(
            label: 'Resume',
            icon: Icon(Icons.description_outlined),
            selectedIcon: Icon(Icons.description),
          ),
          NavigationDestination(
            label: 'Tracker',
            icon: Icon(Icons.view_kanban_outlined),
            selectedIcon: Icon(Icons.view_kanban),
          ),
          NavigationDestination(
            label: 'Alerts',
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications),
          ),
        ],
        onDestinationSelected: _goBranch,
      ),
    );
  }
}
