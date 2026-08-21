import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:go_router/go_router.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import '../core/router/app_router.dart';
import 'repositories/profile_repository.dart';

/// Must stay a top-level (or static) function — FCM re-registers it on the
/// isolate it spins up to deliver a message while the app is fully
/// backgrounded/terminated, so it can't close over any app state. Wired up
/// via `FirebaseMessaging.onBackgroundMessage` in main.dart, *before*
/// `runApp`.
///
/// Notification-style pushes (the kind the not-yet-written Cloud Function
/// in functions/index.js would send) already show themselves via the OS in
/// this state — nothing to do here. This only matters if a future payload
/// switches to data-only messages, which need to be shown explicitly.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// The channel every notification this app shows (foreground pushes *and*
/// the local daily reminder) is posted on. Android requires a channel to
/// exist before posting to it — created once in [NotificationsService.init].
const _androidChannelId = 'moodify_default';
const _androidChannelName = 'Moodify';
const _androidChannelDescription = 'Friend moodifies, reactions, streaks, and reminders';

/// Id for the recurring "Daily check-in reminder" local notification —
/// fixed so re-scheduling it (or cancelling it) always targets the same
/// slot instead of stacking duplicates.
const _dailyReminderId = 1001;

/// Wraps two related things this app needs from notifications:
///
/// 1. **Push (FCM)** — the OS-level permission prompt, saving the signed-in
///    user's FCM device token to their profile doc, and (new) actually
///    *showing* a push while the app is in the foreground. Without a local
///    notifications plugin, Android silently drops a foreground FCM
///    message — it only auto-displays one when the app is backgrounded.
///    `flutter_local_notifications` is what renders it in both cases.
/// 2. **Local scheduling** — the "Daily check-in reminder" toggle on the
///    Notifications screen. That one doesn't depend on a server at all, so
///    it's a plain locally-scheduled notification, not a push.
///
/// Delivering "your friend posted a Moodify" while that friend is outside
/// the app still requires a server-side Cloud Function (see the doc
/// comment this class had before — functions/index.js, deployed
/// separately). This class is the client-side half either way: it's what
/// makes a push actually visible once it arrives, and what saves the token
/// a Cloud Function would send to.
class NotificationsService {
  NotificationsService([FirebaseMessaging? messaging]) : _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseMessaging _messaging;
  final FlutterLocalNotificationsPlugin _local = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  /// One-time setup: the local-notifications plugin (Android channel +
  /// iOS init), the timezone database the daily reminder's scheduling
  /// needs, and the listeners that turn an incoming FCM message into a
  /// visible notification and a tap into navigation. Call once, early in
  /// `main()`, before `runApp` — see main.dart.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;

    await _configureLocalTimeZone();

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    // Alert/badge/sound permission requests are left to
    // NotificationsService.requestPermission() (via FirebaseMessaging),
    // which already drives the single OS prompt from the Notifications
    // screen's master switch — asking again here would just be a second,
    // redundant iOS permission dialog.
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) => _handleLocalTap(response.payload),
    );

    const channel = AndroidNotificationChannel(
      _androidChannelId,
      _androidChannelName,
      description: _androidChannelDescription,
      importance: Importance.high,
    );
    await _local
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(channel);

    // Lets a foreground push show its OS banner on iOS the same way it
    // would if the app were backgrounded. Android has no equivalent
    // setting — that's what the onMessage listener below is for.
    await _messaging.setForegroundNotificationPresentationOptions(alert: true, badge: true, sound: true);

    FirebaseMessaging.onMessage.listen(_showForegroundPush);
    FirebaseMessaging.onMessageOpenedApp.listen(_handlePushTap);
    // Covers the case where tapping a push is what launched the app from
    // fully terminated — onMessageOpenedApp alone only fires for taps
    // while the app was already running in the background.
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) _handlePushTap(initialMessage);
  }

  /// `zonedSchedule` needs a real local timezone (DST-aware), not just
  /// UTC — otherwise "8pm" would drift by an hour twice a year for anyone
  /// in a timezone that observes daylight saving.
  Future<void> _configureLocalTimeZone() async {
    tz_data.initializeTimeZones();
    final timezoneInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
  }

  /// Shows the system permission prompt (iOS) or is a no-op where the OS
  /// grants silently (Android < 13) / where it's already been decided.
  /// Also requests the Android 13+ runtime notification permission that
  /// `flutter_local_notifications` needs to post anything at all — FCM's
  /// own `requestPermission()` only covers push, not local notifications.
  /// Returns true if notifications end up authorized.
  Future<bool> requestPermission() async {
    final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
    final fcmAuthorized = settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;

    final androidLocal = _local.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    final androidGranted = await androidLocal?.requestNotificationsPermission();

    // Android < 13 (no runtime prompt, androidGranted stays null) should
    // fall through to the FCM result; Android 13+ needs both to actually
    // agree, since either one alone means nothing shows up.
    return androidGranted == false ? false : fcmAuthorized;
  }

  /// Checks the current permission status without prompting — used to
  /// keep the Notifications screen's master switch honest if the user
  /// denied the OS prompt (or changed it in system Settings) instead of
  /// letting the in-app switch silently drift out of sync with reality.
  Future<bool> isAuthorized() async {
    final settings = await _messaging.getNotificationSettings();
    return settings.authorizationStatus == AuthorizationStatus.authorized ||
        settings.authorizationStatus == AuthorizationStatus.provisional;
  }

  /// Fetches the device's current FCM token and saves it to the signed-in
  /// user's profile doc (`fcmToken`), and re-saves it whenever FCM rotates
  /// it. No-ops quietly if permission isn't authorized yet or the token
  /// isn't available (e.g. simulator without push entitlements) — this is
  /// best-effort and shouldn't block anything else in the caller.
  Future<void> syncTokenToProfile(ProfileRepository profileRepo, String uid) async {
    try {
      final token = await _messaging.getToken();
      if (token != null) {
        await profileRepo.saveFcmToken(uid: uid, token: token);
      }
    } catch (_) {
      // Best-effort — a missing token shouldn't surface as a user-facing
      // error anywhere that calls this.
    }
    _messaging.onTokenRefresh.listen((newToken) {
      profileRepo.saveFcmToken(uid: uid, token: newToken).catchError((_) {});
    });
  }

  /// Renders an incoming push as a visible notification while the app is
  /// open. Android drops FCM's own auto-display in this state, so without
  /// this, "Friend moodifies" / "Reactions & comments" pushes would
  /// silently do nothing whenever the app happened to be in the
  /// foreground when they arrived.
  Future<void> _showForegroundPush(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      payload: message.data['route'] as String?,
    );
  }

  void _handlePushTap(RemoteMessage message) => _navigate(message.data['route'] as String?);

  void _handleLocalTap(String? payload) => _navigate(payload);

  /// Routes a tapped notification (push or local) to a sensible screen.
  /// `route` is whatever the sender put in the payload — a Cloud Function
  /// push would set `data: {route: '/friends'}`; the daily reminder below
  /// points at the composer, since that's the point of the nudge.
  void _navigate(String? route) {
    if (route == null || route.isEmpty) return;
    final context = rootNavigatorKey.currentContext;
    if (context == null) return;
    GoRouter.of(context).go(route);
  }

  /// Schedules (or re-schedules) the recurring 8pm local notification
  /// backing the "Daily check-in reminder" toggle on the Notifications
  /// screen. Purely local — doesn't touch Firestore or need the user to
  /// be online, since it's just "you haven't posted today," not anything
  /// server-derived.
  Future<void> scheduleDailyCheckInReminder() async {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, 20);
    if (scheduled.isBefore(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }
    await _local.zonedSchedule(
      id: _dailyReminderId,
      title: "Haven't posted today?",
      body: 'Let your friends know how you\'re feeling.',
      scheduledDate: scheduled,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _androidChannelId,
          _androidChannelName,
          channelDescription: _androidChannelDescription,
          importance: Importance.defaultImportance,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Re-fires at the same clock time every day rather than once.
      matchDateTimeComponents: DateTimeComponents.time,
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      payload: '/moodify-create',
    );
  }

  Future<void> cancelDailyCheckInReminder() => _local.cancel(id: _dailyReminderId);
}

final notificationsServiceProvider = Provider<NotificationsService>((ref) => NotificationsService());
