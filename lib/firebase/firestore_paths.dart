/// Firestore data model for Moodify. Centralized here so every repository
/// agrees on the same paths.
///
/// ```
/// /users/{uid}                    — profile doc (name, handle, streak, counts)
/// /users/{uid}/moods/{moodDocId}  — that user's mood history (Profile's "Recent moods")
/// /moodifies/{moodifyDocId}       — a posted Moodify (see MoodifyRepository.post)
/// /friendships/{friendshipId}     — one doc per pair of users, id is both
///                                    uids sorted and joined with '_'; see
///                                    FriendsRepository doc comment for the
///                                    field shape (uids, status, requestedBy,
///                                    seenBy, createdAt/acceptedAt).
/// /users/{uid}/blocked/{blockedUid} — accounts this user has blocked
///                                    (name/handle snapshot + blockedAt).
///                                    See FriendsRepository.blockUser().
/// /reports/{reportId}             — a user-submitted report against
///                                    another user (reporterUid,
///                                    reportedUid, reason, details,
///                                    createdAt). See
///                                    FriendsRepository.reportUser().
/// ```
class FirestorePaths {
  FirestorePaths._();

  static String user(String uid) => 'users/$uid';
  static String userMoods(String uid) => 'users/$uid/moods';
  static String blockedUsers(String uid) => 'users/$uid/blocked';

  /// Top-level feed of posted Moodifies. Written by
  /// `MoodifyRepository.post()`.
  static const String moodifies = 'moodifies';

  /// Top-level collection of friendship/friend-request docs. Written and
  /// read by `FriendsRepository`.
  static const String friendships = 'friendships';

  /// Top-level collection of user-submitted reports. Written by
  /// `FriendsRepository.reportUser()`; reviewed by moderators outside the
  /// app (no in-app reader for this collection, by design).
  static const String reports = 'reports';

  /// Deterministic doc id for the friendship between two uids — sorting
  /// them first means either party can compute the same id independently
  /// (no query needed to find "does a friendship already exist").
  static String friendshipId(String uidA, String uidB) {
    final sorted = [uidA, uidB]..sort();
    return '${sorted[0]}_${sorted[1]}';
  }
}