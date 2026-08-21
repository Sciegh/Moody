import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_theme.dart';
import '../../core/widgets/circle_icon_button.dart';
import '../../core/widgets/cute_warning.dart';
import '../../core/widgets/mascot_blob.dart';
import '../../core/widgets/mood_background.dart';
import '../../core/widgets/pill_text_field.dart';
import '../../core/widgets/primary_button.dart';
import '../../services/auth_providers.dart';
import '../../services/auth_service.dart';
import '../../services/repositories/profile_repository.dart';

/// Migration of Login.html.
///
/// Not carried over: the `.app-frame`/`.status-bar` phone-mockup bezel —
/// that's the HTML file simulating a phone inside a desktop browser for
/// preview purposes. A real Flutter app already runs full-screen on a
/// device, so [Scaffold] + [SafeArea] is the direct equivalent of what the
/// bezel was standing in for.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _submitting = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    // Was previously "the source form has `novalidate`... no validation
    // before redirecting" — now Login stops and asks nicely for anything
    // missing before hitting Firebase, instead of trying to log in blank.
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    if (email.isEmpty || password.isEmpty) {
      await showCuteWarning(
        context,
        emoji: '🙈',
        title: 'Almost there!',
        message: email.isEmpty && password.isEmpty
            ? 'Pop in your email and password to log in.'
            : email.isEmpty
                ? "Don't forget your email."
                : "Don't forget your password.",
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      await ref.read(authServiceProvider).login(
            email: email,
            password: _passwordController.text,
          );
      // Defensive: covers an account that predates the profile-document
      // change (registered before ensureProfileDocument existed). No-ops
      // if the doc is already there — see ProfileRepository doc comment.
      final uid = ref.read(authServiceProvider).currentUserId;
      if (uid != null) {
        await ref.read(profileRepositoryProvider).ensureProfileDocument(
              uid: uid,
              name: ref.read(authServiceProvider).currentUserName ?? 'You',
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

  void _forgotPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      // Same cute-warning logic as every other button on this screen,
      // instead of the plain SnackBar this used to show.
      showCuteWarning(
        context,
        emoji: '🙈',
        title: 'Almost there!',
        message: 'Enter your email above first, then tap this to get a reset link.',
      );
      return;
    }
    try {
      await ref.read(authServiceProvider).sendPasswordReset(email: email);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('A password reset link would be sent to $email.')),
      );
    } on AuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.message)));
    }
  }

  void _continueWithSocial(String provider) {
    // Source behavior: every social button just redirects straight to
    // profile.html with no real auth. Preserved as-is.
    context.go('/profile');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: MoodBackground(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 10, 28, 30),
            child: Column(
              children: [
                const SizedBox(height: 8),
                const Center(
                  child: MascotBlob(
                    emoji: '🙂',
                    size: 120,
                    gradientColors: [Color(0xFFFFC1D2), AppColors.coral, AppColors.coralDark],
                    motion: MascotMotion.bob,
                  ),
                ),
                const SizedBox(height: 18),
                Text('Welcome back!', style: AppTextStyles.baloo(size: 26)),
                const SizedBox(height: 4),
                Text(
                  'Log in to see how your friends are feeling today',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.quicksand(
                    size: 13.5,
                    weight: FontWeight.w600,
                    color: AppColors.inkDim,
                  ),
                ),
                const SizedBox(height: 24),

                PillTextField(
                  label: 'Email',
                  emoji: '📧',
                  controller: _emailController,
                  placeholder: 'you@example.com',
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 14),
                PillTextField(
                  label: 'Password',
                  emoji: '🔒',
                  controller: _passwordController,
                  placeholder: 'Your password',
                  obscureText: _obscurePassword,
                  autofillHints: const [AutofillHints.password],
                  trailing: TextButton(
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: const Size(0, 0),
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                    child: Text(
                      _obscurePassword ? 'Show' : 'Hide',
                      style: AppTextStyles.quicksand(
                        size: 13,
                        weight: FontWeight.w700,
                        color: AppColors.inkFaint,
                      ),
                    ),
                  ),
                ),

                Padding(
                  padding: const EdgeInsets.only(top: 2, bottom: 22),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      InkWell(
                        onTap: () => setState(() => _rememberMe = !_rememberMe),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 15,
                              height: 15,
                              child: Checkbox(
                                value: _rememberMe,
                                onChanged: (v) => setState(() => _rememberMe = v ?? false),
                                activeColor: AppColors.coral,
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                visualDensity: VisualDensity.compact,
                              ),
                            ),
                            const SizedBox(width: 7),
                            Text(
                              'Remember me',
                              style: AppTextStyles.quicksand(
                                size: 12.5,
                                weight: FontWeight.w600,
                                color: AppColors.inkDim,
                              ),
                            ),
                          ],
                        ),
                      ),
                      TextButton(
                        style: TextButton.styleFrom(padding: EdgeInsets.zero),
                        onPressed: _forgotPassword,
                        child: Text(
                          'Forgot password?',
                          style: AppTextStyles.quicksand(
                            size: 12.5,
                            weight: FontWeight.w700,
                            color: AppColors.coralDark,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                PrimaryButton(
                  label: _submitting ? 'Logging in…' : 'Log in 👋',
                  onPressed: _submitting ? null : _submit,
                ),
                const SizedBox(height: 6),

                Row(
                  children: [
                    const Expanded(child: Divider(color: AppColors.line, thickness: 2)),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'or continue with',
                        style: AppTextStyles.quicksand(
                          size: 11.5,
                          weight: FontWeight.w700,
                          color: AppColors.inkFaint,
                        ),
                      ),
                    ),
                    const Expanded(child: Divider(color: AppColors.line, thickness: 2)),
                  ],
                ),
                const SizedBox(height: 18),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleIconButton(
                      size: 54,
                      fontSize: 20,
                      semanticLabel: 'Continue with Google',
                      onPressed: () => _continueWithSocial('google'),
                      child: const Text('🅶'),
                    ),
                    const SizedBox(width: 12),
                    CircleIconButton(
                      size: 54,
                      fontSize: 20,
                      semanticLabel: 'Continue with Apple',
                      onPressed: () => _continueWithSocial('apple'),
                      child: const Text('🍎'),
                    ),
                    const SizedBox(width: 12),
                    CircleIconButton(
                      size: 54,
                      fontSize: 20,
                      semanticLabel: 'Continue with Facebook',
                      onPressed: () => _continueWithSocial('facebook'),
                      child: const Text('🅵'),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                Wrap(
                  alignment: WrapAlignment.center,
                  children: [
                    Text(
                      'New to Moodify? ',
                      style: AppTextStyles.quicksand(
                        size: 13,
                        weight: FontWeight.w600,
                        color: AppColors.inkDim,
                      ),
                    ),
                    GestureDetector(
                      onTap: () => context.go('/register'),
                      child: Text(
                        'Create an account',
                        style: AppTextStyles.quicksand(
                          size: 13,
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