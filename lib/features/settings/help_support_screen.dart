import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/detail_top_bar.dart';
import '../../core/widgets/search_field.dart';

class _Faq {
  const _Faq(this.question, this.answer);
  final String question;
  final String answer;
}

const _kFaqs = <_Faq>[
  _Faq(
    'How long does a moodify stay visible?',
    "Every moodify you post fades from friends' feeds automatically after 24 hours, keeping things fresh and in the moment.",
  ),
  _Faq(
    'Who can see what I post?',
    'By default only your accepted friends can see your moodifies. You can make your account fully private from the Privacy settings page.',
  ),
  _Faq(
    'How do streaks work?',
    'Post at least one moodify a day to keep your streak going. Missing a day resets your streak count back to zero.',
  ),
  _Faq(
    'Can I delete a moodify after posting?',
    "Yes — go to your profile, press and hold the mood chip in your Recent moods strip, then tap the trash icon. It's removed from your profile and from everyone's feed right away.",
  ),
  _Faq(
    'How do I change my password?',
    'Head to Profile → Account details, enter a new password, and tap Save changes.',
  ),
  _Faq(
    'How do I unfriend someone?',
    "Go to your Friends list, then press and hold that friend's row. Choose Remove friend from the menu that pops up. You can always send them a new friend request later if you change your mind.",
  ),
  _Faq(
    'How do I report or block someone?',
    "Go to your Friends list, press and hold their row, then choose Block or Report from the menu. Blocking also ends the friendship, and reports go straight to our team — the person won't be notified. Blocked accounts can be managed (and unblocked) from Privacy settings.",
  ),
];

/// Migration of help-support.html.
class HelpSupportScreen extends StatefulWidget {
  const HelpSupportScreen({super.key});

  @override
  State<HelpSupportScreen> createState() => _HelpSupportScreenState();
}

class _HelpSupportScreenState extends State<HelpSupportScreen> {
  final _searchController = TextEditingController();
  String _filter = '';
  int? _openIndex;
  bool _statusChecked = false;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<_Faq> get _matches {
    final f = _filter.trim().toLowerCase();
    if (f.isEmpty) return _kFaqs;
    return _kFaqs.where((item) => item.question.toLowerCase().contains(f) || item.answer.toLowerCase().contains(f)).toList();
  }

  Future<void> _emailUs() async {
    final uri = Uri.parse('mailto:support@moodify.app');
    // TODO: url_launcher requires platform config (see pubspec/config notes);
    // falls back silently if it can't launch in this environment.
    if (await canLaunchUrl(uri)) await launchUrl(uri);
  }

  void _liveChat() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        content: const Text('Live chat would open here.'),
        actions: [TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('OK'))],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Column(
            children: [
              DetailTopBar(title: 'Help & support', onBack: () => context.go('/profile')),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AppSearchField(
                        controller: _searchController,
                        placeholder: 'Search help articles',
                        onChanged: (v) => setState(() => _filter = v),
                      ),
                      const SizedBox(height: 16),

                      Row(
                        children: [
                          Expanded(child: _ContactCard(emoji: '📧', label: 'Email us', onTap: _emailUs)),
                          const SizedBox(width: 10),
                          Expanded(child: _ContactCard(emoji: '💬', label: 'Live chat', onTap: _liveChat)),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _ContactCard(
                              emoji: '📶',
                              label: 'System status',
                              onTap: _statusChecked ? null : () => setState(() => _statusChecked = true),
                            ),
                          ),
                        ],
                      ),
                      if (_statusChecked)
                        Container(
                          margin: const EdgeInsets.only(top: 10),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                          decoration: BoxDecoration(color: AppColors.paperSoft, borderRadius: BorderRadius.circular(16)),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text('✅', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'All Moodify systems are operational. No incidents reported.',
                                  style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 10),

                      Text('Frequently asked', style: AppTextStyles.baloo(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
                      const SizedBox(height: 10),

                      if (_matches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 24),
                          child: Center(
                            child: Text(
                              'No help articles match that search 🫥',
                              style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkFaint),
                            ),
                          ),
                        )
                      else
                        ..._matches.asMap().entries.map((entry) {
                          final i = entry.key;
                          final faq = entry.value;
                          return _FaqItem(
                            faq: faq,
                            open: _openIndex == i,
                            onTap: () => setState(() => _openIndex = _openIndex == i ? null : i),
                          );
                        }),
                    ],
                  ),
                ),
              ),
            ],
          ),
        )
    );
  }
}

class _ContactCard extends StatelessWidget {
  const _ContactCard({required this.emoji, required this.label, required this.onTap});

  final String emoji;
  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        decoration: BoxDecoration(
          color: AppColors.paper,
          borderRadius: BorderRadius.circular(18),
          boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
        ),
        child: Opacity(
          opacity: onTap == null ? 0.5 : 1,
          child: Column(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 22)),
              const SizedBox(height: 6),
              Text(label, textAlign: TextAlign.center, style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _FaqItem extends StatelessWidget {
  const _FaqItem({required this.faq, required this.open, required this.onTap});

  final _Faq faq;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.paper,
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Expanded(
                    child: Text(faq.question, style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w700)),
                  ),
                  const SizedBox(width: 10),
                  AnimatedRotation(
                    duration: const Duration(milliseconds: 250),
                    turns: open ? 0.125 : 0, // +45deg
                    child: const Text('+', style: TextStyle(fontSize: 16, color: AppColors.marigold, fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
            ),
          ),
          AnimatedCrossFade(
            duration: const Duration(milliseconds: 250),
            crossFadeState: open ? CrossFadeState.showFirst : CrossFadeState.showSecond,
            firstChild: Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
              child: Text(
                faq.answer,
                style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
              ),
            ),
            secondChild: const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}