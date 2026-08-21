import 'package:flutter/material.dart';

@immutable
class Friend {
  const Friend({
    required this.uid,
    required this.name,
    required this.handle,
    this.emoji,
    this.mood,
    this.message,
    this.intentLabel,
    this.accent,
    this.time,
    this.acked = false,
  });

  /// Firestore uid of the friend — the real identity backing this entry.
  /// Everything else (name/handle/mood) is denormalized display data that
  /// can go stale; `uid` is what repositories key off of.
  final String uid;
  final String name;
  final String handle;
  final String? emoji;
  final String? mood;

  /// The custom message (and/or a suggested-message chip) the friend
  /// wrote when posting this mood — see MoodifyRepository.post()'s
  /// `lastMoodMessage` field. Null/empty if they posted with no message.
  final String? message;

  /// Display label for the "Let friends know" intent pill (e.g.
  /// "Available to talk", "Need space") the friend optionally picked when
  /// posting — see MoodifyRepository.post()'s `lastMoodIntent` field.
  /// Null if they didn't pick one.
  final String? intentLabel;
  final Color? accent;
  final String? time;

  /// Whether the current user has marked this friend's current mood as
  /// seen — backed by `FriendsRepository.setMoodSeen()`.
  final bool acked;

  bool get hasMood => emoji != null;
}

/// A pending incoming friend request — someone else asked the current
/// user to be friends. Backed by `FriendsRepository.watchIncomingRequests`.
@immutable
class FriendRequest {
  const FriendRequest({
    required this.friendshipId,
    required this.fromUid,
    required this.name,
    required this.handle,
  });

  final String friendshipId;
  final String fromUid;
  final String name;
  final String handle;
}

/// A "people you may know" suggestion. Backed by
/// `FriendsRepository.fetchSuggestions`.
@immutable
class FriendSuggestion {
  const FriendSuggestion({
    required this.uid,
    required this.name,
    required this.handle,
  });

  final String uid;
  final String name;
  final String handle;
}

/// Someone the current user has blocked. Backed by
/// `FriendsRepository.watchBlockedUsers`/`blockUser`/`unblockUser` —
/// stored at `users/{uid}/blocked/{blockedUid}`. Blocking someone also
/// severs any existing friendship, so a blocked user never shows up in
/// the Friends list at the same time as in this list.
@immutable
class BlockedUser {
  const BlockedUser({
    required this.uid,
    required this.name,
    required this.handle,
  });

  final String uid;
  final String name;
  final String handle;
}

/// The set of reasons offered on the report sheet — mirrors what most
/// social apps expose (kept short and non-judgmental) rather than a free
/// text box only, which people tend to skip.
const kReportReasons = <String>[
  'Spam',
  'Harassment or bullying',
  'Inappropriate content',
  'Impersonation',
  'Something else',
];