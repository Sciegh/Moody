import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart' show Color;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../firebase/firestore_paths.dart';
import '../../models/friend.dart';
import '../../models/mood_option.dart' show kIntents;

/// Backs the Friends list, the friend-request inbox, and "people you may
/// know" with real Firestore data — see `FirestorePaths` doc comment for
/// the `friendships` schema.
///
/// A friend's live mood is read off their own denormalized
/// `users/{uid}` fields (`lastMoodEmoji`/`lastMoodLabel`/`lastMoodAccent`/
/// `lastMoodPostedAt`), written by `MoodifyRepository.post()` — the same
/// pattern `ProfileRepository` uses for the "Recent moods" strip, just
/// with one extra hop for "the mood belongs to someone else."
class FriendsRepository {
  FriendsRepository([FirebaseFirestore? firestore]) : _db = firestore ?? FirebaseFirestore.instance;
  final FirebaseFirestore _db;

  static const _moodFreshWindow = Duration(hours: 24);

  CollectionReference<Map<String, dynamic>> get _friendships => _db.collection(FirestorePaths.friendships);

  /// Accepted friends, each merged live with their profile doc so mood /
  /// name / handle changes show up immediately. Sorted so friends with a
  /// fresh mood come first (most recent first), then quiet friends by name.
  Stream<List<Friend>> watchFriends(String uid) {
    return _watchWithProfiles<Friend>(
      uid: uid,
      query: _friendships.where('uids', arrayContains: uid).where('status', isEqualTo: 'accepted'),
      otherUid: (data) => (List<String>.from(data['uids'] as List)).firstWhere((u) => u != uid),
      mapper: (friendUid, friendshipData, profile) {
        final postedAt = (profile?['lastMoodPostedAt'] as Timestamp?)?.toDate();
        final hasFreshMood = postedAt != null && DateTime.now().difference(postedAt) < _moodFreshWindow;
        final seenBy = (friendshipData['seenBy'] as Map<String, dynamic>?) ?? const {};
        final seenAt = (seenBy[uid] as Timestamp?)?.toDate();
        // Was missing — MoodifyRepository.post() writes the intent id
        // (e.g. 'available') to 'lastMoodIntent' on the profile doc, but
        // this mapper never read that field at all, so Friend.intentLabel
        // was always null regardless of what the poster picked. Look the
        // stored id up against kIntents to get the display label
        // friends_list_screen.dart already knows how to show.
        final intentId = hasFreshMood ? (profile?['lastMoodIntent'] as String?) : null;
        String? intentLabel;
        if (intentId != null) {
          for (final i in kIntents) {
            if (i.id == intentId) {
              intentLabel = i.label;
              break;
            }
          }
        }
        return Friend(
          uid: friendUid,
          name: profile?['name'] as String? ?? 'Someone',
          handle: profile?['handle'] as String? ?? '',
          emoji: hasFreshMood ? (profile?['lastMoodEmoji'] as String?) : null,
          mood: hasFreshMood ? (profile?['lastMoodLabel'] as String?) : null,
          message: hasFreshMood ? (profile?['lastMoodMessage'] as String?) : null,
          intentLabel: intentLabel,
          accent: hasFreshMood && profile?['lastMoodAccent'] != null ? Color(profile!['lastMoodAccent'] as int) : null,
          time: hasFreshMood ? _timeAgo(postedAt) : null,
          acked: hasFreshMood && seenAt != null && !seenAt.isBefore(postedAt),
        );
      },
      sort: (list) => list
        ..sort((a, b) {
          if (a.hasMood != b.hasMood) return a.hasMood ? -1 : 1;
          return a.name.toLowerCase().compareTo(b.name.toLowerCase());
        }),
    );
  }

  /// Incoming pending requests (someone else asked *this* user to be
  /// friends) — the "Friend requests" list on add-friend.html.
  Stream<List<FriendRequest>> watchIncomingRequests(String uid) {
    return _watchWithProfiles<FriendRequest>(
      uid: uid,
      query: _friendships.where('uids', arrayContains: uid).where('status', isEqualTo: 'pending'),
      otherUid: (data) => (List<String>.from(data['uids'] as List)).firstWhere((u) => u != uid),
      filter: (friendshipData) => friendshipData['requestedBy'] != uid,
      mapper: (fromUid, friendshipData, profile) => FriendRequest(
        friendshipId: FirestorePaths.friendshipId(uid, fromUid),
        fromUid: fromUid,
        name: profile?['name'] as String? ?? 'Someone',
        handle: profile?['handle'] as String? ?? '',
      ),
    );
  }

  Stream<int> watchPendingRequestCount(String uid) => watchIncomingRequests(uid).map((r) => r.length);

  /// "People you may know" — anyone recently joined who isn't already a
  /// friend, a pending request, or the current user. Client-side dedupe
  /// (fine at this app's scale); a larger app would back this with a
  /// dedicated recommendations index instead of scanning `users`.
  Future<List<FriendSuggestion>> fetchSuggestions(String uid, {String search = '', int limit = 20}) async {
    Query<Map<String, dynamic>> q = _db.collection('users').orderBy('createdAt', descending: true).limit(60);
    final usersSnap = await q.get();
    final existing = await _friendships.where('uids', arrayContains: uid).get();
    final excluded = <String>{uid};
    for (final doc in existing.docs) {
      final uids = List<String>.from(doc.data()['uids'] as List);
      excluded.addAll(uids);
    }

    final term = search.trim().toLowerCase();
    final results = <FriendSuggestion>[];
    for (final doc in usersSnap.docs) {
      if (excluded.contains(doc.id)) continue;
      final name = doc.data()['name'] as String? ?? 'Someone';
      final handle = doc.data()['handle'] as String? ?? '';
      if (term.isNotEmpty && !name.toLowerCase().contains(term) && !handle.toLowerCase().contains(term)) {
        continue;
      }
      results.add(FriendSuggestion(uid: doc.id, name: name, handle: handle));
      if (results.length >= limit) break;
    }
    return results;
  }

  /// Sends (or re-sends) a friend request. No-ops if a friendship/request
  /// already exists between the two uids.
  Future<void> sendFriendRequest({required String fromUid, required String toUid}) async {
    final ref = _friendships.doc(FirestorePaths.friendshipId(fromUid, toUid));
    final snap = await ref.get();
    if (snap.exists) return;
    await ref.set({
      'uids': [fromUid, toUid]..sort(),
      'status': 'pending',
      'requestedBy': fromUid,
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': <String, dynamic>{},
    });
  }

  /// Accepts a pending request and bumps both users' `friendCount`.
  Future<void> acceptRequest({required String uid, required String friendUid}) async {
    final ref = _friendships.doc(FirestorePaths.friendshipId(uid, friendUid));
    final batch = _db.batch();
    batch.update(ref, {'status': 'accepted', 'acceptedAt': FieldValue.serverTimestamp()});
    batch.update(_db.doc(FirestorePaths.user(uid)), {'friendCount': FieldValue.increment(1)});
    batch.update(_db.doc(FirestorePaths.user(friendUid)), {'friendCount': FieldValue.increment(1)});
    await batch.commit();
  }

  Future<void> declineRequest({required String uid, required String friendUid}) {
    return _friendships.doc(FirestorePaths.friendshipId(uid, friendUid)).delete();
  }

  /// Ends an existing friendship — was entirely missing (only sending,
  /// accepting, and declining requests existed; there was no way to undo
  /// an accepted friendship once made). Deletes the shared friendship doc
  /// and decrements both users' `friendCount` symmetrically with how
  /// [acceptRequest] increments them, so counts stay accurate on both
  /// sides.
  Future<void> removeFriend({required String uid, required String friendUid}) async {
    final ref = _friendships.doc(FirestorePaths.friendshipId(uid, friendUid));
    final batch = _db.batch();
    batch.delete(ref);
    batch.update(_db.doc(FirestorePaths.user(uid)), {'friendCount': FieldValue.increment(-1)});
    batch.update(_db.doc(FirestorePaths.user(friendUid)), {'friendCount': FieldValue.increment(-1)});
    await batch.commit();
  }

  /// Marks (or unmarks) a friend's current mood as seen — the real
  /// backing for what was a local-only `Set<String>` in the UI before.
  Future<void> setMoodSeen({required String uid, required String friendUid, required bool seen}) {
    final ref = _friendships.doc(FirestorePaths.friendshipId(uid, friendUid));
    return ref.update({'seenBy.$uid': seen ? FieldValue.serverTimestamp() : FieldValue.delete()});
  }

  /// Blocked accounts, newest-first. Backs the Privacy screen's "Blocked
  /// accounts" row and the dedicated blocked-accounts list — was entirely
  /// missing before (that row linked to add-friend.html with a hardcoded
  /// badge count, since nothing ever actually wrote a block).
  Stream<List<BlockedUser>> watchBlockedUsers(String uid) {
    return _db
        .collection(FirestorePaths.blockedUsers(uid))
        .orderBy('blockedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => BlockedUser(
                  uid: doc.id,
                  name: doc.data()['name'] as String? ?? 'Someone',
                  handle: doc.data()['handle'] as String? ?? '',
                ))
            .toList());
  }

  Stream<int> watchBlockedCount(String uid) => watchBlockedUsers(uid).map((b) => b.length);

  /// Blocks [blockedUid]. Also severs any existing friendship in both
  /// directions (accepted or pending) the same way [removeFriend] does,
  /// so a blocked account can't keep sharing moods with — or keep a
  /// pending request open against — the blocker.
  Future<void> blockUser({
    required String uid,
    required String blockedUid,
    required String name,
    required String handle,
  }) async {
    final batch = _db.batch();
    batch.set(_db.collection(FirestorePaths.blockedUsers(uid)).doc(blockedUid), {
      'name': name,
      'handle': handle,
      'blockedAt': FieldValue.serverTimestamp(),
    });
    final friendshipRef = _friendships.doc(FirestorePaths.friendshipId(uid, blockedUid));
    final friendshipSnap = await friendshipRef.get();
    if (friendshipSnap.exists) {
      final wasAccepted = friendshipSnap.data()?['status'] == 'accepted';
      batch.delete(friendshipRef);
      if (wasAccepted) {
        batch.update(_db.doc(FirestorePaths.user(uid)), {'friendCount': FieldValue.increment(-1)});
        batch.update(_db.doc(FirestorePaths.user(blockedUid)), {'friendCount': FieldValue.increment(-1)});
      }
    }
    await batch.commit();
  }

  Future<void> unblockUser({required String uid, required String blockedUid}) {
    return _db.collection(FirestorePaths.blockedUsers(uid)).doc(blockedUid).delete();
  }

  /// Files a report against [reportedUid] for moderators to review.
  /// There's deliberately no in-app reader for `reports` — this is a
  /// one-way mailbox, not a feature users browse.
  Future<void> reportUser({
    required String uid,
    required String reportedUid,
    required String reason,
    String? details,
  }) {
    return _db.collection(FirestorePaths.reports).add({
      'reporterUid': uid,
      'reportedUid': reportedUid,
      'reason': reason,
      if (details != null && details.trim().isNotEmpty) 'details': details.trim(),
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  String _timeAgo(DateTime t) {
    final diff = DateTime.now().difference(t);
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    return '${diff.inDays}d ago';
  }

  /// Shared plumbing for "watch a set of friendship docs, keep each one
  /// live-merged with the other party's profile doc." Firestore has no
  /// built-in join, so this hand-rolls one: it listens to the friendship
  /// query, and for every doc it discovers, opens (and later closes) a
  /// `users/{otherUid}` listener, re-emitting the combined list whenever
  /// either side changes.
  ///
  /// Requires a composite index on `friendships` (uids array-contains +
  /// status ==) — Firestore will prompt for one on first real query if it
  /// doesn't exist yet.
  Stream<List<T>> _watchWithProfiles<T>({
    required String uid,
    required Query<Map<String, dynamic>> query,
    required String Function(Map<String, dynamic> friendshipData) otherUid,
    required T Function(String otherUid, Map<String, dynamic> friendshipData, Map<String, dynamic>? profile) mapper,
    bool Function(Map<String, dynamic> friendshipData)? filter,
    List<T> Function(List<T> list)? sort,
  }) {
    late final StreamController<List<T>> controller;
    final friendshipData = <String, Map<String, dynamic>>{};
    final profileData = <String, Map<String, dynamic>?>{};
    final profileSubs = <String, StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>>{};
    StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? mainSub;

    void emit() {
      final list = friendshipData.entries
          .map((e) => mapper(e.key, e.value, profileData[e.key]))
          .toList();
      controller.add(sort != null ? sort(list) : list);
    }

    void start() {
      mainSub = query.snapshots().listen((snap) {
        final current = <String>{};
        for (final doc in snap.docs) {
          final data = doc.data();
          if (filter != null && !filter(data)) continue;
          final other = otherUid(data);
          current.add(other);
          friendshipData[other] = data;
          profileSubs.putIfAbsent(other, () {
            return _db
                .doc(FirestorePaths.user(other))
                .snapshots()
                .listen((profSnap) {
              profileData[other] = profSnap.data();
              emit();
            });
          });
        }
        final stale = friendshipData.keys.where((k) => !current.contains(k)).toList();
        for (final k in stale) {
          friendshipData.remove(k);
          profileData.remove(k);
          profileSubs.remove(k)?.cancel();
        }
        emit();
      }, onError: controller.addError);
    }

    controller = StreamController<List<T>>.broadcast(
      onListen: start,
      onCancel: () {
        mainSub?.cancel();
        for (final s in profileSubs.values) {
          s.cancel();
        }
        profileSubs.clear();
      },
    );

    return controller.stream;
  }
}

final friendsRepositoryProvider = Provider<FriendsRepository>((ref) => FriendsRepository());

final friendsStreamProvider = StreamProvider.family<List<Friend>, String>((ref, uid) {
  return ref.watch(friendsRepositoryProvider).watchFriends(uid);
});

final incomingRequestsStreamProvider = StreamProvider.family<List<FriendRequest>, String>((ref, uid) {
  return ref.watch(friendsRepositoryProvider).watchIncomingRequests(uid);
});

final pendingRequestCountStreamProvider = StreamProvider.family<int, String>((ref, uid) {
  return ref.watch(friendsRepositoryProvider).watchPendingRequestCount(uid);
});

final blockedUsersStreamProvider = StreamProvider.family<List<BlockedUser>, String>((ref, uid) {
  return ref.watch(friendsRepositoryProvider).watchBlockedUsers(uid);
});

final blockedCountStreamProvider = StreamProvider.family<int, String>((ref, uid) {
  return ref.watch(friendsRepositoryProvider).watchBlockedCount(uid);
});