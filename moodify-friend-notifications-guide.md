# Moodify: Notify friends when someone posts a mood

Triggering action: `MoodifyRepository.post()` writes a new `moodifies/{id}` doc (and denormalizes `lastMood*` onto `users/{authorUid}`). This guide adds a Cloud Function that, on that write, pushes a text+emoji notification to the author's friends (or the picked audience) via FCM, with server-side friendship verification so a client can never make another user get a notification they shouldn't.

## Recommendation

**Architecture:** a Firestore-triggered Cloud Function (2nd gen, `onDocumentCreated` on `moodifies/{moodifyId}`) reads the new doc, looks up the author's **accepted** friendships directly from Firestore, filters to `audienceUids` if the post wasn't sent to "all friends," and sends one `messaging.sendEachForMulticast()` call per event to the recipients' stored FCM tokens.

Why this fits the constraints:
- **Secure** — the client never calls a "send notification to UID X" endpoint. It only ever writes its own Moodify (already governed by Security Rules below). The function re-derives *who is allowed to be notified* itself, from the `friendships` collection, so a malicious or buggy client supplying a bogus `audienceUids` list can't get a stranger notified — the function intersects it with real accepted friendships regardless of what the client sent.
- **Reliable** — a Firestore write is durable; the trigger fires once the document commits, independent of whether the recipient's app is open, backgrounded, or killed. FCM (not app code) handles delivery/display in the background/terminated cases.
- **Cost-effective** — no polling, no extra writes for the client, one function invocation per Moodify post. Firestore triggers and FCM sends both fall inside Cloud Functions' and FCM's free tiers at Moodify's likely scale (see billing note below).

## Assumptions and Customization Points

| Detail | Value used | Why |
|---|---|---|
| Flutter version | `>=3.3.0 <4.0.0` (pubspec), treated as "latest stable" | from `pubspec.yaml` |
| Firebase products already configured | `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `firebase_messaging`, `flutter_local_notifications` — all already in `pubspec.yaml`, and `NotificationsService`/`ProfileRepository.saveFcmToken` already exist | inspected `lib/` |
| Backend currently used | Firestore-only — `functions/index.js` is referenced in comments but **doesn't exist yet** in the project | inspected `lib/`; no `functions/` dir found |
| Friendship rule | `friendships/{sortedUidA_sortedUidB}` doc, `uids: [a,b]`, `status: 'accepted'` once both sides agree (`FriendsRepository`) | `firestore_paths.dart`, `friends_repository.dart` |
| Triggering action | `MoodifyRepository.post()` creates `moodifies/{id}` with `authorUid`, `authorName`, `emoji`, `label`, `message`, `audienceUids` (`[]` = all friends) | `moodify_repository.dart` |
| Notification text example | Not supplied — I used `"{authorName} is feeling {emoji} {label}"`, e.g. `"Sam is feeling 😌 Calm"`. Swap for anything else; the function only needs `title`/`body` strings. | assumption |
| Token storage | The project currently stores **one** `fcmToken` string field per user (`ProfileRepository.saveFcmToken`) — single-device only. I upgrade this to a `users/{uid}/fcmTokens/{token}` subcollection so multiple signed-in devices per person all get notified, and stale tokens can be deleted individually without clobbering a newer one. This is a small, backward-compatible change (old single-field writes are simply replaced). | testing checklist requires multi-device support |
| Android notification channel | Reused the **existing** channel (`moodify_default` / "Moodify") that `NotificationsService.init()` already creates, instead of introducing a second `peer_notifications` channel — one channel is simpler and matches what's already shipped. | `notifications_service.dart` |
| Backend language | **TypeScript**, Cloud Functions 2nd gen, Node 20 | your choice per requirements |

## Setup Checklist

1. Confirm the project is on the **Blaze (pay-as-you-go)** plan — required for any Cloud Function, even ones that stay inside the free tier.
2. `firebase init functions` in the project root (TypeScript, ESLint optional) if `functions/` doesn't exist yet; this repo doesn't have one.
3. `cd functions && npm install firebase-admin firebase-functions`.
4. Deploy Firestore Security Rules (below) so `moodifies` and `friendships` writes stay properly scoped — the Cloud Function bypasses rules (Admin SDK), but the client writes that create the trigger still need to be locked down.
5. Ship the Flutter changes: multi-token `ProfileRepository` methods + `NotificationsService` cleanup/removal hooks.
6. Deploy the function: `firebase deploy --only functions:onMoodifyCreated`.
7. Test end-to-end per the checklist below before removing the old single-`fcmToken` field.

## Flutter Implementation

### `lib/services/repositories/profile_repository.dart`

Replace the single-field `saveFcmToken` with subcollection-based methods (keep everything else in the file as-is):

```dart
  /// Saves this device's current FCM token under
  /// `users/{uid}/fcmTokens/{token}` (doc id = token itself, so re-saving
  /// the same token is a no-op merge rather than a duplicate). Replaces
  /// the old single `fcmToken` field so a person signed in on more than
  /// one device gets notified on all of them.
  Future<void> saveFcmToken({required String uid, required String token}) {
    return _db
        .doc(FirestorePaths.user(uid))
        .collection('fcmTokens')
        .doc(token)
        .set({'token': token, 'updatedAt': FieldValue.serverTimestamp()}, SetOptions(merge: true));
  }

  /// Removes one device's token — call on sign-out so a logged-out device
  /// stops receiving pushes meant for whoever signs in next.
  Future<void> removeFcmToken({required String uid, required String token}) {
    return _db.doc(FirestorePaths.user(uid)).collection('fcmTokens').doc(token).delete();
  }
```

Integration notes: nothing else in `ProfileRepository` needs to change. `FirestorePaths` doesn't need a new helper — `'fcmTokens'` is used directly here the same way `'moods'` is used inline for the existing `userMoods` path.

### `lib/services/notifications_service.dart`

Add sign-out cleanup and expose the current token so `AuthService`'s sign-out flow can call `removeFcmToken`. Add this method to `NotificationsService`:

```dart
  /// Current device's FCM token, if available — used by the sign-out
  /// flow to delete this device's token doc so a signed-out device isn't
  /// left in `users/{uid}/fcmTokens` forever.
  Future<String?> currentToken() => _messaging.getToken();
```

Wherever sign-out currently happens (`auth_service.dart` / wherever `FirebaseAuth.instance.signOut()` is called), add before it:

```dart
final token = await notificationsService.currentToken();
if (token != null) {
  await profileRepository.removeFcmToken(uid: currentUid, token: token);
}
await FirebaseAuth.instance.signOut();
```

Everything else in `notifications_service.dart` — channel setup, `_showForegroundPush`, `_handlePushTap`, `firebaseMessagingBackgroundHandler` — is already correct for this feature and needs no changes. The empty `firebaseMessagingBackgroundHandler` body is intentional: this function sends **notification** messages (has a `notification` block), which Android displays itself via the OS while the app is backgrounded or terminated, with no Dart code required.

## Firebase Backend Implementation

### `functions/src/index.ts`

```typescript
import { initializeApp } from "firebase-admin/app";
import { getFirestore, FieldValue } from "firebase-admin/firestore";
import { getMessaging } from "firebase-admin/messaging";
import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/v2";

initializeApp();
const db = getFirestore();

interface MoodifyDoc {
  authorUid: string;
  authorName: string;
  emoji: string;
  label: string;
  audienceUids: string[]; // [] = "all friends"
}

/**
 * Fires whenever MoodifyRepository.post() creates a moodifies/{id} doc.
 * Looks up the author's accepted friendships itself (source of truth),
 * intersects with audienceUids if the post targeted a subset, and pushes
 * a text+emoji notification to every recipient's registered devices.
 */
export const onMoodifyCreated = onDocumentCreated("moodifies/{moodifyId}", async (event) => {
  const snap = event.data;
  if (!snap) return;
  const moodify = snap.data() as MoodifyDoc;
  const { authorUid, authorName, emoji, label } = moodify;
  const audienceUids = moodify.audienceUids ?? [];

  // 1. Server-side authorization: read the real friendship docs for this
  //    author. Never trust a client-supplied recipient list on its own.
  const friendshipsSnap = await db
    .collection("friendships")
    .where("uids", "array-contains", authorUid)
    .where("status", "==", "accepted")
    .get();

  const acceptedFriendUids = friendshipsSnap.docs.map((doc) => {
    const uids: string[] = doc.data().uids;
    return uids.find((u) => u !== authorUid)!;
  });

  // 2. If the post targeted a subset of friends, intersect — never union.
  //    This means an attacker-controlled audienceUids can only narrow the
  //    recipient set, never expand it beyond real accepted friends.
  const recipients =
    audienceUids.length === 0
      ? acceptedFriendUids
      : acceptedFriendUids.filter((uid) => audienceUids.includes(uid));

  if (recipients.length === 0) {
    logger.info("No eligible recipients for moodify", { moodifyId: event.params.moodifyId });
    return;
  }

  // 3. Collect every device token for every recipient.
  const tokenDocs = await Promise.all(
    recipients.map((uid) => db.collection("users").doc(uid).collection("fcmTokens").get())
  );
  const tokenToUid = new Map<string, string>();
  tokenDocs.forEach((qs, i) => {
    qs.docs.forEach((d) => tokenToUid.set(d.id, recipients[i]));
  });
  const tokens = [...tokenToUid.keys()];
  if (tokens.length === 0) return;

  // 4. Text-only, emoji-friendly notification. Title/body are plain
  //    strings — Android renders the friend's own device emoji font, so
  //    make sure `emoji`/`label` came from the fixed mood set already
  //    validated client-side, not free text.
  const title = "Friend activity";
  const body = `${authorName} is feeling ${emoji} ${label}`;

  const response = await getMessaging().sendEachForMulticast({
    tokens,
    notification: { title, body },
    data: { route: "/friends" },
    android: { priority: "high", notification: { channelId: "moodify_default" } },
  });

  // 5. Clean up tokens FCM reports as dead/invalid so future sends don't
  //    keep paying (and failing) for them.
  const staleWrites: Promise<unknown>[] = [];
  response.responses.forEach((r, i) => {
    if (!r.success && isUnregistered(r.error?.code)) {
      const token = tokens[i];
      const uid = tokenToUid.get(token)!;
      staleWrites.push(db.collection("users").doc(uid).collection("fcmTokens").doc(token).delete());
    }
  });
  await Promise.all(staleWrites);

  logger.info("Sent moodify notifications", {
    moodifyId: event.params.moodifyId,
    successCount: response.successCount,
    failureCount: response.failureCount,
  });
});

function isUnregistered(code?: string): boolean {
  return code === "messaging/registration-token-not-registered" || code === "messaging/invalid-registration-token";
}
```

### `functions/package.json` (relevant excerpt)

```json
{
  "engines": { "node": "20" },
  "main": "lib/index.js",
  "dependencies": {
    "firebase-admin": "^12.0.0",
    "firebase-functions": "^5.0.0"
  }
}
```

Deployment:

```bash
cd functions
npm install
npm run build   # tsc, if using the default TS template
firebase deploy --only functions:onMoodifyCreated
```

No `FieldValue` import is actually needed above beyond token bookkeeping if you extend it later — remove the unused import if your linter flags it.

## Security Rules and Data Model

```text
// firestore.rules (excerpt)
match /databases/{database}/documents {

  match /users/{uid} {
    allow read: if request.auth != null;
    allow write: if request.auth != null && request.auth.uid == uid;

    match /fcmTokens/{token} {
      // Only the token's own owner ever writes/deletes it; the Cloud
      // Function uses the Admin SDK, which bypasses these rules entirely.
      allow read, write: if request.auth != null && request.auth.uid == uid;
    }
  }

  match /friendships/{friendshipId} {
    allow read: if request.auth != null && request.auth.uid in resource.data.uids;
    allow create: if request.auth != null
      && request.auth.uid in request.resource.data.uids
      && request.resource.data.status == 'pending';
    allow update, delete: if request.auth != null && request.auth.uid in resource.data.uids;
  }

  match /moodifies/{moodifyId} {
    allow read: if request.auth != null;
    // authorUid must match the caller — this is what makes the Cloud
    // Function's later "look up authorUid's real friendships" trustworthy;
    // a user can only ever post as themselves.
    allow create: if request.auth != null && request.auth.uid == request.resource.data.authorUid;
    allow update, delete: if false; // Moodifies are immutable/expire, not edited
  }
}
```

Document shapes referenced above (already established by the existing code, unchanged):

```text
/users/{uid}
  fcmTokens/{token}   { token: string, updatedAt: Timestamp }

/friendships/{sortedUidA_sortedUidB}
  { uids: [uidA, uidB], status: 'pending' | 'accepted', requestedBy, createdAt, acceptedAt?, seenBy }

/moodifies/{moodifyId}
  { authorUid, authorName, emoji, label, message, intent, audienceUids: string[], postedAt, expiresAt }
```

## Triggering the Notification

Nothing changes in `create_controller.dart` — the existing call already does everything needed to fire the function:

```dart
await _ref.read(moodifyRepositoryProvider).post(
  authorUid: uid,
  authorName: name,
  mood: selectedMood,
  message: message,
  intent: intent,
  audienceUids: audienceUids, // [] = all friends
);
```

The Firestore write this produces (`moodifies/{id}`) is exactly what `onMoodifyCreated` listens for — no extra client code, no direct call to the function.

## Testing Checklist

- Deny notification permission on a fresh install → confirm `requestPermission()` returns `false` and no crash occurs when a Moodify is posted for that user.
- Post a Moodify while a friend's app is in the **foreground** → banner shows via `_showForegroundPush`/`flutter_local_notifications`.
- Background the friend's app → OS displays the notification without the app process running Dart code.
- Fully terminate (swipe away) the friend's app → notification still arrives and tapping it launches the app and navigates (via `getInitialMessage()`).
- Rotate the FCM token (reinstall or clear app data) → confirm the old token doc is gone (or ignored on next send) and the new one receives future pushes.
- Uninstall the app without signing out → next send should get an `messaging/registration-token-not-registered` error and the function should delete that token doc.
- Post twice quickly (duplicate events) → each post is a distinct `moodifies` doc, so each fires its own notification by design; confirm that's the intended behavior for your product (no dedup needed unless you want it).
- Try to notify a non-friend by tampering with `audienceUids` (e.g. via an emulator/direct SDK call) → function's own `friendships` lookup should exclude them regardless of what the client sent.
- Post with emojis in `label`/`authorName` → confirm they render (device font dependent — some very new emoji may show as a fallback glyph on older Android versions).
- Sign in on two devices as the same friend → both should receive the push (multi-token subcollection).

## Troubleshooting

| Symptom | Likely cause |
|---|---|
| Function deploys but never triggers | Firestore trigger region mismatch, or `moodifies` writes are failing Security Rules before they commit — check the Firestore console's rules-denied log, not the function logs. |
| Notification never shows on a backgrounded device | The FCM payload lacks a top-level `notification` block (data-only messages don't auto-display) — this implementation always sends one, so check nothing downstream stripped it. |
| Notification shows but tapping does nothing | `data.route` isn't set, or `rootNavigatorKey.currentContext` is null because the app hadn't finished building yet on cold start from a terminated tap. |
| `messaging/registration-token-not-registered` immediately after a fresh install | Emulators without Google Play services, or the app was reinstalled and the old token doc wasn't cleaned up — harmless, the cleanup step above removes it after the first failed send. |
| Function silently does nothing for a valid friend | Composite index missing on `friendships` (`uids` array-contains + `status ==`) — Firestore's error will link directly to a "create index" URL the first time this query runs; the client already needs the same index for `FriendsRepository.watchFriends`, so it's likely already created. |
| Billing/deploy error: "Cloud Functions require the Blaze plan" | Project is still on Spark — upgrade to Blaze; the free tier (2M invocations/month, first 5GB egress) still applies, so cost stays effectively $0 at low/moderate Moodify volumes. FCM sends themselves are always free regardless of plan. |
