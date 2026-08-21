import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/mood_accent_provider.dart';
import '../../models/mood_entry.dart';

/// Milestone thresholds the streak sheet's progress bar climbs toward.
/// Product-defined, not user data, so there's nothing to fetch from
/// Firestore for this one.
const kStreakMilestones = [3, 7, 14, 21, 30, 60, 100];

const _weekDayLabels = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

/// Turns [ProfileRepository.watchLast7DaysActivity]'s oldest-first
/// booleans into the [WeekDay]s the streak sheet renders — real Firestore
/// activity in place of the old all-true `kMockWeek` list. `activity`
/// must have exactly 7 entries, oldest first, today last.
List<WeekDay> buildWeek(List<bool> activity) {
  final today = DateTime.now().weekday % 7; // DateTime.weekday: Mon=1..Sun=7
  return List<WeekDay>.generate(7, (i) {
    final dayOfWeek = (today - (6 - i)) % 7;
    final label = _weekDayLabels[(dayOfWeek + 7) % 7];
    return _WeekDay(label, filled: activity[i], today: i == 6);
  });
}

class _WeekDay {
  const _WeekDay(this.label, {required this.filled, this.today = false});
  final String label;
  final bool filled;
  final bool today;
}

typedef WeekDay = _WeekDay;

String flameForStreak(int n) {
  if (n >= 30) return '🔥🔥🔥';
  if (n >= 14) return '🔥🔥';
  if (n >= 3) return '🔥';
  return '✨';
}

int nextMilestone(int n) {
  for (final m in kStreakMilestones) {
    if (m > n) return m;
  }
  return ((n + 1) / 50).ceil() * 50;
}

int prevMilestone(int n) {
  final passed = kStreakMilestones.where((m) => m <= n).toList();
  return passed.isEmpty ? 0 : passed.last;
}

/// Now just the Profile screen's own local UI state (the streak-sheet
/// modal). The accent/mood color used to live here too, but it's been
/// promoted to [moodAccentProvider] — see that file's doc comment — since
/// it needs to be readable app-wide, not just on Profile. Read
/// `ref.watch(moodAccentProvider)` directly for the current accent, and
/// `ref.read(moodAccentProvider.notifier).selectMoodAccent(mood)` to
/// change it (e.g. from [MoodChipStrip]'s onTap).
class ProfileState {
  const ProfileState({this.streakSheetOpen = false});

  final bool streakSheetOpen;

  ProfileState copyWith({bool? streakSheetOpen}) => ProfileState(
        streakSheetOpen: streakSheetOpen ?? this.streakSheetOpen,
      );
}

class ProfileController extends StateNotifier<ProfileState> {
  ProfileController(this._ref) : super(const ProfileState());

  final Ref _ref;

  /// Kept here (delegating to the shared provider) so existing call sites
  /// like `MoodChipStrip.onTap` don't need to know the accent moved.
  void selectMoodAccent(MoodEntry mood) {
    _ref.read(moodAccentProvider.notifier).selectMoodAccent(mood);
  }

  void openStreakSheet() => state = state.copyWith(streakSheetOpen: true);
  void closeStreakSheet() => state = state.copyWith(streakSheetOpen: false);
}

final profileControllerProvider = StateNotifierProvider<ProfileController, ProfileState>(
  (ref) => ProfileController(ref),
);