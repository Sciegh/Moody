import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/avatar_photo_picker.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/detail_top_bar.dart';
import '../../core/widgets/mascot_blob.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../core/widgets/save_toast.dart';
import '../../services/auth_providers.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/profile_repository.dart';

/// Migration of account-details.html.
class AccountDetailsScreen extends ConsumerStatefulWidget {
  const AccountDetailsScreen({super.key});

  @override
  ConsumerState<AccountDetailsScreen> createState() => _AccountDetailsScreenState();
}

class _AccountDetailsScreenState extends ConsumerState<AccountDetailsScreen> {
  final _nameController = TextEditingController();
  final _handleController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  bool _saving = false;

  // Firestore is the source of truth once loaded; this just stops every
  // profile-doc update from clobbering text the user is mid-typing.
  //
  // Tracked separately from email population below. `authEmail` (from
  // Firebase Auth) is available synchronously on the very first build,
  // long before the Firestore `profile` stream's first snapshot arrives
  // over the network — so latching a single shared flag off of "either
  // one is non-null" fired immediately with name/handle still blank
  // (profile hadn't loaded yet), then never repopulated once the real
  // data actually arrived a moment later. That's why Name/Username
  // looked permanently empty here even though Firestore had the right
  // values the whole time.
  bool _profileFieldsPopulated = false;
  bool _emailPopulated = false;

  // Local preview of a newly picked photo, shown immediately while the
  // upload in _editAvatar is in flight. Once that upload finishes, the
  // profile doc's `photoUrl` (read below via profileStreamProvider) takes
  // over as the source of truth, so the photo now actually survives an
  // app restart instead of quietly reverting.
  File? _pickedPhoto;
  bool _uploadingPhoto = false;

  final _toast = SaveToastController();

  @override
  void dispose() {
    _nameController.dispose();
    _handleController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _toast.dispose();
    super.dispose();
  }

  void _populateIfNeeded(Map<String, dynamic>? profile, String? authEmail) {
    // Only latches once `profile` itself has actually loaded — not just
    // because `authEmail` (available instantly) is non-null. See the
    // field doc comments above for why this used to show permanently
    // blank Name/Username fields.
    if (!_profileFieldsPopulated && profile != null) {
      _profileFieldsPopulated = true;
      _nameController.text = profile['name'] as String? ?? '';
      _handleController.text = profile['handle'] as String? ?? '';
    }
    if (!_emailPopulated && authEmail != null) {
      _emailPopulated = true;
      _emailController.text = authEmail;
    } else if (!_emailPopulated && profile?['email'] != null) {
      _emailPopulated = true;
      _emailController.text = profile!['email'] as String;
    }
  }

  Future<void> _save(String uid) async {
    final name = _nameController.text.trim();
    final handle = _handleController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (name.isEmpty || handle.isEmpty) {
      _toast.show("Name and username can't be empty", duration: const Duration(milliseconds: 1800));
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(profileRepositoryProvider).updateProfile(uid: uid, name: name, handle: handle);

      final authService = ref.read(authServiceProvider);
      // Was comparing `email` to `_emailController.text` — but `email`
      // (line 91) IS `_emailController.text.trim()`, so this only ever
      // differed by whitespace and was otherwise always equal to itself.
      // updateEmail() never actually ran, so editing the email field and
      // hitting Save silently did nothing — the "profile not updating"
      // symptom for this field specifically. Compare against the actual
      // signed-in email instead, so a real change is detected.
      final currentEmail = _authEmail(authService);
      if (email.isNotEmpty && email != currentEmail) {
        await authService.updateEmail(email: email);
      }
      if (password.isNotEmpty) {
        await authService.updatePassword(password: password);
        _passwordController.clear();
      }

      if (!mounted) return;
      _toast.show('Saved ✓', duration: const Duration(milliseconds: 1600));
    } on AuthException catch (e) {
      if (!mounted) return;
      _toast.show(e.message, duration: const Duration(milliseconds: 2400));
    } catch (_) {
      if (!mounted) return;
      _toast.show("Couldn't save — check your connection and try again", duration: const Duration(milliseconds: 2400));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _editAvatar(String? uid) async {
    if (uid == null) return;
    final photo = await pickAvatarPhoto(context);
    if (photo == null || !mounted) return;
    setState(() {
      _pickedPhoto = photo;
      _uploadingPhoto = true;
    });
    try {
      // Actually persists it now — see ProfileRepository.uploadAvatar doc
      // comment. Previously this just set local state and showed a toast
      // that said "for this session," which was accurate but not what
      // anyone wanted: the photo reverted on next launch because nothing
      // was ever uploaded or saved to the profile doc.
      await ref.read(profileRepositoryProvider).uploadAvatar(uid: uid, file: photo);
      if (!mounted) return;
      _toast.show('Photo updated ✓', duration: const Duration(milliseconds: 1600));
    } catch (_) {
      if (!mounted) return;
      _toast.show("Couldn't upload photo — check your connection and try again", duration: const Duration(milliseconds: 2200));
    } finally {
      if (mounted) setState(() => _uploadingPhoto = false);
    }
  }

  Future<void> _deleteAccount(String uid) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete your account?'),
        content: const Text(
          "Are you sure? This will permanently delete your Moodify account and can't be undone.",
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref.read(profileRepositoryProvider).deleteProfileData(uid);
      await ref.read(authServiceProvider).deleteAccount();
      if (mounted) context.go('/login');
    } on AuthException catch (e) {
      if (!mounted) return;
      _toast.show(e.message, duration: const Duration(milliseconds: 2600));
    } catch (_) {
      if (!mounted) return;
      _toast.show("Couldn't delete your account — please try again", duration: const Duration(milliseconds: 2600));
    }
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
        child: Text(text, style: AppTextStyles.baloo(size: 13, weight: FontWeight.w700, color: AppColors.inkDim)),
      );

  @override
  Widget build(BuildContext context) {
    final authService = ref.watch(authServiceProvider);
    final uid = authService.currentUserId;
    final profile = uid == null ? null : ref.watch(profileStreamProvider(uid)).valueOrNull;
    _populateIfNeeded(profile, uid == null ? null : _authEmail(authService));
    final photoUrl = profile?['photoUrl'] as String?;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
          child: Stack(
            children: [
              Column(
                children: [
                  DetailTopBar(title: 'Account details', onBack: () => context.go('/profile')),
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Center(
                            child: Column(
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    _pickedPhoto != null
                                        ? CircleAvatar(radius: 40, backgroundImage: FileImage(_pickedPhoto!))
                                        : photoUrl != null
                                            ? CircleAvatar(radius: 40, backgroundImage: NetworkImage(photoUrl))
                                            : const MascotBlob(
                                                emoji: '🙂',
                                                size: 80,
                                                gradientColors: [Color(0xFFFFC1D2), AppColors.coral, AppColors.coralDark],
                                                motion: MascotMotion.bob,
                                              ),
                                    if (_uploadingPhoto)
                                      const Positioned.fill(
                                        child: CircularProgressIndicator(strokeWidth: 2.5),
                                      ),
                                    Positioned(
                                      bottom: -2,
                                      right: -2,
                                      child: CircleIconButton(
                                        size: 28,
                                        fontSize: 12,
                                        semanticLabel: 'Edit avatar',
                                        onPressed: () => _editAvatar(uid),
                                        child: const Text('✏️'),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Tap to change photo',
                                  style: AppTextStyles.quicksand(size: 11.5, weight: FontWeight.w700, color: AppColors.inkFaint),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 4),

                          _sectionTitle('Profile'),
                          PillTextField(label: 'Name', emoji: '✨', controller: _nameController),
                          const SizedBox(height: 12),
                          PillTextField(label: 'Username', emoji: '@', controller: _handleController),
                          const SizedBox(height: 12),
                          PillTextField(
                            label: 'Email',
                            emoji: '📧',
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                          ),

                          _sectionTitle('Password'),
                          PillTextField(
                            label: 'New password',
                            emoji: '🔒',
                            controller: _passwordController,
                            placeholder: 'Leave blank to keep current',
                            obscureText: _obscurePassword,
                            trailing: TextButton(
                              style: TextButton.styleFrom(
                                padding: EdgeInsets.zero,
                                minimumSize: const Size(0, 0),
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                              child: Text(
                                _obscurePassword ? 'Show' : 'Hide',
                                style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: AppColors.inkFaint),
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          PrimaryButton(
                            label: _saving ? 'Saving…' : 'Save changes',
                            onPressed: (uid == null || _saving) ? null : () => _save(uid),
                            color: AppColors.sky,
                            colorDark: AppColors.skyDark,
                          ),

                          Container(
                            margin: const EdgeInsets.only(top: 22),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFFE7E0),
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: const [BoxShadow(color: Color(0xFFF6C4B4), offset: Offset(0, 3))],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Delete account',
                                  style: AppTextStyles.baloo(size: 13.5, color: const Color(0xFFB4472A)),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "This permanently deletes your Moodify account, moods, and friends. This can't be undone.",
                                  style: AppTextStyles.quicksand(
                                    size: 11.5,
                                    weight: FontWeight.w600,
                                    color: const Color(0xFFB4472A),
                                    height: 1.4,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: TextButton(
                                    style: TextButton.styleFrom(
                                      backgroundColor: const Color(0xFFE0573B),
                                      padding: const EdgeInsets.symmetric(vertical: 11),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                    onPressed: uid == null ? null : () => _deleteAccount(uid),
                                    child: Text(
                                      'Delete my account',
                                      style: AppTextStyles.quicksand(size: 13, weight: FontWeight.w800, color: Colors.white),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SaveToast(controller: _toast),
            ],
          ),
        )
    );
  }

  /// [AuthService] only exposes uid/displayName, not email — that's fine
  /// for `FirebaseAuthService` where we can reach the real `email` field
  /// directly; the interface wasn't widened for just this one field since
  /// nothing else in the app needs it.
  String? _authEmail(AuthService service) {
    if (service is FirebaseAuthService) return service.currentUserEmail;
    return null;
  }
}