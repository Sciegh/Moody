import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/mood_entry.dart';
import '../theme/app_colors.dart';

/// The accent pair driving the app-wide "mood background" — Flutter's
/// equivalent of the source script rewriting `--accent`/`--accent-light`
/// on `documentElement` when a mood is logged.
///
/// This used to live inside `ProfileController` and only affect the
/// Profile screen's own background. It's promoted to its own top-level
/// provider so that (a) it's the single source of truth for "the user's
/// current mood," or the app in general, and reachable from
/// anywhere (Friends, Settings, etc.) — a screen shouldn't need to know
/// about `ProfileController` just to read the mood colors it's grouped
/// under — and (b) a single [MoodBackground] can be mounted once above
/// the whole authenticated app (see `app_router.dart`'s `ShellRoute`)
/// and just watch this provider, instead of every screen re-declaring
/// its own copy of the gradient.
@immutable
class ProfileAccent {
  const ProfileAccent({required this.accent, required this.accentLight});
  final Color accent;
  final Color accentLight;
}

/// Default accent (`--accent:#FF6F91; --accent-light:#FFC1D2` from the
/// `:root` block) — used before any mood has been loaded.
const kDefaultProfileAccent = ProfileAccent(
  accent: AppColors.coral,
  accentLight: AppColors.accentLightDefault,
);

class MoodAccentController extends StateNotifier<ProfileAccent> {
  // Starts on the static `:root` default and nothing else — no uid is
  // available yet at provider-construction time to seed from real data.
  // `seedFromRecentMoodIfUnset()` below pulls in the user's actual last
  // mood as soon as it's loaded (see ProfileScreen.build), same as the
  // source script's "reflect today's mood in the background right away."
  MoodAccentController() : super(kDefaultProfileAccent);

  bool _seeded = false;

  /// Called once real mood history has loaded for the signed-in user.
  /// Only takes effect before the user has picked/posted a mood
  /// themselves this session — after that, an explicit selection should
  /// win over the historical seed.
  void seedFromRecentMoodIfUnset(MoodEntry mostRecent) {
    if (_seeded) return;
    _seeded = true;
    setAccent(accent: mostRecent.accent, accentLight: mostRecent.accentLight);
  }

  /// Called whenever the user logs/selects a mood — from the Profile mood
  /// strip. Every screen mounted under the app shell picks this up
  /// automatically and transitions its background to match.
  void selectMoodAccent(MoodEntry mood) {
    _seeded = true;
    setAccent(accent: mood.accent, accentLight: mood.accentLight);
  }

  /// Lower-level setter for callers that don't have a [MoodEntry] handy —
  /// e.g. moodify-create's [ComposerController], which posts a
  /// `MoodOption`/`ComposerAccent` pair instead.
  void setAccent({required Color accent, required Color accentLight}) {
    _seeded = true;
    state = ProfileAccent(accent: accent, accentLight: accentLight);
  }
}

final moodAccentProvider = StateNotifierProvider<MoodAccentController, ProfileAccent>(
  (ref) => MoodAccentController(),
);