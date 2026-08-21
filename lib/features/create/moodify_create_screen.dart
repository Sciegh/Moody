import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/mood_background.dart';
import '../../models/friend.dart';
import '../../models/mood_option.dart';
import '../../services/auth_providers.dart';
import '../../services/notifications_service.dart';
import '../../services/repositories/friends_repository.dart';
import '../../services/repositories/profile_repository.dart';
import 'create_controller.dart';
import 'widgets/audience_sheet.dart';
import 'widgets/composer_banners.dart';
import 'widgets/composer_body.dart';
import 'widgets/composer_top_bar.dart';
import 'widgets/mood_grid.dart';
import 'widgets/mood_orb.dart';
import 'widgets/paywall_sheet.dart';
import 'widgets/success_overlay.dart';

/// Migration of moodify-create.html — the largest and most complex source
/// screen (multi-step composer, dynamic per-mood theming, paywall,
/// notification-permission card, offline/error/success states).
///
/// The source's "prototype controls" panel (simulate offline / simulate
/// post-fails / reset) is explicitly labeled "not part of the app UI" in
/// the HTML — it's a design-review aid, not a shipped feature. Rather than
/// dropping it, it's kept here gated behind [kDebugMode] via
/// [_DevPanel], so it's available for exactly the same purpose (manual
/// QA of the error/offline states) without ever appearing in a release
/// build.
class MoodifyCreateScreen extends ConsumerStatefulWidget {
  const MoodifyCreateScreen({super.key});

  @override
  ConsumerState<MoodifyCreateScreen> createState() => _MoodifyCreateScreenState();
}

class _MoodifyCreateScreenState extends ConsumerState<MoodifyCreateScreen> {
  final _messageController = TextEditingController();
  MoodOption? _lastMood;

  // Anchors the "Add a message" section (ComposerBody) so we can scroll it
  // into view the moment a mood is picked — see [_scrollToComposerBody].
  final _composerBodyKey = GlobalKey();

  /// Called right after a mood gets selected (fresh pick, not just a
  /// re-render). Waits a frame so the newly-revealed ComposerBody section
  /// has actually been laid out before we try to scroll to it — calling
  /// this synchronously during the state change would still find the old
  /// layout (or no key context at all, on the very first selection).
  void _scrollToComposerBody() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final ctx = _composerBodyKey.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOut,
        alignment: 0.0, // top of the section, just under the mood grid
      );
    });
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _applySuggestion(String msg) {
    _messageController.text = msg;
    setState(() {});
  }

  /// "Sounds good" used to just dismiss the card like "Not now" did —
  /// nothing ever actually asked the OS for permission. This is the real
  /// prompt, via [NotificationsService].
  Future<void> _allowNotifications(ComposerController controller) async {
    final granted = await ref.read(notificationsServiceProvider).requestPermission();
    if (!mounted) return;
    controller.dismissNotifCard();
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("No worries — you can turn notifications on anytime from your device Settings.")),
      );
      return;
    }
    // Was missing — granting permission alone doesn't give a backend
    // anything to push to. This saves the device's FCM token onto the
    // profile doc so the Cloud Function in functions/index.js (triggered
    // on new `moodifies` writes) can look it up and actually deliver
    // "your friend posted" while this user is outside the app.
    final uid = ref.read(authServiceProvider).currentUserId;
    if (uid != null) {
      await ref.read(notificationsServiceProvider).syncTokenToProfile(ref.read(profileRepositoryProvider), uid);
    }
  }

  Future<void> _closeComposer(ComposerState state, ComposerController controller) async {
    if (state.moodSelected) {
      final discard = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard this Moodify?'),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Keep editing')),
            TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Discard')),
          ],
        ),
      );
      if (discard != true) return;
    }
    controller.resetAll();
    _messageController.clear();
  }

  void _openAudienceSheet(BuildContext context, ComposerController controller, String? uid) {
    controller.openAudienceSheet();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(composerControllerProvider);
          final List<Friend> friends =
              uid == null ? const [] : ref.watch(friendsStreamProvider(uid)).valueOrNull ?? const [];
          return AudienceSheet(
            mode: s.audienceMode,
            search: s.friendSearch,
            selectedFriends: s.selectedFriends,
            friends: friends,
            onModeChanged: controller.setAudienceMode,
            onSearchChanged: controller.setFriendSearch,
            onFriendToggle: controller.toggleFriend,
            onSave: () => Navigator.of(context).pop(),
          );
        },
      ),
    ).whenComplete(() => controller.closeAudienceSheet());
  }

  /// Locked (Deluxe) moods used to jump straight to the paywall on tap
  /// with no explanation — this stops first with a friendly heads-up, and
  /// only opens the paywall if the user actually wants to unlock.
  Future<void> _onLockedMoodTap(BuildContext context, ComposerController controller) async {
    final wantsToUnlock = await showCuteWarning(
      context,
      emoji: '🔒',
      title: 'That one\'s a Deluxe mood',
      message: 'Unlock Deluxe to use this mood — every core mood stays free, always.',
      dismissLabel: 'Not now',
      confirmLabel: 'Unlock',
    );
    if (wantsToUnlock == true && context.mounted) {
      _openPaywall(context, controller);
    }
  }

  void _openPaywall(BuildContext context, ComposerController controller) {
    controller.openPaywall();
    // Shared between the two closures below. Tracks whether the sheet's
    // route has already been popped (by any means) so the two paths that
    // can each independently want to pop it never both do so for the
    // same dismissal — that double-pop was the actual black-screen bug:
    // with nothing left of the sheet's own route to close, the second
    // pop closed the screen underneath it instead.
    var routeAlreadyClosed = false;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final s = ref.watch(composerControllerProvider);
          // Handles state-driven closes — right now that's only
          // buyDeluxe's auto-close a moment after a successful purchase,
          // where nothing tapped a button to pop the sheet directly.
          ref.listen(composerControllerProvider.select((s) => s.paywallOpen), (prev, isOpen) {
            if (prev == true && isOpen == false && !routeAlreadyClosed) {
              routeAlreadyClosed = true;
              Navigator.of(context).pop();
            }
          });
          return PaywallSheet(
            processing: s.paywallProcessing,
            unlocked: s.deluxeUnlocked,
            onBuy: controller.buyDeluxe,
            // Pops directly (this IS a direct user tap) and marks the
            // route closed so the ref.listen callback the state change
            // triggers doesn't also try to pop.
            onLater: () {
              routeAlreadyClosed = true;
              Navigator.of(context).pop();
              controller.closePaywall();
            },
          );
        },
      ),
    ).whenComplete(() {
      // Runs for every dismissal, including ones neither path above
      // caused directly — e.g. the user drags the sheet away or taps the
      // scrim, which pops the route straight through the framework. That
      // pop already happened, so this only needs to resync `paywallOpen`
      // back to false; setting the flag first stops the ref.listen
      // callback the resulting state change triggers from popping again.
      routeAlreadyClosed = true;
      if (ref.read(composerControllerProvider).paywallOpen) controller.closePaywall();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(composerControllerProvider);
    final controller = ref.read(composerControllerProvider.notifier);
    final mood = state.selectedMood;

    // Scroll down to "Add a message" the moment a mood is picked — covers
    // both the first pick (section was hidden, now appears) and switching
    // to a different mood (in case the user had scrolled away from it).
    ref.listen(composerControllerProvider.select((s) => s.selectedMood), (previous, next) {
      if (next != null && next.id != previous?.id) _scrollToComposerBody();
    });

    // Backs "All friends will be notified" counts (subtitle, success
    // message, sheet label) — was hardcoded to '12 friends' before.
    final uid = ref.watch(authServiceProvider).currentUserId;
    final totalFriends = uid == null ? 0 : (ref.watch(friendsStreamProvider(uid)).valueOrNull?.length ?? 0);

    if (mood != null) _lastMood = mood;

    final filteredMoods = state.activeFilter == 'all' ? kAllMoods : kAllMoods.where((m) => m.family == state.activeFilter).toList();

    return Scaffold(
      body: Stack(
        children: [
          MoodBackground(
            animate: true,
            spot1: state.accent.accentLight,
            spot2: state.accent.accent,
            child: SafeArea(
              child: Column(
                children: [
                  if (state.simulateOffline) const OfflineBanner(),
                  ComposerTopBar(
                    stepsActive: state.moodSelected ? 3 : 1,
                    onClose: () => _closeComposer(state, controller),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(24, 4, 24, 16),
                            child: Column(
                              children: [
                                MoodOrb(
                                  emoji: mood?.emoji ?? _lastMood?.emoji ?? '🙂',
                                  family: mood?.family ?? 'calm',
                                  gradientColors: [state.accent.accentLight, state.accent.accent, state.accent.accentDark],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  mood == null ? 'How ya feeling?' : '${mood.emoji} ${mood.label}',
                                  style: AppTextStyles.baloo(size: 23),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  mood == null
                                      ? "Pick the mood that fits — your friends will see it on their feed 💛"
                                      : 'This is how your Moodify will look to friends 💌',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w600, color: AppColors.inkDim),
                                ),
                              ],
                            ),
                          ),

                          if (state.notifCardVisible)
                            NotifCard(onAllow: () => _allowNotifications(controller), onSkip: controller.dismissNotifCard),

                          if (state.errorMessage != null)
                            ComposerErrorBanner(
                              message: state.errorMessage!,
                              onRetry: () => controller.retry(_messageController.text, totalFriends: totalFriends),
                            ),

                          Padding(
                            padding: const EdgeInsets.fromLTRB(20, 4, 20, 22),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text('Choose a mood', style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim)),
                                const SizedBox(height: 10),
                                if (!state.deluxeUnlocked) UnlockBanner(onTap: () => _openPaywall(context, controller)),
                                MoodFilterRow(activeFilter: state.activeFilter, onSelect: controller.setFilter),
                                const SizedBox(height: 10),
                                MoodGrid(
                                  moods: filteredMoods,
                                  selectedMood: state.selectedMood,
                                  deluxeUnlocked: state.deluxeUnlocked,
                                  onSelect: controller.selectMood,
                                  onLockedTap: () => _onLockedMoodTap(context, controller),
                                ),

                                if (mood != null) ...[
                                  SizedBox(height: 22, key: _composerBodyKey),
                                  ComposerBody(
                                    mood: mood,
                                    messageController: _messageController,
                                    onMessageChanged: () => setState(() {}),
                                    onSuggestionTap: _applySuggestion,
                                  ),
                                  IntentPillRow(
                                    mood: mood,
                                    selectedIntent: state.selectedIntent,
                                    onSelect: controller.toggleIntent,
                                  ),
                                  const SizedBox(height: 22),
                                  Text('Who sees this', style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim)),
                                  const SizedBox(height: 10),
                                  AudienceRow(
                                    title: state.audienceTitle,
                                    subtitle: state.audienceSubtitle(totalFriends),
                                    onTap: () => _openAudienceSheet(context, controller, uid),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Only your friends can see this Moodify. It fades from feeds after 24 hours, and you can delete it anytime from your profile.',
                                    style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint, height: 1.4),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + MediaQuery.of(context).padding.bottom),
                    decoration: BoxDecoration(
                      color: Color.lerp(AppColors.bg1, state.accent.accent, 0.14),
                      border: const Border(top: BorderSide(color: AppColors.line, width: 2)),
                    ),
                    child: ComposerPostButton(
                      status: state.postStatus,
                      moodSelected: state.moodSelected,
                      onTap: () => controller.post(_messageController.text, totalFriends: totalFriends),
                    ),
                  ),
                  AppTabBar(active: AppTab.create, accent: state.accent.accent),
                ],
              ),
            ),
          ),

          if (state.postStatus == PostStatus.success)
            Positioned.fill(
              child: SuccessOverlay(
                accent: state.accent,
                text: state.successText ?? '',
                onDone: controller.resetAll,
              ),
            ),

          if (kDebugMode)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: SafeArea(
                top: false,
                child: _DevPanel(
                  offline: state.simulateOffline,
                  simulateError: state.simulateError,
                  onToggleOffline: controller.toggleSimulateOffline,
                  onToggleError: controller.toggleSimulateError,
                  onReset: controller.resetAll,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Debug-only equivalent of the source's `.dev-panel` "prototype controls".
/// Never shown in a release build (see [kDebugMode] guard above).
class _DevPanel extends StatelessWidget {
  const _DevPanel({
    required this.offline,
    required this.simulateError,
    required this.onToggleOffline,
    required this.onToggleError,
    required this.onReset,
  });

  final bool offline;
  final bool simulateError;
  final VoidCallback onToggleOffline;
  final VoidCallback onToggleError;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.75),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          _DevButton(label: offline ? 'Simulate: back online' : 'Simulate: offline', onTap: onToggleOffline),
          _DevButton(label: simulateError ? 'Simulate: post succeeds' : 'Simulate: post fails', onTap: onToggleError),
          _DevButton(label: 'Reset prototype', onTap: onReset),
        ],
      ),
    );
  }
}

class _DevButton extends StatelessWidget {
  const _DevButton({required this.label, required this.onTap});
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10)),
        child: Text(label, style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
      ),
    );
  }
}