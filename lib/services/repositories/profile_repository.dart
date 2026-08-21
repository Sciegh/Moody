import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/firestore_paths.dart';
import '../../models/mood_entry.dart';

/// Backs Profile's header (name/handle/streak/counts) with real Firestore
/// data. Replaces the hardcoded 'Sciegh' / '@sciegh' / kMockStreak numbers
/// currently in profile_screen.dart — see the TODO(firebase) comment
/// there for the wiring that still needs to happen after this repository
/// exists.
class ProfileRepository {
  ProfileRepository([FirebaseFirestore? firestore, FirebaseStorage? storage])
      : _db = firestore ?? FirebaseFirestore.instance,
        _storage = storage ?? FirebaseStorage.instance;
  final FirebaseFirestore _db;
  final FirebaseStorage _storage;

  /// Call once right after registration succeeds (register_screen.dart)
  /// so a profile document exists before any screen tries to read it.
  /// Safe to call more than once — it no-ops if the document already
  /// exists, so it's also safe to call defensively on login in case an
  /// older account predates this field.
  Future<void> ensureProfileDocument({
    required String uid,
    required String name,
    required String email,
  }) async {
    final ref = _db.doc(FirestorePaths.user(uid));
    final snap = await ref.get();
    if (snap.exists) return;

    await ref.set({
      'name': name,
      'handle': _handleFromEmail(email),
      'email': email,
      'streak': 0,
      'friendCount': 0,
      'moodifyCount': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _handleFromEmail(String email) {
    final local = email.split('@').first;
    // Keep it printable even if the local part has odd characters — this
    // only feeds the '@handle' display text, not an actual lookup key.
    return local.isEmpty ? 'user' : local;
  }

  Stream<Map<String, dynamic>?> watchProfile(String uid) {
    return _db.doc(FirestorePaths.user(uid)).snapshots().map((snap) => snap.data());
  }

  /// Saves edits made on account-details.html — was previously a no-op
  /// (the screen just showed a "Saved ✓" toast without writing anywhere).
  ///
  /// Uses `set(..., merge: true)` rather than `update()`. `update()`
  /// throws NOT_FOUND if the doc doesn't exist yet, which is exactly what
  /// happened when the register-screen race (see RegisterScreen._submit
  /// doc comment) left a user without a profile doc: every subsequent
  /// save attempt failed with a generic "couldn't save" error and there
  /// was no way to recover from the UI. `set(merge: true)` creates the
  /// doc if missing and patches it otherwise, so a save always succeeds
  /// once the network round-trip does.
  Future<void> updateProfile({required String uid, required String name, required String handle}) {
    return _db.doc(FirestorePaths.user(uid)).set({'name': name, 'handle': handle}, SetOptions(merge: true));
  }

  /// Uploads a picked avatar to Firebase Storage and saves its download
  /// URL to the profile doc. This is the missing other half of
  /// `pickAvatarPhoto` (see its TODO(storage) doc comment) — that
  /// function only ever handed back a local `File` for in-session
  /// preview, so a changed photo looked fine until the app restarted,
  /// then reverted because nothing had actually been persisted or
  /// synced to Firestore for other screens (or friends) to read.
  /// Overwrites any previous avatar at the same path, so there's nothing
  /// to clean up afterwards. Returns the new download URL.
  Future<String> uploadAvatar({required String uid, required File file}) async {
    final ref = _storage.ref('avatars/$uid.jpg');
    await ref.putFile(file, SettableMetadata(contentType: 'image/jpeg'));
    final url = await ref.getDownloadURL();
    await _db.doc(FirestorePaths.user(uid)).set({'photoUrl': url}, SetOptions(merge: true));
    return url;
  }

  /// Saves the device's current FCM token to the profile doc, for a
  /// Cloud Function to read when deciding who to push a notification to.
  /// See NotificationsService.syncTokenToProfile doc comment.
  Future<void> saveFcmToken({required String uid, required String token}) {
    return _db.doc(FirestorePaths.user(uid)).set({'fcmToken': token}, SetOptions(merge: true));
  }

  /// Best-effort cleanup of this user's Firestore data. Doesn't touch
  /// `moodifies` (posts already visible to friends) or friendship docs the
  /// other party still owns half of — a full account-delete pipeline
  /// would handle that fan-out server-side (Cloud Function), which is out
  /// of scope for a client-only pass, same as MoodifyRepository's
  /// `expiresAt` comment notes for feed cleanup.
  Future<void> deleteProfileData(String uid) async {
    final moods = await _db.collection(FirestorePaths.userMoods(uid)).get();
    final batch = _db.batch();
    for (final doc in moods.docs) {
      batch.delete(doc.reference);
    }
    batch.delete(_db.doc(FirestorePaths.user(uid)));
    await batch.commit();
    // Best-effort — an avatar might never have been uploaded, so a
    // not-found error here is expected and fine to ignore.
    try {
      await _storage.ref('avatars/$uid.jpg').delete();
    } catch (_) {}
  }

  /// Backs the streak sheet's 7-dot week view — was a static
  /// all-true `kMockWeek` before. Returns which of the last 7 calendar
  /// days (oldest first, today last) had at least one Moodify posted.
  Stream<List<bool>> watchLast7DaysActivity(String uid) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));

    return _db
        .collection(FirestorePaths.userMoods(uid))
        .where('postedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((snap) {
      final postedDays = snap.docs.map((d) {
        final ts = (d.data()['postedAt'] as Timestamp).toDate();
        return DateTime(ts.year, ts.month, ts.day);
      }).toSet();

      return List<bool>.generate(7, (i) {
        final day = sevenDaysAgo.add(Duration(days: i));
        return postedDays.contains(day);
      });
    });
  }

  /// Profile's "Recent moods" strip — most recent 7 entries, newest first.
  /// Written by `MoodifyRepository.post()` alongside each Moodify post.
  Stream<List<MoodEntry>> watchRecentMoods(String uid) {
    return _db
        .collection(FirestorePaths.userMoods(uid))
        .orderBy('postedAt', descending: true)
        .limit(7)
        .snapshots()
        .map((snap) => snap.docs.map((d) {
              final data = d.data();
              // Was reading a precomputed `dayLabel` string
              // ('Today'/'Wed'/...) written once at post time — like the
              // mock data, that froze the label forever, so an entry
              // posted "Today" would still say "Today" a week later.
              // `postedAt` is the real source of truth; MoodEntry.date
              // stores that Timestamp and the UI derives the label
              // (see formatMoodDay) fresh on every render instead.
              final postedAt = data['postedAt'] as Timestamp?;
              return MoodEntry(
                emoji: data['emoji'] as String? ?? '🙂',
                date: postedAt?.toDate() ?? DateTime.now(),
                label: data['label'] as String?,
                accent: Color(data['accent'] as int? ?? 0xFFFF6F91),
                accentLight: Color(data['accentLight'] as int? ?? 0xFFFFC1D2),
                id: d.id,
                moodifyId: data['moodifyId'] as String?,
              );
            }).toList());
  }
}

final profileRepositoryProvider = Provider<ProfileRepository>((ref) => ProfileRepository());

/// Reactive stream of a given user's profile document. `.family` because
/// the uid isn't known until the widget reads it from [authServiceProvider].
final profileStreamProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchProfile(uid);
});

/// Reactive stream of a user's recent-moods history — see
/// [ProfileRepository.watchRecentMoods].
final recentMoodsStreamProvider = StreamProvider.family<List<MoodEntry>, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchRecentMoods(uid);
});

/// Backs the streak sheet's week dots — see
/// [ProfileRepository.watchLast7DaysActivity].
final last7DaysActivityStreamProvider = StreamProvider.family<List<bool>, String>((ref, uid) {
  return ref.watch(profileRepositoryProvider).watchLast7DaysActivity(uid);
});