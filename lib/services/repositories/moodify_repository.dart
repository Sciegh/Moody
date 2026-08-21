import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/firestore_paths.dart';
import '../../models/mood_option.dart';

/// Backs `ComposerController.post()` with a real Firestore write, replacing
/// the `Future.delayed`-simulated post. A single [FirebaseFirestore.runTransaction]
/// does three things atomically:
/// 1. Creates the `moodifies` document (the actual post).
/// 2. Mirrors it into `users/{uid}/moods` — what Profile's "Recent moods"
///    strip reads (see `ProfileRepository.watchRecentMoods`).
/// 3. Updates the author's `streak`/`moodifyCount`/`lastPostedAt` on their
///    profile doc, with real day-based streak math (post again same day =
///    streak unchanged; post the day after your last post = streak + 1;
///    skip a day = streak resets to 1).
///
/// A Moodify is meant to fade from feeds after 24h — `expiresAt` is stored
/// so a Cloud Function (or a client-side query filter) can hide/clean up
/// expired posts. No Cloud Function is included here — that's server-side
/// infra out of scope for a client-only pass.
class MoodifyRepository {
  MoodifyRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  Future<void> post({
    required String authorUid,
    required String authorName,
    required MoodOption mood,
    required String message,
    required String? intent,
    required List<String> audienceUids, // empty = all friends
  }) async {
    final now = DateTime.now();
    final moodifyRef = _db.collection(FirestorePaths.moodifies).doc();
    final moodHistoryRef = _db.collection(FirestorePaths.userMoods(authorUid)).doc();
    final userRef = _db.doc(FirestorePaths.user(authorUid));

    await _db.runTransaction((tx) async {
      final userSnap = await tx.get(userRef);
      final data = userSnap.data() ?? {};
      final lastPostedAt = (data['lastPostedAt'] as Timestamp?)?.toDate();
      final currentStreak = data['streak'] as int? ?? 0;
      final currentMoodifyCount = data['moodifyCount'] as int? ?? 0;

      final newStreak = _nextStreak(currentStreak: currentStreak, lastPostedAt: lastPostedAt, now: now);

      tx.set(moodifyRef, {
        'authorUid': authorUid,
        'authorName': authorName,
        'moodId': mood.id,
        'emoji': mood.emoji,
        'label': mood.label,
        'accent': mood.accent.toARGB32(),
        'message': message,
        'intent': intent,
        'audienceUids': audienceUids,
        'postedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(now.add(const Duration(hours: 24))),
      });

      tx.set(moodHistoryRef, {
        'emoji': mood.emoji,
        // Was missing — Profile's "Recent moods" strip only ever showed
        // the emoji + day, with no way to know which mood it actually
        // was without hovering/guessing. See ProfileRepository.watchRecentMoods.
        'label': mood.label,
        'dayLabel': 'Today',
        'accent': mood.accent.toARGB32(),
        'accentLight': _lighten(mood.accent).toARGB32(),
        'postedAt': Timestamp.fromDate(now),
        // Links this history entry back to the actual feed post, so
        // deleteMoodify() can remove both in one go — see that method's
        // doc comment.
        'moodifyId': moodifyRef.id,
      });

      tx.set(
        userRef,
        {
          'streak': newStreak,
          'moodifyCount': currentMoodifyCount + 1,
          'lastPostedAt': Timestamp.fromDate(now),
          // Denormalized onto the profile doc so friends can read "what's
          // this person's mood right now" with a single doc listener each,
          // instead of every viewer querying this user's full mood history.
          // Read by FriendsRepository.watchFriends() and by
          // MoodAccentController's seed-on-first-load.
          'lastMoodEmoji': mood.emoji,
          'lastMoodLabel': mood.label,
          // Was missing — the author's custom message (and the "let
          // friends know" text) was written to the `moodifies` doc but
          // never denormalized here, so FriendsRepository.watchFriends()
          // (which only reads this profile doc) had no way to surface it.
          // Friends saw the mood but never the message that came with it.
          'lastMoodMessage': message,
          // Was also missing — same story as lastMoodMessage above, but
          // for the "Let friends know" intent pill (Available to talk /
          // Need space / etc). It was saved to the `moodifies` doc and
          // then went nowhere: FriendsRepository never read an intent
          // field because there wasn't one, so it silently never reached
          // the Friends list no matter what the poster picked.
          'lastMoodIntent': intent,
          'lastMoodAccent': mood.accent.toARGB32(),
          'lastMoodAccentLight': _lighten(mood.accent).toARGB32(),
          'lastMoodPostedAt': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
    });
  }

  int _nextStreak({required int currentStreak, required DateTime? lastPostedAt, required DateTime now}) {
    if (lastPostedAt == null) return 1;
    final lastDay = DateTime(lastPostedAt.year, lastPostedAt.month, lastPostedAt.day);
    final today = DateTime(now.year, now.month, now.day);
    final dayGap = today.difference(lastDay).inDays;
    if (dayGap == 0) return currentStreak == 0 ? 1 : currentStreak; // already posted today
    if (dayGap == 1) return currentStreak + 1; // posted yesterday — streak continues
    return 1; // missed a day or more — streak resets
  }

  /// Deletes a posted Moodify — was entirely missing (Help & Support and
  /// the composer's own footer both claimed "delete it anytime from your
  /// profile," but nothing in the app ever wrote a delete). Removes the
  /// `moodifies` feed doc (so it disappears from friends' feeds right
  /// away, not just after it naturally expires) and the matching
  /// `users/{uid}/moods` history entry (so it drops out of the "Recent
  /// moods" strip), and decrements `moodifyCount` to match.
  Future<void> deleteMoodify({
    required String uid,
    required String moodHistoryDocId,
    String? moodifyId,
  }) async {
    final batch = _db.batch();
    batch.delete(_db.collection(FirestorePaths.userMoods(uid)).doc(moodHistoryDocId));
    if (moodifyId != null) {
      batch.delete(_db.collection(FirestorePaths.moodifies).doc(moodifyId));
    }
    batch.set(
      _db.doc(FirestorePaths.user(uid)),
      {'moodifyCount': FieldValue.increment(-1)},
      SetOptions(merge: true),
    );
    await batch.commit();
  }

  /// Rough approximation for the "light" variant of a mood's accent color,
  /// used for the mood-history entry's card background — matches the
  /// lighten-toward-white math in create_controller.dart's `shade()`.
  Color _lighten(Color c) => Color.lerp(c, const Color(0xFFFFFFFF), 0.35)!;
}

final moodifyRepositoryProvider = Provider<MoodifyRepository>((ref) => MoodifyRepository());