import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/mood_background.dart';
import '../../core/widgets/save_toast.dart';
import '../../core/widgets/search_field.dart';
import '../../models/friend.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/friends_repository.dart';

/// Migration of friends-list.html.
class FriendsListScreen extends ConsumerStatefulWidget {
  const FriendsListScreen({super.key});

  @override
  ConsumerState<FriendsListScreen> createState() => _FriendsListScreenState();
}

class _FriendsListScreenState extends ConsumerState<FriendsListScreen> {
  final _searchController = TextEditingController();
  String _filter = '';
  final _toast = SaveToastController();

  @override
  void dispose() {
    _searchController.dispose();
    _toast.dispose();
    super.dispose();
  }

  List<Friend> _matches(List<Friend> friends) {
    final f = _filter.trim().toLowerCase();
    if (f.isEmpty) return friends;
    return friends.where((fr) => fr.name.toLowerCase().contains(f) || fr.handle.toLowerCase().contains(f)).toList();
  }

  void _showToast(String message) => _toast.show(message, duration: const Duration(milliseconds: 1800));

  void _onRowTap(Friend f) {
    if (!f.hasMood) {
      _showToast("${f.name} hasn't shared a mood recently");
      return;
    }
    // Was just emoji + mood name — now includes their actual message
    // (when they posted one), since that's what the "Add a message" step
    // in the composer is for.
    final hasMessage = f.message != null && f.message!.trim().isNotEmpty;
    // The "Let friends know (optional)" intent pill (Available to talk /
    // Need space / etc) was being saved on post but never surfaced
    // anywhere a friend could actually see it — this and the badge in
    // _FriendRow below are the two places it's now shown.
    final intentSuffix = f.intentLabel != null ? ' · ${f.intentLabel}' : '';
    _showToast(
      hasMessage
          ? '${f.name} is feeling ${f.mood!.toLowerCase()} ${f.emoji} — "${f.message}"$intentSuffix'
          : '${f.name} is feeling ${f.mood!.toLowerCase()} ${f.emoji}$intentSuffix',
    );
  }

  void _toggleAck(String uid, Friend f) {
    final nowAcked = !f.acked;
    // Real read-receipt, written to the friendship doc — replaces the old
    // local-only `ackedHandles` Set.
    ref.read(friendsRepositoryProvider).setMoodSeen(uid: uid, friendUid: f.uid, seen: nowAcked);
    _showToast(nowAcked ? '${f.name} will see you noticed their mood' : 'Seen mark removed');
  }

  // Was missing entirely — FriendsRepository could send, accept, and
  // decline requests, but nothing in the app let you end an existing
  // friendship. Long-press mirrors the confirm-then-delete pattern
  // already used for account deletion elsewhere in the app.
  Future<void> _confirmRemoveFriend(String uid, Friend f) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Remove ${f.name}?'),
        content: Text("You won't see ${f.name}'s moods anymore, and they won't see yours. You can always send a new friend request later."),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendsRepositoryProvider).removeFriend(uid: uid, friendUid: f.uid);
      if (!mounted) return;
      _showToast('${f.name} removed from your friends');
    } catch (_) {
      if (!mounted) return;
      _showToast("Couldn't remove ${f.name} — check your connection and try again");
    }
  }

  /// Long-press entry point for a friend row — was a direct jump to the
  /// remove-friend confirm dialog with no way to block or report someone
  /// from the Friends list. Help & Support has always claimed a "•••
  /// menu, then Report or Block" existed on a person's profile, but no
  /// such thing was ever built anywhere in the app; this (and
  /// [_confirmBlock]/[_reportFriend] below) is that feature, made real.
  Future<void> _openFriendActions(String uid, Friend f) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) => _FriendActionsSheet(name: f.name),
    );
    if (!mounted || action == null) return;
    switch (action) {
      case 'remove':
        await _confirmRemoveFriend(uid, f);
        break;
      case 'block':
        await _confirmBlock(uid, f);
        break;
      case 'report':
        await _reportFriend(uid, f);
        break;
    }
  }

  Future<void> _confirmBlock(String uid, Friend f) async {
    final confirmed = await showCuteWarning(
      context,
      emoji: '🚫',
      title: 'Block ${f.name}?',
      message: "They won't be able to see your moods or contact you, and you'll stop seeing theirs. "
          "This also ends your friendship. You can unblock them anytime from Privacy settings.",
      dismissLabel: 'Cancel',
      confirmLabel: 'Block',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendsRepositoryProvider).blockUser(uid: uid, blockedUid: f.uid, name: f.name, handle: f.handle);
      if (!mounted) return;
      _showToast('${f.name} has been blocked');
    } catch (_) {
      if (!mounted) return;
      _showToast("Couldn't block ${f.name} — check your connection and try again");
    }
  }

  Future<void> _reportFriend(String uid, Friend f) async {
    final result = await showModalBottomSheet<Map<String, String>>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _ReportSheet(name: f.name),
    );
    if (!mounted || result == null) return;

    try {
      await ref.read(friendsRepositoryProvider).reportUser(
            uid: uid,
            reportedUid: f.uid,
            reason: result['reason']!,
            details: result['details'],
          );
      if (!mounted) return;
      _showToast("Thanks — we'll take a look and follow up if needed");
    } catch (_) {
      if (!mounted) return;
      _showToast("Couldn't send that report — check your connection and try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authServiceProvider).currentUserId;
    final allFriends = uid == null ? const <Friend>[] : ref.watch(friendsStreamProvider(uid)).valueOrNull ?? const <Friend>[];
    final pendingCount = uid == null ? 0 : ref.watch(pendingRequestCountStreamProvider(uid)).valueOrNull ?? 0;
    final matches = _matches(allFriends);
    final active = matches.where((f) => f.hasMood).toList();
    final quiet = matches.where((f) => !f.hasMood).toList();

    return Scaffold(
      body: MoodBackground(
        spot1: const Color(0xFFDCC3F2),
        spot2: AppColors.lilac,
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('Friends', style: AppTextStyles.baloo(size: 22)),
                              const SizedBox(height: 3),
                              Text(
                                '${allFriends.length} friends sharing moods with you',
                                style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkDim),
                              ),
                            ],
                          ),
                        ),
                        _IconLinkButton(
                          emoji: '➕',
                          semanticLabel: 'Add friends',
                          onTap: () => context.go('/add-friend'),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          AppSearchField(
                            controller: _searchController,
                            placeholder: 'Search your friends',
                            onChanged: (v) => setState(() => _filter = v),
                          ),
                          const SizedBox(height: 14),

                          if (pendingCount > 0)
                            _RequestsBanner(
                              count: pendingCount,
                              onTap: () => context.go('/add-friend'),
                            ),

                          if (matches.isEmpty)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 44),
                              child: Column(
                                children: [
                                  const Text('🫥', style: TextStyle(fontSize: 34)),
                                  const SizedBox(height: 10),
                                  Text(
                                    'No friends match that search.',
                                    style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkFaint),
                                  ),
                                ],
                              ),
                            )
                          else ...[
                            if (active.isNotEmpty) ...[
                              _sectionTitle('Sharing their mood today'),
                              ...active.map((f) => _FriendRow(
                                    friend: f,
                                    index: allFriends.indexOf(f),
                                    acked: f.acked,
                                    onTap: () => _onRowTap(f),
                                    onAckToggle: uid == null ? null : () => _toggleAck(uid, f),
                                    onLongPress: uid == null ? null : () => _openFriendActions(uid, f),
                                  )),
                            ],
                            if (quiet.isNotEmpty) ...[
                              _sectionTitle('Quiet for now'),
                              ...quiet.map((f) => _FriendRow(
                                    friend: f,
                                    index: allFriends.indexOf(f),
                                    acked: false,
                                    onTap: () => _onRowTap(f),
                                    onAckToggle: null,
                                    onLongPress: uid == null ? null : () => _openFriendActions(uid, f),
                                  )),
                            ],
                          ],
                        ],
                      ),
                    ),
                  ),
                  const AppTabBar(active: AppTab.friends, accent: AppColors.lilac),
                ],
              ),
              SaveToast(controller: _toast, bottomOffset: 88),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 16, 2, 10),
        child: Text(text, style: AppTextStyles.baloo(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
      );
}

class _IconLinkButton extends StatelessWidget {
  const _IconLinkButton({required this.emoji, required this.semanticLabel, required this.onTap});

  final String emoji;
  final String semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 38,
          height: 38,
          alignment: Alignment.center,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.paper,
            boxShadow: [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
          ),
          child: Text(emoji, style: const TextStyle(fontSize: 16)),
        ),
      ),
    );
  }
}

class _RequestsBanner extends StatelessWidget {
  const _RequestsBanner({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [AppColors.sky, AppColors.lilac]),
            borderRadius: BorderRadius.circular(18),
          ),
          child: Row(
            children: [
              const Text('💌', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$count friend request${count == 1 ? '' : 's'} waiting',
                      style: AppTextStyles.baloo(size: 13, color: Colors.white),
                    ),
                    const SizedBox(height: 1),
                    Text(
                      'Tap to accept or decline',
                      style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                    ),
                  ],
                ),
              ),
              const Text('›', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FriendRow extends StatefulWidget {
  const _FriendRow({
    required this.friend,
    required this.index,
    required this.acked,
    required this.onTap,
    required this.onAckToggle,
    required this.onLongPress,
  });

  final Friend friend;
  final int index;
  final bool acked;
  final VoidCallback onTap;
  final VoidCallback? onAckToggle;
  // Long-press opens the Remove/Block/Report sheet — see
  // FriendsListScreen._openFriendActions.
  final VoidCallback? onLongPress;

  @override
  State<_FriendRow> createState() => _FriendRowState();
}

class _FriendRowState extends State<_FriendRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final f = widget.friend;
    return Semantics(
      button: true,
      label: f.name,
      hint: widget.onLongPress == null ? null : 'Double tap and hold for more options',
      child: GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        transform: Matrix4.translationValues(0, _pressed ? 2 : 0, 0),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          boxShadow: [BoxShadow(color: AppColors.line, offset: Offset(0, _pressed ? 1 : 3))],
          gradient: f.hasMood
              ? LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color.lerp(Colors.white, f.accent, 0.38)!, Color.lerp(Colors.white, f.accent, 0.14)!],
                )
              : null,
          color: f.hasMood ? null : AppColors.paper,
        ),
        child: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                InitialsAvatar(name: f.name, colorIndex: widget.index),
                if (f.hasMood)
                  Positioned(
                    bottom: -2,
                    right: -2,
                    child: Container(
                      width: 20,
                      height: 20,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: AppColors.paper,
                        border: Border.all(color: AppColors.paper, width: 2),
                        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.18), blurRadius: 3, offset: const Offset(0, 1))],
                      ),
                      child: Text(f.emoji!, style: const TextStyle(fontSize: 11)),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(f.name, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  if (f.hasMood) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
                      decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.55), borderRadius: BorderRadius.circular(8)),
                      child: Text(
                        '${f.emoji} ${f.mood}',
                        style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800, color: f.accent),
                      ),
                    ),
                    // Was missing entirely — the friend's custom message
                    // never rendered anywhere, only the mood name/emoji.
                    if (f.message != null && f.message!.trim().isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        f.message!,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.3),
                      ),
                    ],
                    // Was also missing — the "Let friends know" intent
                    // pill (Available to talk / Need space / etc) was
                    // saved on post but MoodifyRepository never
                    // denormalized it anywhere FriendsRepository could
                    // read it, so it silently never reached this list.
                    if (f.intentLabel != null) ...[
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.7),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppColors.line),
                        ),
                        child: Text(
                          f.intentLabel!,
                          style: AppTextStyles.quicksand(size: 10, weight: FontWeight.w700, color: AppColors.inkDim),
                        ),
                      ),
                    ],
                  ] else
                    Text(
                      'No mood shared recently',
                      style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint)
                          .copyWith(fontStyle: FontStyle.italic),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (f.time != null)
                  Text(f.time!, style: AppTextStyles.quicksand(size: 10.5, weight: FontWeight.w700, color: AppColors.inkFaint)),
                if (widget.onAckToggle != null) ...[
                  const SizedBox(height: 7),
                  _AckButton(acked: widget.acked, onTap: widget.onAckToggle!, label: "Mark ${f.name}'s mood as seen"),
                ],
              ],
            ),
          ],
        ),
      ),
      ),
    );
  }
}

class _AckButton extends StatelessWidget {
  const _AckButton({required this.acked, required this.onTap, required this.label});

  final bool acked;
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: label,
      toggled: acked,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          width: 22,
          height: 22,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: acked ? AppColors.mint : Colors.white.withValues(alpha: 0.65),
            border: Border.all(color: acked ? AppColors.mint : AppColors.ink.withValues(alpha: 0.28), width: 1.5),
          ),
          child: Text(
            '✓',
            style: TextStyle(fontSize: 12, height: 1, color: acked ? Colors.white : Colors.transparent),
          ),
        ),
      ),
    );
  }
}

/// The long-press menu for a friend row — Remove friend / Block / Report,
/// each popping its action id back to [FriendsListScreen._openFriendActions].
class _FriendActionsSheet extends StatelessWidget {
  const _FriendActionsSheet({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Container(
        margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(22)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 10, 18, 4),
              child: Text(name, style: AppTextStyles.baloo(size: 13.5, color: AppColors.inkDim)),
            ),
            const Divider(height: 1, color: AppColors.line),
            _ActionTile(emoji: '👋', label: 'Remove friend', onTap: () => Navigator.of(context).pop('remove')),
            _ActionTile(emoji: '🚫', label: 'Block', destructive: true, onTap: () => Navigator.of(context).pop('block')),
            _ActionTile(emoji: '🚩', label: 'Report', destructive: true, onTap: () => Navigator.of(context).pop('report')),
            const Divider(height: 1, color: AppColors.line),
            _ActionTile(emoji: '✕', label: 'Cancel', onTap: () => Navigator.of(context).pop()),
          ],
        ),
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  const _ActionTile({required this.emoji, required this.label, required this.onTap, this.destructive = false});

  final String emoji;
  final String label;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        child: Row(
          children: [
            SizedBox(width: 22, child: Text(emoji, style: const TextStyle(fontSize: 16))),
            const SizedBox(width: 12),
            Text(
              label,
              style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700, color: destructive ? AppColors.coral : AppColors.ink),
            ),
          ],
        ),
      ),
    );
  }
}

/// Reason picker + optional details for filing a report — pops
/// `{'reason': ..., 'details': ...}` back to
/// [FriendsListScreen._reportFriend], or `null` if cancelled.
class _ReportSheet extends StatefulWidget {
  const _ReportSheet({required this.name});

  final String name;

  @override
  State<_ReportSheet> createState() => _ReportSheetState();
}

class _ReportSheetState extends State<_ReportSheet> {
  String? _reason;
  final _detailsController = TextEditingController();

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: SafeArea(
        child: Container(
          margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
          decoration: BoxDecoration(color: AppColors.paper, borderRadius: BorderRadius.circular(22)),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Report ${widget.name}', style: AppTextStyles.baloo(size: 16)),
              const SizedBox(height: 4),
              Text(
                "This is sent privately to our team — ${widget.name} won't be notified.",
                style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: kReportReasons.map((r) {
                  final selected = r == _reason;
                  return GestureDetector(
                    onTap: () => setState(() => _reason = r),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 150),
                      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
                      decoration: BoxDecoration(
                        color: selected ? AppColors.coral : AppColors.paperSoft,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        r,
                        style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: selected ? Colors.white : AppColors.inkDim),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _detailsController,
                maxLines: 3,
                minLines: 2,
                style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600),
                decoration: InputDecoration(
                  hintText: 'Anything else we should know? (optional)',
                  hintStyle: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkFaint),
                  filled: true,
                  fillColor: AppColors.paperSoft,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: AppColors.paperSoft,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text('Cancel', style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextButton(
                      style: TextButton.styleFrom(
                        backgroundColor: _reason == null ? AppColors.paperSoft : AppColors.coral,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                      ),
                      onPressed: _reason == null
                          ? null
                          : () => Navigator.of(context).pop({'reason': _reason!, 'details': _detailsController.text}),
                      child: Text(
                        'Submit',
                        style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w800, color: _reason == null ? AppColors.inkFaint : Colors.white),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}