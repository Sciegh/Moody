import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/detail_top_bar.dart';
import '../../core/widgets/link_row.dart';
import '../../core/widgets/save_toast.dart';
import '../../core/widgets/toggle_setting_row.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/friends_repository.dart';

/// Migration of Privacy.html.
class PrivacyScreen extends ConsumerStatefulWidget {
  const PrivacyScreen({super.key});

  @override
  ConsumerState<PrivacyScreen> createState() => _PrivacyScreenState();
}

class _PrivacyScreenState extends ConsumerState<PrivacyScreen> {
  bool _privateAccount = true;
  bool _historyVisibility = false;
  bool _discoverable = true;
  bool _shareLocation = false;
  bool _personalizedInsights = true;

  final _toast = SaveToastController();
  String _downloadLabel = 'Download my data';

  @override
  void dispose() {
    _toast.dispose();
    super.dispose();
  }

  void _flashSaved() => _toast.show('Saved ✓');

  Future<void> _downloadData() async {
    setState(() => _downloadLabel = "We'll email your export soon");
    await Future.delayed(const Duration(milliseconds: 2200));
    if (mounted) setState(() => _downloadLabel = 'Download my data');
  }

  void _openPolicy() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text("Moodify's full Privacy Policy would open here."),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Text(text, style: AppTextStyles.baloo(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
      );

  @override
  Widget build(BuildContext context) {
    final uid = ref.watch(authServiceProvider).currentUserId;
    // Was a hardcoded '2' with no feature behind it at all — now the real
    // count from FriendsRepository.watchBlockedUsers(), and null (no
    // badge) once there's actually nothing blocked.
    final blockedCount = uid == null ? 0 : ref.watch(blockedCountStreamProvider(uid)).valueOrNull ?? 0;
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  DetailTopBar(title: 'Privacy', onBack: () => context.go('/profile')),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Control who sees your moods and how your data is used.',
                            style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
                          ),
                          const SizedBox(height: 4),
                          _sectionTitle('Account'),
                          ToggleSettingRow(
                            emoji: '🔐',
                            title: 'Private account',
                            subtitle: 'Only approved friends can see your moodifies',
                            value: _privateAccount,
                            activeColor: AppColors.lilac,
                            onChanged: (v) => setState(() {
                              _privateAccount = v;
                              _flashSaved();
                            }),
                          ),
                          ToggleSettingRow(
                            emoji: '🕰️',
                            title: 'Mood history visibility',
                            subtitle: 'Let friends scroll back past your last 24h',
                            value: _historyVisibility,
                            activeColor: AppColors.lilac,
                            onChanged: (v) => setState(() {
                              _historyVisibility = v;
                              _flashSaved();
                            }),
                          ),
                          ToggleSettingRow(
                            emoji: '🔎',
                            title: 'Discoverable by search',
                            subtitle: 'Appear in "people you may know"',
                            value: _discoverable,
                            activeColor: AppColors.lilac,
                            onChanged: (v) => setState(() {
                              _discoverable = v;
                              _flashSaved();
                            }),
                          ),
                          _sectionTitle('Location'),
                          ToggleSettingRow(
                            emoji: '📍',
                            title: 'Share general location',
                            subtitle: 'Shown as your city, never exact address',
                            value: _shareLocation,
                            activeColor: AppColors.lilac,
                            onChanged: (v) => setState(() {
                              _shareLocation = v;
                              _flashSaved();
                            }),
                          ),
                          _sectionTitle('Data'),
                          ToggleSettingRow(
                            emoji: '📊',
                            title: 'Personalized insights',
                            subtitle: 'Use your mood data for trends & suggestions',
                            value: _personalizedInsights,
                            activeColor: AppColors.lilac,
                            onChanged: (v) => setState(() {
                              _personalizedInsights = v;
                              _flashSaved();
                            }),
                          ),
                          LinkRow(emoji: '⬇️', label: _downloadLabel, onTap: _downloadData),
                          LinkRow(
                            emoji: '🚫',
                            label: 'Blocked accounts',
                            badge: blockedCount > 0 ? '$blockedCount' : null,
                            badgeColor: AppColors.lilac,
                            onTap: () => context.go('/blocked-accounts'),
                          ),
                          const SizedBox(height: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: AppColors.paperSoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: RichText(
                              text: TextSpan(
                                style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
                                children: [
                                  const TextSpan(text: 'Read the full '),
                                  TextSpan(
                                    text: 'Privacy Policy',
                                    style: const TextStyle(
                                      color: AppColors.lilacDark,
                                      fontWeight: FontWeight.w800,
                                      decoration: TextDecoration.underline,
                                    ),
                                    recognizer: (TapGestureRecognizer()..onTap = _openPolicy),
                                  ),
                                  const TextSpan(text: ' for details on how Moodify collects and uses your information.'),
                                ],
                              ),
                            ),
                          ),
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