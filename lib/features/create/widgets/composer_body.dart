import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_theme.dart';
import '../../../models/mood_option.dart';

/// `#composer` — the desc card + suggested-message chips + textarea, shown
/// once a mood is selected.
class ComposerBody extends StatelessWidget {
  const ComposerBody({
    super.key,
    required this.mood,
    required this.messageController,
    required this.onMessageChanged,
    required this.onSuggestionTap,
  });

  final MoodOption mood;
  final TextEditingController messageController;
  final VoidCallback onMessageChanged;
  final ValueChanged<String> onSuggestionTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(color: AppColors.paperSoft, borderRadius: BorderRadius.circular(20)),
          child: Text(
            mood.desc,
            style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w600, color: AppColors.inkDim, height: 1.5),
          ),
        ),

        Text('Add a message', style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim)),
        const SizedBox(height: 10),
        SizedBox(
          height: 52,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: mood.messages.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (context, i) {
              final msg = mood.messages[i];
              return GestureDetector(
                onTap: () => onSuggestionTap(msg),
                child: Container(
                  constraints: const BoxConstraints(maxWidth: 230),
                  padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
                  decoration: BoxDecoration(
                    color: AppColors.paper,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: const [BoxShadow(color: AppColors.line, offset: Offset(0, 3))],
                  ),
                  alignment: Alignment.centerLeft,
                  child: Text(
                    msg,
                    style: AppTextStyles.quicksand(size: 12.5, weight: FontWeight.w600, height: 1.35),
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 10),

        Stack(
          children: [
            TextField(
              controller: messageController,
              onChanged: (_) => onMessageChanged(),
              maxLength: 140,
              maxLines: null,
              minLines: 3,
              buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
              style: AppTextStyles.quicksand(size: 14, weight: FontWeight.w600),
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.paper,
                hintText: 'Write your own…',
                hintStyle: AppTextStyles.quicksand(size: 14, weight: FontWeight.w600, color: AppColors.inkFaint),
                contentPadding: const EdgeInsets.fromLTRB(14, 12, 14, 22),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 8,
              child: Text(
                '${messageController.text.length} / 140',
                style: AppTextStyles.quicksand(size: 10.5, weight: FontWeight.w700, color: AppColors.inkFaint),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Text(
          'Let friends know (optional)',
          style: AppTextStyles.baloo(size: 13.5, weight: FontWeight.w700, color: AppColors.inkDim),
        ),
        const SizedBox(height: 10),
      ],
    );
  }
}

/// `.pill-row` / `.pill` — the optional-intent chips ("Available to talk", etc).
class IntentPillRow extends StatelessWidget {
  const IntentPillRow({super.key, required this.mood, required this.selectedIntent, required this.onSelect});

  final MoodOption mood;
  final String? selectedIntent;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: kIntents.map((intent) {
        final selected = selectedIntent == intent.id;
        return GestureDetector(
          onTap: () => onSelect(intent.id),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? mood.accent : AppColors.paper,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: selected ? Color.lerp(mood.accent, Colors.black, 0.4)! : AppColors.line, offset: const Offset(0, 3))],
            ),
            child: Text(
              intent.label,
              style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: selected ? mood.onAccent : AppColors.inkDim),
            ),
          ),
        );
      }).toList(),
    );
  }
}
