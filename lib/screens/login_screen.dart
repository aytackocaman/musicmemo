import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../config/theme.dart';
import '../services/auth_service.dart';
import '../utils/app_dialogs.dart';
import '../services/deep_link_service.dart';
import '../widgets/game_button.dart';
import 'home_screen.dart';

const _kHasLoggedInBefore = 'has_logged_in_before';

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
      if (result.errorMessage != 'Sign-in cancelled.') {
        setState(() => _errorMessage = result.errorMessage);
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
      setState(() => _errorMessage = result.errorMessage);
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
      if (result.errorMessage != 'Sign-in cancelled.') {
        setState(() => _errorMessage = result.errorMessage);
      }
    }
  }

  Future<void> _resetPassword() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Enter your email to reset password.');
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
        showAppSnackBar(context, 'Password reset email sent!');
      }
    } else {
      setState(() => _errorMessage = result.errorMessage);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: Column(
              children: [
                const SizedBox(height: AppSpacing.xxl),

                // Decorative dots
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildDot(AppColors.purple),
                    const SizedBox(width: 8),
                    _buildDot(AppColors.teal),
                    const SizedBox(width: 8),
                    _buildDot(AppColors.pink),
                  ],
                ),
                const SizedBox(height: AppSpacing.xxl),

                // Logo
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.purple,
                    borderRadius: BorderRadius.circular(28),
                  ),
                  child: const Icon(
                    Icons.music_note,
                    size: 48,
                    color: AppColors.white,
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),

                // Title
                Text(
                  _isFirstLaunch ? 'Welcome!' : 'Welcome Back',
                  style: AppTypography.headline2(context),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  _isFirstLaunch
                      ? 'Create an account or sign in to start playing'
                      : 'Sign in to continue playing',
                  style: AppTypography.body(context).copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
                const SizedBox(height: AppSpacing.xxl),

                if (_showEmailForm) ...[
                  _buildEmailForm(),
                ] else ...[
                  _buildSocialButtons(),
                ],

                const SizedBox(height: AppSpacing.xxl),

                // Terms
                Text(
                  'By continuing, you agree to our',
                  style: AppTypography.labelSmall(context),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Terms of Service',
                        style: AppTypography.labelSmall(context).copyWith(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    Text(' & ', style: AppTypography.labelSmall(context)),
                    TextButton(
                      onPressed: () {},
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(
                        'Privacy Policy',
                        style: AppTypography.labelSmall(context).copyWith(
                          color: AppColors.purple,
                          fontWeight: FontWeight.w600,
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

  Widget _buildSocialButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: _AppleSignInButton(
            onPressed: _isLoading ? null : _signInWithApple,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: _GoogleSignInButton(
            onPressed: _isLoading ? null : _signInWithGoogle,
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        SizedBox(
          width: double.infinity,
          child: _EmailSignInButton(
            onPressed: _isLoading ? null : () {
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
              _buildTab('Sign In', !_isSignUp),
              _buildTab('Sign Up', _isSignUp),
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
                    hint: 'Display Name (optional)',
                    icon: Icons.person_outline,
                  ),
                  const SizedBox(height: AppSpacing.lg),
                ],
                _buildTextField(
                  controller: _emailController,
                  hint: 'Email',
                  icon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your email';
                    if (!value.contains('@')) return 'Please enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: AppSpacing.lg),
                _buildTextField(
                  controller: _passwordController,
                  hint: 'Password',
                  icon: Icons.lock_outline,
                  obscureText: _obscurePassword,
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
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) return 'Please enter your password';
                    if (_isSignUp && value.length < 6) return 'Password must be at least 6 characters';
                    return null;
                  },
                ),
                if (!_isSignUp) ...[
                  const SizedBox(height: AppSpacing.sm),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: _isLoading ? null : _resetPassword,
                      child: Text(
                        'Forgot Password?',
                        style: AppTypography.bodySmall(context).copyWith(
                          color: AppColors.purple,
                        ),
                      ),
                    ),
                  ),
                ],
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
              color: Colors.red.shade50,
              borderRadius: BorderRadius.circular(AppRadius.card),
            ),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: Colors.red.shade700, size: 20),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    _errorMessage!,
                    style: AppTypography.bodySmall(context).copyWith(
                      color: Colors.red.shade700,
                    ),
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
                ? 'Please wait...'
                : (_isSignUp ? 'Create Account' : 'Sign In'),
            icon: _isLoading ? null : Icons.arrow_forward,
            onPressed: _isLoading ? () {} : _submit,
          ),
        ),

        const SizedBox(height: AppSpacing.lg),

        // Back to sign-in options
        TextButton(
          onPressed: _isLoading ? null : () {
            setState(() {
              _showEmailForm = false;
              _isSignUp = false;
              _errorMessage = null;
            });
          },
          child: Text(
            '← Other sign-in options',
            style: AppTypography.bodySmall(context).copyWith(
              color: context.colors.textTertiary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTab(String label, bool active) {
    return Expanded(
      child: GestureDetector(
        onTap: _isLoading ? null : () {
          setState(() {
            _isSignUp = label == 'Sign Up';
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
                ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 4, offset: const Offset(0, 1))]
                : null,
          ),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: AppTypography.label(context).copyWith(
              color: active ? AppColors.purple : context.colors.textTertiary,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDot(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
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
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
      autofillHints: autofillHints,
      validator: validator,
      style: AppTypography.body(context),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body(context).copyWith(
          color: context.colors.textTertiary,
        ),
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
          borderSide: const BorderSide(color: AppColors.purple, width: 2),
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
    return SizedBox(
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          side: BorderSide(color: Colors.grey.shade300),
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
              'Sign in with Google',
              style: AppTypography.body(context).copyWith(
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

class _AppleSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _AppleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? Colors.white : const Color(0xFF1C1C1E);
    final fgColor = isDark ? const Color(0xFF1C1C1E) : Colors.white;

    return SizedBox(
      height: 56,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bgColor,
          foregroundColor: fgColor,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              '\uF8FF',
              style: TextStyle(fontSize: 20, color: fgColor, height: 1.1),
            ),
            const SizedBox(width: 12),
            Text(
              'Sign in with Apple',
              style: AppTypography.body(context).copyWith(
                fontWeight: FontWeight.w600,
                color: fgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmailSignInButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _EmailSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 56,
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
            Icon(Icons.email_outlined, size: 20, color: context.colors.textPrimary),
            const SizedBox(width: 12),
            Text(
              'Sign in with Email',
              style: AppTypography.body(context).copyWith(
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
