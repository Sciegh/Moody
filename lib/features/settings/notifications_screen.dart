import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/detail_top_bar.dart';
import '../../core/widgets/save_toast.dart';
import '../../core/widgets/toggle_setting_row.dart';
import '../../services/notifications_service.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/profile_repository.dart';

class _NotifSetting {
  _NotifSetting({required this.emoji, required this.title, required this.subtitle, required this.value});
  final String emoji;
  final String title;
  final String subtitle;
  bool value;
}

/// Migration of notifications.html.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key});

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  // Starts false rather than true — was defaulting to "on" without the OS
  // permission ever having actually been granted. Real status is checked
  // as soon as the screen loads (see initState) and kept honest from then
  // on via NotificationsService, instead of just being local UI state.
  bool _master = false;
  bool _checkingPermission = true;
  final _toast = SaveToastController();

  @override
  void initState() {
    super.initState();
    _syncWithSystemPermission();
  }

  Future<void> _syncWithSystemPermission() async {
    final authorized = await ref.read(notificationsServiceProvider).isAuthorized();
    if (!mounted) return;
    setState(() {
      _master = authorized;
      _checkingPermission = false;
    });
    // Was missing — a returning user who already granted permission (in
    // an earlier session, or from the composer's card) never got their
    // FCM token (re)saved here, so a rotated token would go stale and
    // the Cloud Function in functions/index.js would have nothing
    // current to push to. Best-effort; doesn't block the toggle UI.
    if (authorized) {
      final uid = ref.read(authServiceProvider).currentUserId;
      if (uid != null) {
        unawaited(ref.read(notificationsServiceProvider).syncTokenToProfile(ref.read(profileRepositoryProvider), uid));
      }
    }
    _syncDailyReminder(_moodifies[2].value);
  }

  /// Turning the master switch on now actually requests the OS permission
  /// instead of just flipping a local bool. Turning it off can't revoke
  /// OS permission (no app can do that on iOS/Android) — it's pointed at
  /// system Settings instead, same as most apps handle this.
  Future<void> _setMaster(bool v) async {
    if (!v) {
      setState(() => _master = false);
      unawaited(ref.read(notificationsServiceProvider).cancelDailyCheckInReminder());
      _toast.show('Turn notifications off from your device Settings to fully disable them');
      return;
    }
    final granted = await ref.read(notificationsServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() => _master = granted);
    if (granted) {
      _flashSaved();
      final uid = ref.read(authServiceProvider).currentUserId;
      if (uid != null) {
        unawaited(ref.read(notificationsServiceProvider).syncTokenToProfile(ref.read(profileRepositoryProvider), uid));
      }
      _syncDailyReminder(_moodifies[2].value);
    } else {
      _toast.show("Notifications are off in system Settings — enable them there first");
    }
  }

  final _moodifies = [
    _NotifSetting(emoji: '💭', title: 'Friend moodifies', subtitle: "When a friend posts how they're feeling", value: true),
    _NotifSetting(emoji: '💛', title: 'Reactions & comments', subtitle: 'When someone responds to your moodify', value: true),
    _NotifSetting(emoji: '⏰', title: 'Daily check-in reminder', subtitle: "A gentle nudge if you haven't posted by 8pm", value: true),
  ];

  /// The daily reminder is the one row in `_moodifies` backed by a real
  /// local notification rather than a server-side push — everything else
  /// here is still just a preference flag until a Cloud Function reads
  /// it. Schedules on first load if already on (e.g. returning user),
  /// and whenever the row's own switch flips, independent of the other
  /// rows sharing this list.
  void _syncDailyReminder(bool enabled) {
    final service = ref.read(notificationsServiceProvider);
    if (enabled && _master) {
      unawaited(service.scheduleDailyCheckInReminder());
    } else {
      unawaited(service.cancelDailyCheckInReminder());
    }
  }
  final _friends = [
    _NotifSetting(emoji: '👥', title: 'Friend requests', subtitle: 'When someone wants to connect', value: true),
    _NotifSetting(emoji: '🎉', title: 'Streaks & milestones', subtitle: 'Streak saves, new badges, anniversaries', value: true),
  ];
  final _digest = [
    _NotifSetting(emoji: '📬', title: 'Weekly recap email', subtitle: 'A summary of your week in moods', value: false),
  ];

  @override
  void dispose() {
    _toast.dispose();
    super.dispose();
  }

  void _flashSaved() => _toast.show('Saved ✓');

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Text(text, style: AppTextStyles.baloo(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
      );

  List<Widget> _rowsFor(List<_NotifSetting> settings, {void Function(_NotifSetting setting, bool value)? onExtra}) {
    return settings
        .map((s) => ToggleSettingRow(
              emoji: s.emoji,
              title: s.title,
              subtitle: s.subtitle,
              value: s.value,
              onChanged: _master
                  ? (v) => setState(() {
                        s.value = v;
                        _flashSaved();
                        onExtra?.call(s, v);
                      })
                  : null,
            ))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  DetailTopBar(title: 'Notifications', onBack: () => context.go('/profile')),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Choose what Moodify can nudge you about. You can change these any time.',
                            style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
                          ),
                          const SizedBox(height: 4),
                          _sectionTitle('General'),
                          ToggleSettingRow(
                            emoji: '🔔',
                            title: 'Push notifications',
                            subtitle: 'Master switch for all alerts',
                            value: _master,
                            onChanged: _checkingPermission ? null : (v) => _setMaster(v),
                          ),
                          _sectionTitle('Moodifies'),
                          ..._rowsFor(_moodifies, onExtra: (s, v) {
                            if (identical(s, _moodifies[2])) _syncDailyReminder(v);
                          }),
                          _sectionTitle('Friends'),
                          ..._rowsFor(_friends),
                          _sectionTitle('Digest'),
                          ..._rowsFor(_digest),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SaveToast(controller: _toast),
            ],
          ),
        )
    );
  }
}