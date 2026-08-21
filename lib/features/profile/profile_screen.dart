import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart' show Timestamp;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/avatar_photo_picker.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/mascot_blob.dart';
import '../../core/providers/mood_accent_provider.dart';
import '../../models/mood_entry.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/moodify_repository.dart';
import '../../services/repositories/profile_repository.dart';
import 'profile_controller.dart';
import 'widgets/mood_chip_strip.dart';
import 'widgets/settings_list.dart';
import 'widgets/streak_sheet.dart';

/// Migration of Profile.html. See [LoginScreen] doc comment re: the
/// `.app-frame` phone bezel not being carried over.
///
/// The bottom `.tabbar` (Create / Friends / Profile) is reproduced as a
/// [BottomNavigationBar]-style row here rather than lifted into a
/// `go_router` [ShellRoute], since Friends and Create aren't migrated yet
/// in this pass — revisit once all three tab destinations are real screens,
/// so the tab bar persists across them instead of being rebuilt per screen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final _scrollController = ScrollController();
  final _settingsKey = GlobalKey();
  File? _pickedPhoto;

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _openStreakSheet(BuildContext context, WidgetRef ref, int streak, String uid) {
    ref.read(profileControllerProvider.notifier).openStreakSheet();
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => Consumer(
        builder: (context, ref, _) {
          final activity = ref.watch(last7DaysActivityStreamProvider(uid)).valueOrNull ?? List.filled(7, false);
          return StreakSheet(streak: streak, week: buildWeek(activity));
        },
      ),
    ).whenComplete(() => ref.read(profileControllerProvider.notifier).closeStreakSheet());
  }

  /// Press-and-hold on a "Recent moods" chip — was entirely missing (the
  /// composer's own footer and Help & Support both promised "delete it
  /// anytime from your profile" / "tap the trash icon," but nothing in
  /// the app could actually open a moodify or delete one). Opens a small
  /// detail sheet for that entry with a trash icon to remove it.
  void _openMoodDetail(BuildContext context, WidgetRef ref, String uid, MoodEntry mood) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoodDetailSheet(
        mood: mood,
        onDelete: mood.id == null ? null : () => _confirmDeleteMood(context, ref, uid, mood),
      ),
    );
  }

  Future<void> _confirmDeleteMood(BuildContext context, WidgetRef ref, String uid, MoodEntry mood) async {
    Navigator.of(context).pop(); // close the detail sheet first
    final confirmed = await showCuteWarning(
      context,
      emoji: '🗑️',
      title: 'Delete this Moodify?',
      message: "It'll be removed from your Recent moods and from everyone's feed right away. This can't be undone.",
      dismissLabel: 'Cancel',
      confirmLabel: 'Delete',
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await ref.read(moodifyRepositoryProvider).deleteMoodify(
            uid: uid,
            moodHistoryDocId: mood.id!,
            moodifyId: mood.moodifyId,
          );
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Moodify deleted')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't delete that Moodify — check your connection and try again")),
      );
    }
  }

  Future<void> _confirmLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Log out of Moodify?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Log out')),
        ],
      ),
    );
    if (confirmed != true) return;
    // Was missing entirely before — the dialog navigated straight to
    // /login without ever signing out of Firebase, leaving the session
    // active. Sign out first, then navigate.
    await ref.read(authServiceProvider).logout();
    if (context.mounted) context.go('/login');
  }

  String _formatJoined(dynamic createdAt) {
    if (createdAt is! Timestamp) return '';
    const months = [
      'January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December',
    ];
    final d = createdAt.toDate();
    return 'joined ${months[d.month - 1]} ${d.year}';
  }

  /// "Feeling {mood} today." — shown under the display name when
  /// the user's most recent mood entry is from today. `recentMoods` is
  /// ordered most-recent-first (see MoodChipStrip / kMockRecentMoods), so
  /// the current mood is always index 0; anything older than today (no
  /// entry posted yet) just omits the line rather than showing stale info.
  String? _moodStatusLine(List<MoodEntry> recentMoods) {
    if (recentMoods.isEmpty) return null;
    final latest = recentMoods.first;
    if (formatMoodDay(latest.date) != 'Today' || latest.label == null || latest.label!.isEmpty) return null;
    return 'Is feeling ${latest.label!.toLowerCase()} today.';
  }

  Future<void> _editAvatar(String? uid) async {
    if (uid == null) return;
    final photo = await pickAvatarPhoto(context);
    if (photo == null || !mounted) return;
    final previousPhoto = _pickedPhoto;
    setState(() => _pickedPhoto = photo);
    try {
      // See ProfileRepository.uploadAvatar doc comment — this is what
      // actually persists the photo (to Firebase Storage + the profile
      // doc's `photoUrl`) instead of it only living in this screen's
      // local `File` state, which reverted on every app restart.
      await ref.read(profileRepositoryProvider).uploadAvatar(uid: uid, file: photo);
    } catch (_) {
      if (!mounted) return;
      // Roll the optimistic preview back — without this, a failed upload
      // still left the newly-picked photo showing on screen even though
      // nothing was actually saved, so the avatar silently "succeeded"
      // from the user's point of view right up until their next restart.
      setState(() => _pickedPhoto = previousPhoto);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't upload photo — check your connection and try again")),
      );
    }
  }

  void _jumpToSettings() {
    final settingsContext = _settingsKey.currentContext;
    if (settingsContext == null) return;
    Scrollable.ensureVisible(
      settingsContext,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {  
    final accent = ref.watch(moodAccentProvider);
    final uid = ref.watch(authServiceProvider).currentUserId;

    // Falls back to sensible defaults while the Firestore doc is still
    // loading, or for an older account created before profile documents
    // existed — see ProfileRepository.ensureProfileDocument().
    final realRecentMoods = uid == null ? null : ref.watch(recentMoodsStreamProvider(uid)).valueOrNull;
    final recentMoods = (realRecentMoods == null || realRecentMoods.isEmpty) ? kMockRecentMoods : realRecentMoods;
    if (realRecentMoods != null && realRecentMoods.isNotEmpty) {
      // Real history is in — reflect the user's actual last mood in the
      // app-wide background, same as the source script did on load.
      // No-ops after the first call, or once the user has picked a mood
      // themselves this session (see MoodAccentController).
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(moodAccentProvider.notifier).seedFromRecentMoodIfUnset(realRecentMoods.first);
      });
    }
    final profileData = uid == null ? null : ref.watch(profileStreamProvider(uid)).valueOrNull;
    final name = profileData?['name'] as String? ?? '';
    // Empty, not a placeholder string — lets the existing
    // `handle.isEmpty ? joined : '@$handle...'` fallback below degrade
    // gracefully to just the join date instead of showing a fake handle.
    final handle = profileData?['handle'] as String? ?? '';
    final joined = _formatJoined(profileData?['createdAt']);
    final streak = profileData?['streak'] as int? ?? 0;
    final friendCount = profileData?['friendCount'] as int? ?? 0;
    final moodifyCount = profileData?['moodifyCount'] as int? ?? 0;
    final photoUrl = profileData?['photoUrl'] as String?;
    final moodStatus = _moodStatusLine(recentMoods);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(20, 6, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerRight,
                        child: CircleIconButton(
                          semanticLabel: 'Jump to settings',
                          onPressed: _jumpToSettings,
                          child: const Text('⚙️'),
                        ),
                      ),
                      const SizedBox(height: 6),

                      Center(
                        child: Column(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                _pickedPhoto != null
                                    ? CircleAvatar(radius: 48, backgroundImage: FileImage(_pickedPhoto!))
                                    : photoUrl != null
                                        ? CircleAvatar(radius: 48, backgroundImage: NetworkImage(photoUrl))
                                        : const MascotBlob(
                                            emoji: '🙂',
                                            size: 96,
                                            gradientColors: [Color(0xFFFFC1D2), AppColors.coral, AppColors.coralDark],
                                            motion: MascotMotion.sway,
                                          ),
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: CircleIconButton(
                                    size: 30,
                                    fontSize: 13,
                                    semanticLabel: 'Edit avatar',
                                    onPressed: () => _editAvatar(uid),
                                    child: const Text('✏️'),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text(name, style: AppTextStyles.baloo(size: 20)),
                            if (moodStatus != null) ...[
                              const SizedBox(height: 3),
                              Text(
                                moodStatus,
                                textAlign: TextAlign.center,
                                style: AppTextStyles.quicksand(
                                  size: 12.5,
                                  weight: FontWeight.w600,
                                  color: AppColors.inkDim,
                                ),
                              ),
                            ],
                            const SizedBox(height: 2),
                            Text(
                              handle.isEmpty ? joined : '@$handle${joined.isEmpty ? '' : ' · $joined'}',
                              style: AppTextStyles.quicksand(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: AppColors.inkFaint,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(
                            child: _StreakStatCard(
                              streak: streak,
                              onTap: uid == null ? null : () => _openStreakSheet(context, ref, streak, uid),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(value: '$friendCount', label: 'FRIENDS')),
                          const SizedBox(width: 10),
                          Expanded(child: _StatCard(value: '$moodifyCount', label: 'MOODIFIES')),
                        ],
                      ),
                      const SizedBox(height: 20),

                      Text(
                        'Recent moods',
                        style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim),
                      ),
                      const SizedBox(height: 10),
                      MoodChipStrip(
                        moods: recentMoods,
                        onTap: (mood) => ref.read(profileControllerProvider.notifier).selectMoodAccent(mood),
                        onLongPress: uid == null ? null : (mood) => _openMoodDetail(context, ref, uid, mood),
                      ),
                      const SizedBox(height: 10),

                      Text(
                        'Settings',
                        key: _settingsKey,
                        style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim),
                      ),
                      const SizedBox(height: 10),
                      SettingsList(
                        onNotifications: () => context.go('/notifications'),
                        onPrivacy: () => context.go('/privacy'),
                        onAccountDetails: () => context.go('/account-details'),
                        onHelpSupport: () => context.go('/help-support'),
                        onLogout: () => _confirmLogout(context, ref),
                      ),
                    ],
                  ),
                ),
              ),
              AppTabBar(active: AppTab.profile, accent: accent.accent),
            ],
          ),
        )
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.baloo(size: 18)),
          Text(
            label,
            style: AppTextStyles.quicksand(size: 10.5, weight: FontWeight.w700, color: AppColors.inkFaint),
          ),
        ],
      ),
    );
  }
}

class _StreakStatCard extends StatefulWidget {
  const _StreakStatCard({required this.streak, required this.onTap});

  final int streak;
  final VoidCallback? onTap;

  @override
  State<_StreakStatCard> createState() => _StreakStatCardState();
}

class _StreakStatCardState extends State<_StreakStatCard> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final flame = flameForStreak(widget.streak);
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFFFE9D2), AppColors.paper],
          ),
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.line, offset: Offset(0, _pressed ? 1 : 3))],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(flame, style: const TextStyle(fontSize: 20)),
                const SizedBox(width: 3),
                Text('${widget.streak}', style: AppTextStyles.baloo(size: 18)),
              ],
            ),
            Text(
              'MOOD STREAK',
              style: AppTextStyles.quicksand(size: 10.5, weight: FontWeight.w700, color: AppColors.inkFaint),
            ),
          ],
        ),
      ),
    );
  }
}

/// The "open a moodify from your profile" detail sheet — shows what was
/// posted and, when it's real Firestore data (i.e. [mood.id] isn't null),
/// a trash icon to delete it. Mock/demo entries still show the Delete
/// button — it's just disabled — so the sheet's layout doesn't shift
/// depending on where the data came from.
class _MoodDetailSheet extends StatelessWidget {
  const _MoodDetailSheet({required this.mood, required this.onDelete});

  final MoodEntry mood;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final canDelete = onDelete != null;
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
        decoration: BoxDecoration(
          // Was a flat AppColors.paper fill with only the little emoji
          // circle carrying the mood's color — now the whole sheet washes
          // through that mood's palette, from its accent at the top down
          // to paper at the bottom. Solid colors (no alpha) so the panel
          // reads as a real themed surface instead of a faint tint.
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [mood.accent, mood.accentLight, AppColors.paper],
            stops: const [0.0, 0.45, 1.0],
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.paper,
                shape: BoxShape.circle,
                boxShadow: const [BoxShadow(color: AppColors.line, blurRadius: 6, offset: Offset(0, 2))],
              ),
              child: Text(mood.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(height: 12),
            Text(mood.label ?? 'Moodify', style: AppTextStyles.baloo(size: 17)),
            const SizedBox(height: 4),
            Text(
              formatMoodDay(mood.date),
              style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkFaint),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      backgroundColor: AppColors.paper,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text('Close', style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton.icon(
                    style: TextButton.styleFrom(
                      backgroundColor: canDelete ? AppColors.coral : AppColors.coral.withValues(alpha: 0.35),
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                    ),
                    onPressed: onDelete,
                    icon: Icon(Icons.delete_rounded, size: 16, color: Colors.white.withValues(alpha: canDelete ? 1 : 0.7)),
                    label: Text(
                      'Delete',
                      style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w800, color: Colors.white.withValues(alpha: canDelete ? 1 : 0.7)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}