# Moodify — Flutter migration notes

Status: **10 of 10 screens migrated.** All source `.html` files have a
Flutter equivalent wired into the router.

## Run instructions

```bash
flutter pub get
flutter run
```

The app boots on `/login`. Login/Register have no real validation (see
Assumptions) — any input, or none, takes you to `/profile`.

There is no `pubspec.yaml` asset/font setup required: Baloo 2 and Quicksand
are fetched at runtime via `google_fonts`, mirroring the source's
`@import` from Google Fonts. This means **the app needs network access on
first run** to render the correct typefaces (it falls back to the system
font otherwise). For release builds, consider bundling the fonts as assets
instead — see the note in `lib/core/theme/app_text_theme.dart`.

`url_launcher` (used by the "Email us" button on Help & support) needs no
extra platform config for `mailto:` links on Android/iOS.

## Source-to-Flutter mapping (high level)

| Source element | Flutter equivalent | Notes |
|---|---|---|
| `.app-frame` / `.status-bar` (phone-mockup bezel) | *(omitted)* | Browser-preview artifact; a real Flutter app already runs full-screen — `Scaffold` + `SafeArea` is the direct equivalent. |
| `body` radial-gradient + `color-mix` | `MoodBackground` | Two soft blobs via `Alignment` + `RadialGradient`, since `BoxDecoration` only takes one gradient. |
| `--accent` / `--accent-light` rewritten by JS | Riverpod `ProfileController` state | Profile's mood-strip tap re-themes the screen; static screens (Notifications/Privacy/etc.) just seed from that screen's fixed `:root` accent. |
| `.primary-btn` / `.save-btn` (3D press button) | `PrimaryButton` | `AnimatedContainer` + `Matrix4.translationValues` for the press-down, swapped `boxShadow` list for the collapsed shadow. |
| `.field-input` | `PillTextField` | Focus-driven shadow-color swap instead of a Material outline. |
| `.toggle` / `.slider` | `AppToggle` | Custom pill switch — Material's `Switch` doesn't match the flat/inset look. |
| `.mascot` / `.avatar-big` (organic blob) | `MascotBlob` | CSS's independent per-corner elliptical radius approximated via `BorderRadius.only(Radius.elliptical(...))`; the `bob`/`wiggle`/`sway` keyframe animations approximated with an `AnimationController` driving small rotate/translate. |
| `.save-toast` / `.toast` | `SaveToastController` + `SaveToast` | Positioned + `AnimatedOpacity`/`AnimatedSlide`, not a `SnackBar` (source toast persists mid-screen, offset per page). |
| `.tabbar` | `AppTabBar` | Rebuilt per-screen (matches source repeating the same `<nav>` on every page) rather than a `go_router` `ShellRoute` — see TODO in the file once Create/Friends/Profile are all real. |
| `<script>` mocked arrays (`FRIENDS`, `RECENT`, `FAQS`, etc.) | `lib/models/*.dart` `const` lists | Marked `TODO(firebase)` — replace with real Firestore-backed data. |
| `const MOODS = [...]` (51 entries) | `lib/models/mood_option.dart` `kAllMoods` | Parsed programmatically from the source `<script>` to avoid transcription errors — every id/emoji/label/family/accent/onAccent/desc/messages/intent carried over 1:1. |
| `.orb.family-*` blob keyframe animations | `MoodOrb` | Scale/rotate/translate motion approximated per family; the source's per-family asymmetric `border-radius` morphing is **not** reproduced — see the limitation below. |
| `shade(hex, amt)` (JS color lighten/darken helper) | `shade()` in `create_controller.dart` | Same lighten-toward-white / darken-toward-black math, using `Color.lerp`. |
| `localStorage.getItem('moodify_deluxe_unlocked')` | In-memory `ComposerState.deluxeUnlocked` | Resets on app restart — flagged `TODO(iap)`, see Limitations. |
| `#successOverlay` + `burstConfetti()` | `SuccessOverlay` | 26 animated rect pieces with randomized size/color/timing, matching the source's spawn loop. |
| `.dev-panel` ("prototype controls — not part of the app UI") | `_DevPanel` in `moodify_create_screen.dart`, gated by `kDebugMode` | Same purpose (manually testing offline/error states), but never compiled into a release build — the source explicitly disclaims it as non-product UI. |

## Assumptions made (no source behavior existed to migrate)

- **No client-side validation** on Login/Register/Account details forms —
  the source HTML has `novalidate` and submit handlers that redirect
  unconditionally. Preserved as-is; add real validation when the product
  wants it.
- **State management: Riverpod**, scoped mainly to `ProfileController`
  (the one screen with cross-widget shared state). Other screens use
  plain `setState` since their state genuinely is local — introducing
  providers there would be overengineering for what's there today.
- **Navigation: `go_router`**, using path names that mirror the source
  filenames.
- Privacy's "Blocked accounts" row still links to Add Friends
  (`/add-friend`), matching the source's literal
  `href="add-friend.html"` — this reads like a placeholder link in the
  original mockup rather than intentional; flagging it rather than
  "fixing" it, since a blocked-accounts screen doesn't exist in the
  supplied source.
- Avatar "edit" (Profile, Account details) and the photo picker just show
  a placeholder dialog, matching the source's `alert('Photo picker would
  open here.')`.

## Firebase / secure storage / notifications

Per the "pure UI migration" scope: **none of these are implemented.**
- `lib/services/auth_service.dart` — interface + a `FakeAuthService` that
  just simulates latency, so loading states are exercisable.
- `lib/services/secure_storage_service.dart` — interface only, with a
  commented reference implementation. Nothing currently calls it — the
  source has no persisted "remember me" or session logic to migrate.
- No Firestore models exist yet; every mocked list (`kMockFriends`,
  `kMockRecentMoods`, `kMockStreak`, FAQs) is `const` data lifted directly
  from the source `<script>` blocks, each commented `TODO(firebase)`.

## Validation checklist

- [ ] `flutter analyze` — not run in this environment (no Dart SDK
      available here); brackets/imports were checked by hand — run this
      yourself before merging.
- [ ] `flutter run` on both Android and iOS simulators — verify Baloo 2 /
      Quicksand load correctly (needs network on first launch).
- [ ] Visual pass against each source `.html` file side-by-side, especially:
      shadow depth/offset on pressed buttons, gradient direction on the
      body background, mascot blob asymmetry.
- [ ] Interaction states: button press-down, toggle on/off + master-toggle
      disabling sub-toggles (Notifications), FAQ accordion open/close
      (Help & support), search filtering (Friends, Add friends, Help),
      accept/decline requests + add suggestion (Add friends), ack toggle
      (Friends list), streak bottom sheet, mood grid selection + filter
      chips + paywall purchase flow + audience sheet + post/error/offline/
      success states (Create).
- [ ] Accessibility: `Semantics` labels are set on icon-only buttons;
      verify TalkBack/VoiceOver reads them sensibly; confirm tap targets
      are ≥44dp (icon buttons are 38–54dp depending on screen, matching
      source `px` sizes 1:1 — check against your target's minimum).
- [ ] Responsiveness: all screens use `SingleChildScrollView` +
      percentage/flex layout rather than the source's fixed 390×844
      frame, so verify on a couple of different device widths/heights.

## Limitations & next steps

- **`MoodOrb`'s per-family blob morphing is approximated, not exact.** The
  source animates each family's `border-radius` through several keyframe
  shapes in addition to scale/rotate/translate; this migration only
  reproduces the scale/rotate/translate motion, keeping the asymmetric
  base shape static. Side-by-side, the calm/energetic/heavy/anxious/social
  orbs will feel similar in spirit but not pixel-identical to the CSS
  keyframes.
- **Deluxe-unlock purchase state is in-memory only** (`ComposerState.deluxeUnlocked`),
  matching the source's `localStorage` flag in spirit but not durability —
  it resets on app restart. Before shipping, this needs a real purchase
  flow (App Store/Play Billing) with server-side entitlement storage, per
  the `TODO(iap)` comments in `create_controller.dart`.
- `AppTabBar` is duplicated across Profile/Friends/Add-friend/Create rather
  than hoisted into a `go_router` `ShellRoute` — worth doing now that all
  four destinations are real screens, so the bar persists across tab
  switches instead of rebuilding each time.
- CSS `color-mix()` (used throughout for the accent-tinted background,
  frame gradient, and tab bar tint) has no direct Flutter equivalent;
  every instance is approximated with `Color.lerp` or a two-blob radial
  gradient. Side-by-side comparison against the HTML will show minor color
  differences, especially at low mix percentages.
- The source's unlock-banner copy says "Unlock 8 Deluxe moods" but the
  actual `MOODS` data has 16 entries marked `premium:true` — this
  discrepancy exists in the source content itself and was carried over
  as-is rather than "corrected," since it wasn't clear which number was
  intended to be authoritative.
- No automated widget/golden tests were written in this pass.
