import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/providers/mood_accent_provider.dart';
import '../../models/mood_option.dart';
import '../../services/auth_providers.dart';
import '../../services/repositories/moodify_repository.dart';

/// `shade(hex, amt)` from the source `<script>` — lightens toward white for
/// amt > 0, darkens toward black for amt < 0. Used to derive `--accent-dark`
/// / `--accent-light` from a mood's base `accent` the same way the source does.
Color shade(Color c, double amt) {
  return amt >= 0 ? Color.lerp(c, Colors.white, amt)! : Color.lerp(c, Colors.black, -amt)!;
}

@immutable
class ComposerAccent {
  const ComposerAccent({required this.accent, required this.accentDark, required this.accentLight, required this.onAccent});

  final Color accent;
  final Color accentDark;
  final Color accentLight;
  final Color onAccent;

  factory ComposerAccent.forMood(MoodOption m) => ComposerAccent(
        accent: m.accent,
        accentDark: shade(m.accent, -0.35),
        accentLight: shade(m.accent, 0.35),
        onAccent: m.onAccent,
      );

  // `:root` defaults, restored by resetAll().
  static const initial = ComposerAccent(
    accent: Color(0xFFFF6F91),
    accentDark: Color(0xFFE24E74),
    accentLight: Color(0xFFFFC1D2),
    onAccent: Color(0xFF3A0E1D),
  );
}

enum AudienceMode { all, select }

enum PostStatus { idle, posting, error, success }

@immutable
class ComposerState {
  const ComposerState({
    this.selectedMood,
    this.selectedIntent,
    this.activeFilter = 'all',
    this.accent = ComposerAccent.initial,
    this.notifCardVisible = true,
    // TODO(iap): the source persists this via `localStorage`
    // (`moodify_deluxe_unlocked`) so a purchase survives a reload. This
    // in-memory bool resets on app restart — wire up real purchase
    // persistence (App Store/Play Billing entitlement, stored server-side)
    // before shipping.
    this.deluxeUnlocked = false,
    this.paywallOpen = false,
    this.paywallProcessing = false,
    this.audienceSheetOpen = false,
    this.audienceMode = AudienceMode.all,
    this.selectedFriends = const {},
    this.friendSearch = '',
    this.postStatus = PostStatus.idle,
    this.errorMessage,
    this.successText,
    // Prototype-only toggles mirroring the source's "dev panel" — see
    // MoodifyCreateScreen doc comment for why these are gated to debug mode.
    this.simulateOffline = false,
    this.simulateError = false,
  });

  final MoodOption? selectedMood;
  final String? selectedIntent;
  final String activeFilter;
  final ComposerAccent accent;
  final bool notifCardVisible;
  final bool deluxeUnlocked;
  final bool paywallOpen;
  final bool paywallProcessing;
  final bool audienceSheetOpen;
  final AudienceMode audienceMode;
  final Set<String> selectedFriends;
  final String friendSearch;
  final PostStatus postStatus;
  final String? errorMessage;
  final String? successText;
  final bool simulateOffline;
  final bool simulateError;

  bool get moodSelected => selectedMood != null;

  String get audienceTitle {
    if (audienceMode == AudienceMode.all) return 'All friends';
    final n = selectedFriends.length;
    return n > 0 ? '$n friend${n > 1 ? 's' : ''} selected' : 'Select friends';
  }

  /// [totalFriends] comes from the caller (backed by `friendsStreamProvider`)
  /// rather than being stored on this state — was previously a hardcoded
  /// '12 friends', disconnected from the user's actual friend count.
  String audienceSubtitle(int totalFriends) {
    if (audienceMode == AudienceMode.all) {
      return '$totalFriends friend${totalFriends == 1 ? '' : 's'} will be notified';
    }
    return selectedFriends.isNotEmpty ? 'Only they will be notified' : 'Choose at least one friend';
  }

  ComposerState copyWith({
    MoodOption? selectedMood,
    bool clearSelectedMood = false,
    String? selectedIntent,
    bool clearSelectedIntent = false,
    String? activeFilter,
    ComposerAccent? accent,
    bool? notifCardVisible,
    bool? deluxeUnlocked,
    bool? paywallOpen,
    bool? paywallProcessing,
    bool? audienceSheetOpen,
    AudienceMode? audienceMode,
    Set<String>? selectedFriends,
    String? friendSearch,
    PostStatus? postStatus,
    String? errorMessage,
    bool clearErrorMessage = false,
    String? successText,
    bool? simulateOffline,
    bool? simulateError,
  }) {
    return ComposerState(
      selectedMood: clearSelectedMood ? null : (selectedMood ?? this.selectedMood),
      selectedIntent: clearSelectedIntent ? null : (selectedIntent ?? this.selectedIntent),
      activeFilter: activeFilter ?? this.activeFilter,
      accent: accent ?? this.accent,
      notifCardVisible: notifCardVisible ?? this.notifCardVisible,
      deluxeUnlocked: deluxeUnlocked ?? this.deluxeUnlocked,
      paywallOpen: paywallOpen ?? this.paywallOpen,
      paywallProcessing: paywallProcessing ?? this.paywallProcessing,
      audienceSheetOpen: audienceSheetOpen ?? this.audienceSheetOpen,
      audienceMode: audienceMode ?? this.audienceMode,
      selectedFriends: selectedFriends ?? this.selectedFriends,
      friendSearch: friendSearch ?? this.friendSearch,
      postStatus: postStatus ?? this.postStatus,
      errorMessage: clearErrorMessage ? null : (errorMessage ?? this.errorMessage),
      successText: successText ?? this.successText,
      simulateOffline: simulateOffline ?? this.simulateOffline,
      simulateError: simulateError ?? this.simulateError,
    );
  }
}

class ComposerController extends StateNotifier<ComposerState> {
  ComposerController(this._ref) : super(const ComposerState());

  final Ref _ref;

  void setFilter(String filter) => state = state.copyWith(activeFilter: filter);

  void selectMood(MoodOption m) {
    state = state.copyWith(
      selectedMood: m,
      selectedIntent: m.intent,
      accent: ComposerAccent.forMood(m),
    );
  }

  void toggleIntent(String intentId) {
    state = state.copyWith(
      selectedIntent: state.selectedIntent == intentId ? null : intentId,
      clearSelectedIntent: state.selectedIntent == intentId,
    );
  }

  void dismissNotifCard() => state = state.copyWith(notifCardVisible: false);

  void openPaywall() => state = state.copyWith(paywallOpen: true);
  void closePaywall() => state = state.copyWith(paywallOpen: false, paywallProcessing: false);

  /// TODO(iap): simulated purchase — see [ComposerState.deluxeUnlocked].
  Future<void> buyDeluxe() async {
    state = state.copyWith(paywallProcessing: true);
    await Future.delayed(const Duration(milliseconds: 900));
    state = state.copyWith(deluxeUnlocked: true);
    await Future.delayed(const Duration(milliseconds: 700));
    state = state.copyWith(paywallOpen: false, paywallProcessing: false);
  }

  void openAudienceSheet() => state = state.copyWith(audienceSheetOpen: true, friendSearch: '');
  void closeAudienceSheet() => state = state.copyWith(audienceSheetOpen: false);

  void setAudienceMode(AudienceMode mode) => state = state.copyWith(audienceMode: mode);

  /// [uid] is the friend's Firestore uid (not their display name) — this
  /// set is sent to `MoodifyRepository.post()` as `audienceUids` as-is, so
  /// it has to hold real uids or the post's audience targeting is
  /// meaningless.
  void toggleFriend(String uid) {
    final next = Set<String>.from(state.selectedFriends);
    next.contains(uid) ? next.remove(uid) : next.add(uid);
    state = state.copyWith(selectedFriends: next);
  }

  void setFriendSearch(String q) => state = state.copyWith(friendSearch: q);

  void toggleSimulateOffline() => state = state.copyWith(simulateOffline: !state.simulateOffline);
  void toggleSimulateError() => state = state.copyWith(simulateError: !state.simulateError);

  /// [totalFriends] backs the "All friends" audience count in the success
  /// message — pass the caller's current `friendsStreamProvider` length.
  Future<void> post(String message, {required int totalFriends}) async {
    if (!state.moodSelected) return;
    state = state.copyWith(clearErrorMessage: true);

    if (state.simulateOffline) {
      state = state.copyWith(
        errorMessage: "You're offline. This Moodify will send automatically once you're back online — nothing has been lost.",
      );
      return;
    }

    state = state.copyWith(postStatus: PostStatus.posting);

    final m = state.selectedMood!;
    final audienceUids = state.audienceMode == AudienceMode.all ? const <String>[] : state.selectedFriends.toList();
    final count = state.audienceMode == AudienceMode.all ? totalFriends : state.selectedFriends.length;

    try {
      if (state.simulateError) {
        // Dev-panel toggle — deliberately skips the real write and takes
        // the same failure path a genuine Firestore error would.
        throw Exception('Simulated post failure (dev panel)');
      }

      final authService = _ref.read(authServiceProvider);
      final uid = authService.currentUserId;
      if (uid == null) throw Exception('Not signed in');

      await _ref.read(moodifyRepositoryProvider).post(
            authorUid: uid,
            authorName: authService.currentUserName ?? 'Someone',
            mood: m,
            message: message.trim(),
            intent: state.selectedIntent,
            audienceUids: audienceUids,
          );

      state = state.copyWith(
        postStatus: PostStatus.success,
        successText: '${m.emoji} ${m.label} — sent to $count friend${count == 1 ? '' : 's'}. '
            "It'll fade from their feed in 24 hours.",
      );

      // A freshly-posted mood becomes "today's mood" — the persistent
      // app-wide background (and Profile's own accent) should reflect it
      // everywhere, not just in this composer.
      _ref.read(moodAccentProvider.notifier).setAccent(
            accent: state.accent.accent,
            accentLight: state.accent.accentLight,
          );
    } catch (_) {
      state = state.copyWith(
        postStatus: PostStatus.idle,
        errorMessage: "Couldn't post your Moodify. Check your connection and try again — nothing you've written has been lost.",
      );
    }
  }

  void retry(String message, {required int totalFriends}) {
    state = state.copyWith(clearErrorMessage: true);
    post(message, totalFriends: totalFriends);
  }

  void resetAll() {
    state = ComposerState(
      deluxeUnlocked: state.deluxeUnlocked, // purchase (if any) survives a reset
      simulateOffline: state.simulateOffline,
      simulateError: state.simulateError,
    );
  }
}

final composerControllerProvider = StateNotifierProvider.autoDispose<ComposerController, ComposerState>(
  (ref) => ComposerController(ref),
);