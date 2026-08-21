import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../core/widgets/initials_avatar.dart';
import '../../../models/friend.dart';
import '../create_controller.dart';

/// `#sheetScrim` / `.sheet` — "Who sees this Moodify?"
class AudienceSheet extends StatelessWidget {
  const AudienceSheet({
    super.key,
    required this.mode,
    required this.search,
    required this.selectedFriends,
    required this.friends,
    required this.onModeChanged,
    required this.onSearchChanged,
    required this.onFriendToggle,
    required this.onSave,
  });

  final AudienceMode mode;
  final String search;

  /// uids of the friends currently selected under [AudienceMode.select].
  final Set<String> selectedFriends;

  /// Real friends list — backed by `friendsStreamProvider`, replacing the
  /// old hardcoded `kComposerFriends` name list.
  final List<Friend> friends;

  final ValueChanged<AudienceMode> onModeChanged;
  final ValueChanged<String> onSearchChanged;

  /// Called with a friend's uid.
  final ValueChanged<String> onFriendToggle;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final term = search.trim().toLowerCase();
    final matches = term.isEmpty
        ? friends
        : friends.where((f) => f.name.toLowerCase().contains(term) || f.handle.toLowerCase().contains(term)).toList();
    final showFriendControls = mode == AudienceMode.select;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 10, 20, 20 + MediaQuery.of(context).padding.bottom),
      constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.72),
      decoration: const BoxDecoration(
        color: AppColors.bg1,
        borderRadius: BorderRadius.only(topLeft: Radius.circular(30), topRight: Radius.circular(30)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 5,
            margin: const EdgeInsets.only(bottom: 14),
            decoration: BoxDecoration(color: AppColors.line, borderRadius: BorderRadius.circular(3)),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Text('Who sees this Moodify?', style: AppTextStyles.baloo(size: 17)),
          ),
          const SizedBox(height: 12),

          _RadioOption(
            label: 'All friends (${friends.length})',
            selected: mode == AudienceMode.all,
            onTap: () => onModeChanged(AudienceMode.all),
          ),
          const SizedBox(height: 8),
          _RadioOption(
            label: 'Select friends',
            selected: mode == AudienceMode.select,
            onTap: () => onModeChanged(AudienceMode.select),
          ),

          if (showFriendControls) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.paper,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
              ),
              child: TextField(
                onChanged: onSearchChanged,
                style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  isCollapsed: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                  hintText: 'Search friends',
                  hintStyle: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkFaint),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Flexible(
              child: matches.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      child: Text(
                        'No friends match that search.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkFaint),
                      ),
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: matches.length,
                      itemBuilder: (context, i) {
                        final friend = matches[i];
                        final checked = selectedFriends.contains(friend.uid);
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () => onFriendToggle(friend.uid),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 4),
                            child: Row(
                              children: [
                                InitialsAvatar(name: friend.name, colorIndex: i, size: 34),
                                const SizedBox(width: 10),
                                Expanded(child: Text(friend.name, style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600))),
                                Checkbox(
                                  value: checked,
                                  onChanged: (_) => onFriendToggle(friend.uid),
                                  activeColor: AppColors.coral,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],

          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: TextButton(
              style: TextButton.styleFrom(
                backgroundColor: AppColors.coral,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
              ),
              onPressed: onSave,
              child: Text('Save', style: AppTextStyles.baloo(size: 15, color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }
}

class _RadioOption extends StatelessWidget {
  const _RadioOption({required this.label, required this.selected, required this.onTap});
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(14),
          boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
        ),
        child: Row(
          children: [
            Radio<bool>(value: true, groupValue: selected ? true : null, onChanged: (_) => onTap(), activeColor: AppColors.coral),
            Expanded(child: Text(label, style: AppTextStyles.quicksand(size: 13.5, weight: FontWeight.w600))),
          ],
        ),
      ),
    );
  }
}