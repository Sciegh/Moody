import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'firebase_options.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'services/notifications_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  // Must be registered before runApp, and with a top-level function (see
  // notifications_service.dart) — this is what lets FCM wake the app to
  // handle a message while it's fully backgrounded/terminated.
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  // Sets up the local-notifications plugin, Android channel, and the
  // foreground-push / notification-tap listeners. Safe to call before
  // permission has been granted — it only starts producing visible
  // notifications once NotificationsService.requestPermission() succeeds.
  // Created once here and shared with the rest of the app via the
  // provider override below, rather than letting notificationsServiceProvider's
  // default create a second, never-initialized instance.
  final notifications = NotificationsService();
  await notifications.init();

  runApp(ProviderScope(
    overrides: [notificationsServiceProvider.overrideWithValue(notifications)],
    child: const MoodifyApp(),
  ));
}

class MoodifyApp extends StatelessWidget {
  const MoodifyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Moodify',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      routerConfig: appRouter,
    );
  }
}
