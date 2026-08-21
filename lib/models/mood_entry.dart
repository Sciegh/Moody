import 'package:flutter/material.dart';

/// One entry in the "Recent moods" strip on Profile.
/// Mirrors the `RECENT` array literal in Profile.html's inline `<script>`.
@immutable
class MoodEntry {
  const MoodEntry({
    required this.emoji,
    required this.date,
    required this.accent,
    required this.accentLight,
    this.label,
    this.id,
    this.moodifyId,
  });

  final String emoji;

  /// When the mood was logged. Was previously a hardcoded display string
  /// (e.g. 'Today', 'Wed') that never changed after being set, so the
  /// "Recent moods" strip and the "Feeling X today." status line silently
  /// went stale the moment a day passed — an entry logged "Today" would
  /// still say "Today" a week later. Storing the actual DateTime and
  /// deriving the label at render time (see [formatMoodDay]) fixes that.
  final DateTime date;

  final Color accent;
  final Color accentLight;

  /// The mood's display name (e.g. "Peaceful") — was missing entirely, so
  /// Profile's "Recent moods" strip only ever showed an emoji and a day,
  /// with no way to tell which mood it actually was. See
  /// ProfileRepository.watchRecentMoods and MoodifyRepository.post's
  /// `label` field.
  final String? label;

  /// This entry's own `users/{uid}/moods/{id}` document id — null for the
  /// mock data below. Needed (along with [moodifyId]) so
  /// MoodifyRepository.deleteMoodify() knows exactly which docs to
  /// remove; without it, "delete this moodify" had nothing to delete.
  final String? id;

  /// The matching `moodifies/{moodifyId}` feed document — the actual
  /// post friends see. Deleting a moodify removes both this and the
  /// history entry above, so it disappears from the profile strip *and*
  /// friends' feeds at the same time, not just one or the other.
  final String? moodifyId;
}

const _kWeekdayAbbr = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Derives the chip's day label from an actual [date] instead of trusting
/// a stored string, so "Today" correctly becomes "Yest." and then a
/// weekday abbreviation as real time passes. Mirrors [_formatJoined] in
/// profile_screen.dart in spirit: compute display text from real data at
/// call time rather than persisting a display string.
String formatMoodDay(DateTime date) {
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final entryDay = DateTime(date.year, date.month, date.day);
  final diffDays = today.difference(entryDay).inDays;
  if (diffDays == 0) return 'Today';
  if (diffDays == 1) return 'Yest.';
  // Beyond a week old, this still returns a weekday abbreviation rather
  // than a date — matches the original 7-entry strip's design, which only
  // ever shows the last 7 days.
  return _kWeekdayAbbr[date.weekday - 1];
}

/// TODO(firebase): this is the same mocked list from the source `<script>`
/// (`const RECENT = [...]`). Replace with the user's actual last-7-days
/// mood history from Firestore once that's wired up.
///
/// Was a `const` list of hardcoded day strings — now built from
/// `DateTime.now()` offsets so the mock data itself stays correct no
/// matter when the app is run (can no longer be `const` since
/// `DateTime.now()` isn't a compile-time constant).
final kMockRecentMoods = <MoodEntry>[
  MoodEntry(emoji: '🤩', date: DateTime.now(), label: 'Excited', accent: const Color(0xFFFF8A5B), accentLight: const Color(0xFFFFC79E)),
  MoodEntry(emoji: '😌', date: DateTime.now().subtract(const Duration(days: 1)), label: 'Chill', accent: const Color(0xFF6FA8DC), accentLight: const Color(0xFFB9D8F2)),
  MoodEntry(emoji: '🥰', date: DateTime.now().subtract(const Duration(days: 2)), label: 'Loved', accent: const Color(0xFFF25C78), accentLight: const Color(0xFFFAB6C4)),
  MoodEntry(emoji: '🔥', date: DateTime.now().subtract(const Duration(days: 3)), label: 'Motivated', accent: const Color(0xFFF4845F), accentLight: const Color(0xFFFAC3AD)),
  MoodEntry(emoji: '😴', date: DateTime.now().subtract(const Duration(days: 4)), label: 'Sleepy', accent: const Color(0xFF8E97C9), accentLight: const Color(0xFFCBD0E9)),
  MoodEntry(emoji: '🙂', date: DateTime.now().subtract(const Duration(days: 5)), label: 'Content', accent: const Color(0xFF9BC49A), accentLight: const Color(0xFFD2E8D1)),
  MoodEntry(emoji: '🎉', date: DateTime.now().subtract(const Duration(days: 6)), label: 'Celebratory', accent: const Color(0xFFC77DFF), accentLight: const Color(0xFFE6C4FF)),
];