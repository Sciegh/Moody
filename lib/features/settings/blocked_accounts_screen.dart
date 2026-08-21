import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/detail_top_bar.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/save_toast.dart';
import '../../models/friend.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/friends_repository.dart';

/// Lists accounts the current user has blocked, with an Unblock action on
/// each. Reached from Privacy → Blocked accounts, which used to link to
/// add-friend.html with a hardcoded "2" badge — there was no real block
/// feature anywhere in the app for this screen to show. See
/// FriendsRepository.watchBlockedUsers/blockUser/unblockUser and
/// FriendsListScreen's long-press menu, which is where a block gets
/// created.
class BlockedAccountsScreen extends ConsumerStatefulWidget {
  const BlockedAccountsScreen({super.key});

  @override
  ConsumerState<BlockedAccountsScreen> createState() => _BlockedAccountsScreenState();
}

class _BlockedAccountsScreenState extends ConsumerState<BlockedAccountsScreen> {
  final _toast = SaveToastController();

  @override
  void dispose() {
    _toast.dispose();
    super.dispose();
  }

  Future<void> _confirmUnblock(String uid, BlockedUser b) async {
    final confirmed = await showCuteWarning(
      context,
      emoji: '🔓',
      title: 'Unblock ${b.name}?',
      message: 'They\'ll be able to find and friend you again. This does not restore your previous friendship automatically.',
      dismissLabel: 'Cancel',
      confirmLabel: 'Unblock',
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendsRepositoryProvider).unblockUser(uid: uid, blockedUid: b.uid);
      if (!mounted) return;
      _toast.show('${b.name} has been unblocked');
    } catch (_) {
      if (!mounted) return;
      _toast.show("Couldn't unblock ${b.name} — check your connection and try again");
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authServiceProvider).currentUserId;
    final blocked = uid == null ? const <BlockedUser>[] : ref.watch(blockedUsersStreamProvider(uid)).valueOrNull ?? const <BlockedUser>[];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              children: [
                DetailTopBar(title: 'Blocked accounts', onBack: () => context.go('/privacy')),
                Expanded(
                  child: blocked.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 40),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Text('🚫', style: TextStyle(fontSize: 34)),
                                const SizedBox(height: 10),
                                Text(
                                  "You haven't blocked anyone.",
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkFaint),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Long-press a friend from your Friends list to block or report them.',
                                  textAlign: TextAlign.center,
                                  style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint, height: 1.4),
                                ),
                              ],
                            ),
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: blocked
                                .asMap()
                                .entries
                                .map((entry) => _BlockedRow(
                                      blocked: entry.value,
                                      index: entry.key,
                                      onUnblock: uid == null ? null : () => _confirmUnblock(uid, entry.value),
                                    ))
                                .toList(),
                          ),
                        ),
                ),
              ],
            ),
            SaveToast(controller: _toast),
          ],
        ),
      ),
    );
  }
}

class _BlockedRow extends StatelessWidget {
  const _BlockedRow({required this.blocked, required this.index, required this.onUnblock});

  final BlockedUser blocked;
  final int index;
  final VoidCallback? onUnblock;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          InitialsAvatar(name: blocked.name, colorIndex: index),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(blocked.name, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                if (blocked.handle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(blocked.handle, style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: AppColors.inkFaint)),
                ],
              ],
            ),
          ),
          if (onUnblock != null)
            TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.paperSoft,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              onPressed: onUnblock,
              child: Text('Unblock', style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: AppColors.inkDim)),
            ),
        ],
      ),
    );
  }
}
