import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/login_screen.dart';
import '../../features/auth/register_screen.dart';
import '../../features/create/moodify_create_screen.dart';
import '../../features/friends/add_friend_screen.dart';
import '../../features/friends/friends_list_screen.dart';
import '../../features/profile/profile_screen.dart';
import '../../features/settings/account_details_screen.dart';
import '../../features/settings/blocked_accounts_screen.dart';
import '../../features/settings/help_support_screen.dart';
import '../../features/settings/notifications_screen.dart';
import '../../features/settings/privacy_screen.dart';
import '../providers/mood_accent_provider.dart';
import '../widgets/mood_background.dart';

/// Bridges FirebaseAuth's stream into a [Listenable] go_router can use for
/// [GoRouter.refreshListenable] — without this, `redirect` only re-runs on
/// navigation, so a sign-in/sign-out that happens without a route change
/// (e.g. Firebase restoring a persisted session on cold start, after
/// `initialLocation` has already been evaluated) would never re-trigger it.
class _AuthChangeNotifier extends ChangeNotifier {
  _AuthChangeNotifier() {
    _sub = FirebaseAuth.instance.authStateChanges().listen((_) => notifyListeners());
  }
  late final StreamSubscription<User?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}

/// Route names mirror the source .html filenames (lowercased) so the
/// migration mapping stays obvious: login.html -> /login, etc.
///
/// All 10 source screens are now migrated — see MIGRATION_NOTES.md.
///
/// Every route except Login/Register lives inside a [ShellRoute] wrapping
/// a single [MoodBackground] fed by [moodAccentProvider]. That's what
/// makes the mood background persist across navigation instead of resetting:
/// with each screen creating its own `MoodBackground`, moving from Profile
/// to Friends destroyed and recreated the widget (and its color) from
/// scratch. Mounting it once here means the same [CustomPainter] instance
/// stays alive across pushes/pops, so (a) it doesn't need to be re-declared
/// per screen, and (b) an in-flight color animation (mood just changed)
/// keeps playing smoothly even if the user navigates mid-transition.
///
/// Login/Register stay outside the shell — no user/mood is loaded yet at
/// that point, so they keep their own static default-accent background.
/// Lets code outside the widget tree (notification taps — see
/// NotificationsService._navigate) drive navigation without a
/// BuildContext of its own.
final rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  // Was missing entirely — with no `redirect`, a returning user with an
  // already-valid Firebase session always landed back on `/login` and had
  // to log in again every time the app was reopened. `refreshListenable`
  // makes this re-run once Firebase finishes restoring that session on
  // cold start, not just on the next manual navigation.
  refreshListenable: _AuthChangeNotifier(),
  redirect: (context, state) {
    final signedIn = FirebaseAuth.instance.currentUser != null;
    final onAuthScreen = state.matchedLocation == '/login' || state.matchedLocation == '/register';
    if (!signedIn && !onAuthScreen) return '/login';
    if (signedIn && onAuthScreen) return '/profile';
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    ShellRoute(
      builder: (context, state, child) => _MoodShell(child: child),
      routes: [
        GoRoute(path: '/profile', builder: (context, state) => const ProfileScreen()),
        GoRoute(path: '/friends', builder: (context, state) => const FriendsListScreen()),
        GoRoute(path: '/add-friend', builder: (context, state) => const AddFriendScreen()),
        GoRoute(path: '/notifications', builder: (context, state) => const NotificationsScreen()),
        GoRoute(path: '/privacy', builder: (context, state) => const PrivacyScreen()),
        GoRoute(path: '/blocked-accounts', builder: (context, state) => const BlockedAccountsScreen()),
        GoRoute(path: '/account-details', builder: (context, state) => const AccountDetailsScreen()),
        GoRoute(path: '/help-support', builder: (context, state) => const HelpSupportScreen()),
        GoRoute(path: '/moodify-create', builder: (context, state) => const MoodifyCreateScreen()),
      ],
    ),
  ],
);

/// Screens reachable from the tab bar — pressing back here is allowed to
/// exit the app (standard Android behavior for a bottom-nav "home" tab).
/// Every other shell route is a "detail" screen reached by pushing deeper
/// (Settings > Notifications, Friends > Add friend, etc).
const _rootTabPaths = {'/profile', '/friends', '/moodify-create'};

class _MoodShell extends ConsumerStatefulWidget {
  const _MoodShell({required this.child});

  final Widget child;

  @override
  ConsumerState<_MoodShell> createState() => _MoodShellState();
}

class _MoodShellState extends ConsumerState<_MoodShell> {
  DateTime? _lastBackPressAt;

  /// Was missing entirely — every shell route used `context.go(...)`,
  /// which *replaces* the location instead of pushing, so there was never
  /// anything for go_router to pop. That meant the Android hardware back
  /// button skipped straight past the app and closed it, from any screen
  /// (Settings > Notifications, Add friend, etc), not just the tab roots.
  ///
  /// Fix: intercept it here. From a "detail" screen, back goes to Profile
  /// instead of exiting. From a tab-root screen, use the standard
  /// double-back-to-exit pattern instead of exiting on the first press.
  Future<void> _handleBack(BuildContext context) async {
    final location = GoRouterState.of(context).matchedLocation;
    if (!_rootTabPaths.contains(location)) {
      context.go('/profile');
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressAt != null && now.difference(_lastBackPressAt!) < const Duration(seconds: 2)) {
      SystemNavigator.pop();
      return;
    }
    _lastBackPressAt = now;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Press back again to exit'), duration: Duration(seconds: 2)),
    );
  }

  @override
  Widget build(BuildContext context) {          // was: (BuildContext context, WidgetRef ref)
    final accent = ref.watch(moodAccentProvider); // `ref` now resolves to the ConsumerState property
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack(context);
      },
      child: MoodBackground(
        animate: true,
        spot1: accent.accentLight,
        spot2: accent.accent,
        child: widget.child,
      ),
    );
  }
}