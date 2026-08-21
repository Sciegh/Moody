import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/app_tab_bar.dart';
import '../../core/widgets/initials_avatar.dart';
import '../../core/widgets/search_field.dart';
import '../../models/friend.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/friends_repository.dart';

/// Migration of add-friend.html.
class AddFriendScreen extends ConsumerStatefulWidget {
  const AddFriendScreen({super.key});

  @override
  ConsumerState<AddFriendScreen> createState() => _AddFriendScreenState();
}

class _AddFriendScreenState extends ConsumerState<AddFriendScreen> {
  final _searchController = TextEditingController();
  String _filter = '';
  String _copyLabel = 'Copy';

  // "People you may know" is fetched once per search term rather than
  // streamed — see FriendsRepository.fetchSuggestions doc comment.
  List<FriendSuggestion> _suggestions = const [];
  bool _loadingSuggestions = true;
  final Set<String> _added = {};

  @override
  void initState() {
    super.initState();
    _loadSuggestions();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadSuggestions() async {
    final uid = ref.read(authServiceProvider).currentUserId;
    if (uid == null) return;
    setState(() => _loadingSuggestions = true);
    final results = await ref.read(friendsRepositoryProvider).fetchSuggestions(uid, search: _filter);
    if (!mounted) return;
    setState(() {
      _suggestions = results;
      _loadingSuggestions = false;
    });
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(const ClipboardData(text: 'https://moodify.app/invite/sciegh'));
    setState(() => _copyLabel = 'Copied!');
    await Future.delayed(const Duration(milliseconds: 1500));
    if (mounted) setState(() => _copyLabel = 'Copy');
  }

  Future<void> _acceptRequest(String uid, FriendRequest request) async {
    await ref.read(friendsRepositoryProvider).acceptRequest(uid: uid, friendUid: request.fromUid);
  }

  Future<void> _declineRequest(String uid, FriendRequest request) async {
    await ref.read(friendsRepositoryProvider).declineRequest(uid: uid, friendUid: request.fromUid);
  }

  Future<void> _addSuggestion(String uid, FriendSuggestion suggestion) async {
    setState(() => _added.add(suggestion.uid));
    await ref.read(friendsRepositoryProvider).sendFriendRequest(fromUid: uid, toUid: suggestion.uid);
  }

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authServiceProvider).currentUserId;
    final requests = uid == null ? const <FriendRequest>[] : ref.watch(incomingRequestsStreamProvider(uid)).valueOrNull ?? const [];

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Add friends', style: AppTextStyles.baloo(size: 22)),
                          const SizedBox(height: 3),
                          Text(
                            "Find people to share your moods with 🌤️",
                            style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim),
                          ),
                        ],
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Back to friends list',
                      child: GestureDetector(
                        onTap: () => context.go('/friends'),
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                            color: AppColors.paper,
                            boxShadow: [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
                          ),
                          child: const Icon(Icons.arrow_back, color: Colors.black, size: 16),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchField(
                        controller: _searchController,
                        placeholder: 'Search by name or username',
                        onChanged: (v) {
                          setState(() => _filter = v);
                          _loadSuggestions();
                        },
                      ),
                      const SizedBox(height: 16),

                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [AppColors.sky, AppColors.lilac]),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Text('💌', style: TextStyle(fontSize: 26)),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text('Invite by link', style: AppTextStyles.baloo(size: 14.5, color: Colors.white)),
                                  const SizedBox(height: 2),
                                  Text(
                                    "Share Moodify with friends who aren't here yet",
                                    style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w600, color: Colors.white.withValues(alpha: 0.9)),
                                  ),
                                ],
                              ),
                            ),
                            TextButton(
                              style: TextButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                              ),
                              onPressed: _copyLink,
                              child: Text(_copyLabel, style: AppTextStyles.baloo(size: 12.5, color: AppColors.lilac)),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      if (requests.isNotEmpty && uid != null) ...[
                        Text('Friend requests', style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim)),
                        const SizedBox(height: 10),
                        ...requests.asMap().entries.map((entry) {
                          final i = entry.key;
                          final request = entry.value;
                          return _RequestRow(
                            name: request.name,
                            colorIndex: i,
                            onAccept: () => _acceptRequest(uid, request),
                            onDecline: () => _declineRequest(uid, request),
                          );
                        }),
                        const SizedBox(height: 16),
                      ],

                      Text(
                        'People you may know',
                        style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim),
                      ),
                      const SizedBox(height: 10),
                      if (_loadingSuggestions)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 30),
                          child: Center(child: CircularProgressIndicator()),
                        )
                      else if (_suggestions.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Center(
                            child: Text(
                              'No one matches that search 🫥',
                              style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkFaint),
                            ),
                          ),
                        )
                      else
                        ..._suggestions.asMap().entries.map((entry) {
                          final i = entry.key;
                          final suggestion = entry.value;
                          return _SuggestionRow(
                            name: suggestion.name,
                            colorIndex: i + 2, // matches source's `avatarStyle(i+2)`
                            added: _added.contains(suggestion.uid),
                            onAdd: uid == null ? null : () => _addSuggestion(uid, suggestion),
                          );
                        }),
                    ],
                  ),
                ),
              ),
              const AppTabBar(active: AppTab.friends, accent: AppColors.lilac),
            ],
          ),
        )
    );
  }
}

class _RequestRow extends StatelessWidget {
  const _RequestRow({required this.name, required this.colorIndex, required this.onAccept, required this.onDecline});

  final String name;
  final int colorIndex;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          InitialsAvatar(name: name, colorIndex: colorIndex, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                Text('wants to be friends', style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: AppColors.inkFaint)),
              ],
            ),
          ),
          Row(
            children: [
              _MiniButton(label: 'Accept', background: AppColors.mint, shadow: const Color(0xFF26AD7C), onTap: onAccept),
              const SizedBox(width: 6),
              _MiniButton(
                label: 'Decline',
                background: AppColors.paperSoft,
                textColor: AppColors.inkDim,
                shadow: AppColors.line,
                onTap: onDecline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.name, required this.colorIndex, required this.added, required this.onAdd});

  final String name;
  final int colorIndex;
  final bool added;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      child: Row(
        children: [
          InitialsAvatar(name: name, colorIndex: colorIndex, size: 42),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w700)),
                Text('Suggested for you', style: AppTextStyles.quicksand(size: 11, weight: FontWeight.w600, color: AppColors.inkFaint)),
              ],
            ),
          ),
          added
              ? const _MiniButton(label: 'Added ✓', background: AppColors.paperSoft, textColor: AppColors.mint, shadow: AppColors.line, onTap: null)
              : _MiniButton(label: 'Add', background: AppColors.coral, shadow: AppColors.coralDark, onTap: onAdd),
        ],
      ),
    );
  }
}

class _MiniButton extends StatelessWidget {
  const _MiniButton({
    required this.label,
    required this.background,
    required this.shadow,
    required this.onTap,
    this.textColor = Colors.white,
  });

  final String label;
  final Color background;
  final Color shadow;
  final Color textColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: shadow, offset: const Offset(0, 3))],
        ),
        child: Text(label, style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: textColor)),
      ),
    );
  }
}