import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/mascot_blob.dart';
import '../../core/widgets/mood_background.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_providers.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/profile_repository.dart';

/// Migration of Register.html. See [LoginScreen] doc comment re: the
/// `.app-frame` phone bezel not being carried over.
class RegisterScreen extends ConsumerStatefulWidget {
  const RegisterScreen({super.key});

  @override
  ConsumerState<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends ConsumerState<RegisterScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _agreedToTerms = false;
  bool _submitting = false;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Was "source form is `novalidate`... redirects unconditionally,
    // including the terms checkbox" — same cute-warning treatment as
    // Login now applies here for every required field plus the checkbox.
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty || email.isEmpty || password.isEmpty || confirmPassword.isEmpty) {
      await showCuteWarning(
        context,
        emoji: '🙈',
        title: 'Almost there!',
        message: 'Fill in your name, email, and password to create your account.',
      );
      return;
    }
    if (password != confirmPassword) {
      await showCuteWarning(
        context,
        emoji: '🔒',
        title: "Those don't match",
        message: 'Double-check your password and confirmation — they need to be identical.',
      );
      return;
    }
    if (!_agreedToTerms) {
      await showCuteWarning(
        context,
        emoji: '📄',
        title: 'One more thing',
        message: "You'll need to agree to the Terms of Service and Privacy Policy first.",
      );
      return;
    }

    // Captured up front, not re-read via `ref` after the awaits below.
    // The moment register() creates the Firebase Auth user, app_router's
    // `redirect` (wired to authStateChanges()) fires and immediately
    // navigates /register -> /profile, unmounting this screen. If we
    // called `ref.read(...)` again after that point it would throw
    // (ref used on a disposed widget), silently aborting
    // ensureProfileDocument — which is why the profile doc's name/handle
    // never actually got written, leaving Profile showing blank name and
    // username after registering. Holding these references from before
    // the race means ensureProfileDocument still runs to completion even
    // if the router has already navigated away underneath us.
    final authService = ref.read(authServiceProvider);
    final profileRepo = ref.read(profileRepositoryProvider);

    setState(() => _submitting = true);
    try {
      await authService.register(
        name: name,
        email: email,
        password: _passwordController.text,
      );
      // The doc this screen (and every other screen reading
      // profileStreamProvider) depends on doesn't exist until we create
      // it — register() only creates the Firebase Auth user, nothing in
      // Firestore. See ProfileRepository.ensureProfileDocument doc comment.
      final uid = authService.currentUserId;
      if (uid != null) {
        await profileRepo.ensureProfileDocument(
          uid: uid,
          name: name,
          email: email,
        );
      }
      if (!mounted) return;
      context.go('/profile');
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _showTermsPlaceholder() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Moodify's Terms of Service would open here.")),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MoodBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 6, 26, 26),
            child: Column(
              children: [
                const SizedBox(height: 2),
                const Center(
                  child: MascotBlob(
                    emoji: '🎈',
                    size: 96,
                    gradientColors: [Color(0xFFFFF0B0), AppColors.marigold, Color(0xFFE89E1F)],
                    motion: MascotMotion.wiggle,
                  ),
                ),
                const SizedBox(height: 6),
                Text("Let's get you set up!", style: AppTextStyles.baloo(size: 23)),
                const SizedBox(height: 4),
                Text(
                  'Takes less than a minute, promise',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.quicksand(
                    size: 13,
                    weight: FontWeight.w600,
                    color: AppColors.inkDim,
                  ),
                ),
                const SizedBox(height: 18),

                PillTextField(
                  label: 'Name',
                  emoji: '✨',
                  controller: _nameController,
                  placeholder: 'What should friends call you?',
                ),
                const SizedBox(height: 12),
                PillTextField(
                  label: 'Email',
                  emoji: '📧',
                  controller: _emailController,
                  placeholder: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),
                PillTextField(
                  label: 'Password',
                  emoji: '🔒',
                  controller: _passwordController,
                  placeholder: 'Create a password',
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.newPassword],
                  trailing: _ShowHideToggle(
                    obscured: _obscurePassword,
                    onToggle: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                const SizedBox(height: 12),
                PillTextField(
                  label: 'Confirm password',
                  emoji: '🔒',
                  controller: _confirmPasswordController,
                  placeholder: 'Type it again',
                  obscureText: _obscureConfirmPassword,
                  autofillHints: const [AutofillHints.newPassword],
                  trailing: _ShowHideToggle(
                    obscured: _obscureConfirmPassword,
                    onToggle: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: 15,
                        height: 15,
                        child: Checkbox(
                          value: _agreedToTerms,
                          onChanged: (v) => setState(() => _agreedToTerms = v ?? false),
                          activeColor: AppColors.coral,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          visualDensity: VisualDensity.compact,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.quicksand(
                              size: 11.5,
                              weight: FontWeight.w600,
                              color: AppColors.inkDim,
                              height: 1.4,
                            ),
                            children: [
                              const TextSpan(text: "I agree to Moodify's "),
                              TextSpan(
                                text: 'Terms of Service',
                                style: const TextStyle(
                                  color: AppColors.coralDark,
                                  fontWeight: FontWeight.w800,
                                ),
                                recognizer: TapGestureRecognizer()..onTap = _showTermsPlaceholder,
                              ),
                              const TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: const TextStyle(
                                  color: AppColors.coralDark,
                                  fontWeight: FontWeight.w800,
                                ),
                                recognizer: TapGestureRecognizer()..onTap = () => context.go('/privacy'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                PrimaryButton(
                  label: _submitting ? 'Creating account…' : 'Create my account 🎉',
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: 6),

                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'Already have an account? ',
                      style: AppTextStyles.quicksand(
                        size: 12.5,
                        weight: FontWeight.w600,
                        color: AppColors.inkDim,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/login'),
                      child: Text(
                        'Log in',
                        style: AppTextStyles.quicksand(
                          size: 12.5,
                          weight: FontWeight.w800,
                          color: AppColors.coralDark,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ShowHideToggle extends StatelessWidget {
  const _ShowHideToggle({required this.obscured, required this.onToggle});

  final bool obscured;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    return TextButton(
      style: TextButton.styleFrom(
        padding: EdgeInsets.zero,
        minimumSize: const Size(0, 0),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      onPressed: onToggle,
      child: Text(
        obscured ? 'Show' : 'Hide',
        style: AppTextStyles.quicksand(size: 12, weight: FontWeight.w700, color: AppColors.inkFaint),
      ),
    );
  }
}