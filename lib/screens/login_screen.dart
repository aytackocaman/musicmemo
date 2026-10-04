import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:url_launcher/url_launcher.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../utils/app_dialogs.dart';
import '../services/deep_link_service.dart';
import '../widgets/game_button.dart';
import '../l10n/app_localizations.dart';
import '../utils/responsive.dart';
import '../widgets/animated_app_icon.dart';
import 'home_screen.dart';

const _kHasLoggedInBefore = 'has_logged_in_before';

const _kTermsUrl = 'https://musicmemo.app/terms';
const _kPrivacyUrl = 'https://musicmemo.app/privacy';

/// Height shared by the three "Sign in with ..." buttons.
///
/// Apple's official badge sizes its own label as height * 0.43, so all three
/// must share a height for their text to match: 44 renders the badge at ~19px.
/// 44 is also Apple's minimum tap target.
const double _kSocialButtonHeight = 44;

Future<void> _openLegalPage(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _nameController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true;
  bool _isFirstLaunch = true;
  bool _showEmailForm = false;
  String? _errorMessage;

  Future<void> _signInWithGoogle() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.signInWithGoogle();

    // Web: result is null — browser is redirecting to Google. Keep loading.
    if (result == null) return;

    setState(() => _isLoading = false);

    if (result.success) {
      await _markLoggedIn();
      if (mounted) {
        if (DeepLinkService.consumePendingInviteCode(context)) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (!result.wasCancelled) {
        setState(() => _errorMessage = _localizeAuthError(result));
      }
    }
  }

  @override
  void initState() {
    super.initState();
    _loadFirstLaunch();
  }

  Future<void> _loadFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _isFirstLaunch = !(prefs.getBool(_kHasLoggedInBefore) ?? false);
      });
    }
  }

  Future<void> _markLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kHasLoggedInBefore, true);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final AuthResult result;

    if (_isSignUp) {
      result = await AuthService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        displayName: _nameController.text.trim().isNotEmpty
            ? _nameController.text.trim()
            : null,
      );
    } else {
      result = await AuthService.signIn(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    }

    setState(() => _isLoading = false);

    if (result.success) {
      await _markLoggedIn();
      TextInput.finishAutofillContext();
      if (mounted) {
        if (DeepLinkService.consumePendingInviteCode(context)) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      setState(() => _errorMessage = _localizeAuthError(result));
    }
  }

  Future<void> _signInWithApple() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.signInWithApple();

    setState(() => _isLoading = false);

    if (result.success) {
      await _markLoggedIn();
      if (mounted) {
        if (DeepLinkService.consumePendingInviteCode(context)) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } else {
      if (!result.wasCancelled) {
        setState(() => _errorMessage = _localizeAuthError(result));
      }
    }
  }

  Future<void> _resetPassword() async {
    final l10n = AppLocalizations.of(context)!;
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = l10n.enterEmailToReset);
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final result = await AuthService.resetPassword(email);

    setState(() => _isLoading = false);

    if (result.success) {
      if (mounted) {
        showAppSnackBar(context, l10n.passwordResetSent);
      }
    } else {
      setState(() => _errorMessage = _localizeAuthError(result));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // Read the real keyboard height above the Scaffold. Once the body is laid
    // out, Scaffold has already consumed the bottom view inset for its own
    // resize, so reading MediaQuery inside the body would always yield 0.
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SingleChildScrollView(
                // Must stay scrollable while the email form is open. On short
                // devices (iPhone 13 mini) the software keyboard covers the
                // password field and the submit button, and without scrolling
                // there is no way to reach them.
                padding: EdgeInsets.only(
                  left: AppSpacing.xl,
                  right: AppSpacing.xl,
                  top: AppSpacing.xl,
                  // Headroom so the last field, the submit button and the
                  // forgot-password link can be scrolled clear of the keyboard.
                  bottom: AppSpacing.xl + keyboardInset,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 2 * AppSpacing.xl,
                  ),
                  child: ResponsiveBody(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Top section
                        Column(
                          children: [
                            const SizedBox(height: AppSpacing.xxl),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              // 200px pushed the actual controls below the
                              // fold on a 13 mini. Trimmed for breathing room.
                              width: _showEmailForm ? 96 : 140,
                              height: _showEmailForm ? 96 : 140,
                              child: AnimatedAppIcon(
                                size: _showEmailForm ? 96 : 140,
                              ),
                            ),
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 350),
                              curve: Curves.easeInOut,
                              height: _showEmailForm
                                  ? AppSpacing.xl
                                  : AppSpacing.xxl,
                            ),
                            Text(
                              _isFirstLaunch ? l10n.welcome : l10n.welcomeBack,
                              style: AppTypography.headline2(context),
                            ),
                            if (!_showEmailForm) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Text(
                                _isFirstLaunch
                                    ? l10n.createAccountSubtitle
                                    : l10n.signInSubtitle,
                                style: AppTypography.body(
                                  context,
                                ).copyWith(color: context.colors.textSecondary),
                              ),
                            ],
                          ],
                        ),
                        // Bottom section
                        Column(
                          children: [
                            if (_showEmailForm) ...[
                              _buildEmailForm(),
                            ] else ...[
                              _buildSocialButtons(),
                            ],
                            SizedBox(
                              height: _showEmailForm
                                  ? AppSpacing.sm
                                  : AppSpacing.xxl,
                            ),
                            Text(
                              l10n.byContinuing,
                              style: AppTypography.labelSmall(context),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                TextButton(
                                  onPressed: () => _openLegalPage(_kTermsUrl),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    l10n.termsOfService,
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                          color: context.colors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                                Text(
                                  l10n.andSeparator,
                                  style: AppTypography.labelSmall(context),
                                ),
                                TextButton(
                                  onPressed: () => _openLegalPage(_kPrivacyUrl),
                                  style: TextButton.styleFrom(
                                    padding: EdgeInsets.zero,
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  child: Text(
                                    l10n.privacyPolicy,
                                    style: AppTypography.labelSmall(context)
                                        .copyWith(
                                          color: context.colors.accent,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Render an auth failure in the active language.
  ///
  /// AuthService returns a stable [AuthErrorCode]; the raw message is only an
  /// English fallback for logging and for codes with no dedicated string.
  String _localizeAuthError(AuthResult result) {
    final l10n = AppLocalizations.of(context)!;
    return switch (result.code) {
      AuthErrorCode.signUpFailed => l10n.authSignUpFailed,
      AuthErrorCode.signInFailed => l10n.authSignInFailed,
      AuthErrorCode.invalidCredentials => l10n.authInvalidCredentials,
      AuthErrorCode.emailNotConfirmed => l10n.authEmailNotConfirmed,
      AuthErrorCode.userAlreadyRegistered => l10n.authUserAlreadyRegistered,
      AuthErrorCode.passwordTooShort => l10n.authPasswordTooShort,
      AuthErrorCode.invalidEmail => l10n.authInvalidEmail,
      AuthErrorCode.googleNoIdToken => l10n.authGoogleNoIdToken,
      AuthErrorCode.googleFailed => l10n.authGoogleFailed,
      AuthErrorCode.googleError => l10n.authGoogleError(
        result.errorMessage ?? '',
      ),
      AuthErrorCode.appleNoIdentityToken => l10n.authAppleNoIdentityToken,
      AuthErrorCode.appleFailed => l10n.authAppleFailed,
      AuthErrorCode.appleError => l10n.authAppleError(
        result.errorMessage ?? '',
      ),
      _ => result.errorMessage ?? l10n.authUnexpectedError,
    };
  }

  Widget _buildSocialButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _AppleSignInButton(
            onPressed: _isLoading ? () {} : _signInWithApple,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: _GoogleSignInButton(
            onPressed: _isLoading ? () {} : _signInWithGoogle,
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        const _SignInDivider(),
        const SizedBox(height: AppSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: _EmailSignInButton(
            onPressed: _isLoading
                ? () {}
                : () {
                    setState(() {
                      _showEmailForm = true;
                      _errorMessage = null;
                    });
                  },
          ),
        ),
      ],
    );
  }

  Widget _buildEmailForm() {
    final l10n = AppLocalizations.of(context)!;
    return Column(
      children: [
        // Tab switcher: Sign In / Sign Up
        Container(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
          padding: const EdgeInsets.all(4),
          child: Row(
            children: [
              _buildTab(l10n.signIn, !_isSignUp, isSignUp: false),
              _buildTab(l10n.signUp, _isSignUp, isSignUp: true),
            ],
          ),
        ),

        const SizedBox(height: AppSpacing.xl),

        // Form fields
        AutofillGroup(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                if (_isSignUp) ...[
                  _buildTextField(
                    controller: _nameController,
                    hint: l10n.displayNameOptional,
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    textCapitalization: TextCapitalization.words,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _buildTextField(
                  controller: _emailController,
                  hint: l10n.email,
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterEmail;
                    }
                    if (!value.contains('@')) return l10n.pleaseEnterValidEmail;
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _passwordController,
                  hint: l10n.password,
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
                  textInputAction: TextInputAction.done,
                  textCapitalization: TextCapitalization.none,
                  autocorrect: false,
                  enableSuggestions: false,
                  onFieldSubmitted: (_) {
                    // The keyboard's Done key signs in, same as the button.
                    FocusScope.of(context).unfocus();
                    if (!_isLoading) _submit();
                  },
                  autofillHints: _isSignUp
                      ? const [AutofillHints.newPassword]
                      : const [AutofillHints.password],
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: context.colors.textTertiary,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return l10n.pleaseEnterPassword;
                    }
                    if (_isSignUp && value.length < 6) {
                      return l10n.passwordMinLength;
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
        ),

        // Error message
        if (_errorMessage != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              // Tinted dark surface rather than a near-white block: the old
              // Colors.red.shade50 painted a glaring pink rectangle over the
              // #1C1C1E background on every mistyped password.
              color: AppColors.danger.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadius.card),
              border: Border.all(
                color: AppColors.danger.withValues(alpha: 0.32),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.error_outline, color: AppColors.danger, size: 18),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySmall(
                      context,
                    ).copyWith(color: AppColors.danger),
                  ),
                ),
              ],
            ),
          ),
        ],

        const SizedBox(height: AppSpacing.xl),

        // Submit button
        SizedBox(
          width: double.infinity,
          child: GameButton(
            label: _isLoading
                ? l10n.pleaseWait
                : (_isSignUp ? l10n.createAccount : l10n.signIn),
            icon: _isLoading ? null : Icons.arrow_forward,
            onPressed: _isLoading ? () {} : _submit,
          ),
        ),

        const SizedBox(height: AppSpacing.sm),

        // Forgot password
        if (!_isSignUp)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _isLoading ? null : _resetPassword,
              style: TextButton.styleFrom(
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                minimumSize: Size.zero,
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              ),
              child: Text(
                l10n.forgotPassword,
                style: AppTypography.bodySmall(
                  context,
                ).copyWith(color: context.colors.accent),
              ),
            ),
          ),

        const SizedBox(height: AppSpacing.sm),

        // Back to sign-in options
        TextButton(
          onPressed: _isLoading
              ? null
              : () {
                  setState(() {
                    _showEmailForm = false;
                    _isSignUp = false;
                    _errorMessage = null;
                  });
                },
          child: Text(
            '← ${l10n.otherSignInOptions}',
            style: AppTypography.bodySmall(
              context,
            ).copyWith(color: context.colors.textTertiary),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, bool active, {required bool isSignUp}) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading
            ? null
            : () {
                setState(() {
                  _isSignUp = isSignUp;
                  _errorMessage = null;
                });
              },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? AppColors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(AppRadius.button - 4),
            boxShadow: active
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.08),
                      blurRadius: 4,
                      offset: const Offset(0, 1),
                    ),
                  ]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label(context).copyWith(
              color: active
                  ? context.colors.accent
                  : context.colors.textTertiary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    Widget? suffixIcon,
    List<String>? autofillHints,
    String? Function(String?)? validator,
    TextInputAction? textInputAction,
    TextCapitalization textCapitalization = TextCapitalization.none,
    ValueChanged<String>? onFieldSubmitted,
    bool autocorrect = true,
    bool enableSuggestions = true,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      onFieldSubmitted: onFieldSubmitted,
      autocorrect: autocorrect,
      enableSuggestions: enableSuggestions,
      // Let the scroll view lift the focused field clear of the keyboard.
      scrollPadding: const EdgeInsets.symmetric(vertical: 96),
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body(
          context,
        ).copyWith(color: context.colors.textTertiary),
        prefixIcon: Icon(icon, color: context.colors.textTertiary),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: context.colors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: context.colors.accent, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: Colors.red.shade400, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.lg,
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: _kSocialButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          // Google's branding spec calls for a #DADCE0 outline on the white
          // button, not Material's grey.shade300.
          side: const BorderSide(color: Color(0xFFDADCE0)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const _GoogleG(),
            const SizedBox(width: 12),
            Text(
              l10n.signInWithGoogle,
              style: AppTypography.button(context).copyWith(
                fontWeight: FontWeight.w600,
                color: const Color(0xFF3C4043),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoogleG extends StatelessWidget {
  const _GoogleG();

  @override
  Widget build(BuildContext context) {
    return SvgPicture.asset(
      'assets/images/google_logo.svg',
      width: 20,
      height: 20,
    );
  }
}

/// Official Apple "Sign in with Apple" badge.
///
/// Apple requires the official badge whenever Apple sign-in is offered next to
/// other providers, and the logo must be drawn by the platform rather than
/// substituted with the U+F8FF private-use glyph — that glyph only exists in
/// Apple's system font and rendered as an empty box on web and Android.
/// Thin rule with a centered "OR", separating the one-tap providers from the
/// email option so the three buttons do not read as one undifferentiated stack.
class _SignInDivider extends StatelessWidget {
  const _SignInDivider();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final rule = Expanded(
      child: Container(height: 1, color: context.colors.elevated),
    );
    return Row(
      children: [
        rule,
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Text(l10n.or, style: AppTypography.labelSmall(context)),
        ),
        rule,
      ],
    );
  }
}

class _AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _AppleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Apple's badge derives its own font size from its height
    // (fontSize = height * 0.43) and exposes no text-size override, so height
    // is the only lever. At 56 it rendered 24px - larger than the primary CTA
    // and visually louder than it should be. 44 is Apple's own minimum tap
    // target and renders ~19px, matching the other two buttons at 18px.
    return SizedBox(
      width: double.infinity,
      height: _kSocialButtonHeight,
      child: SignInWithAppleButton(
        onPressed: onPressed,
        text: l10n.signInWithApple,
        height: _kSocialButtonHeight,
        // Match the rest of the app's button treatment rather than Apple's
        // default 8px radius.
        borderRadius: BorderRadius.circular(AppRadius.button),
        // The app is dark-only, so the white badge is always the right variant.
        style: isDark
            ? SignInWithAppleButtonStyle.white
            : SignInWithAppleButtonStyle.black,
      ),
    );
  }
}

class _EmailSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _EmailSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      height: _kSocialButtonHeight,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: context.colors.surface,
          side: BorderSide(color: context.colors.surface),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.email_outlined,
              size: 20,
              color: context.colors.textPrimary,
            ),
            const SizedBox(width: 12),
            Text(
              l10n.signInWithEmail,
              style: AppTypography.button(context).copyWith(
                fontWeight: FontWeight.w600,
                color: context.colors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
