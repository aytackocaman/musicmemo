import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
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
  String? _errorMessage;

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

  void _toggleMode() {
    setState(() {
      _isSignUp = !_isSignUp;
      _errorMessage = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colors.background,
      body: SafeArea(
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
                _isSignUp
                    ? 'Create Account'
                    : (_isFirstLaunch ? 'Welcome!' : 'Welcome Back'),
                style: AppTypography.headline2(context),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                _isSignUp
                    ? 'Sign up to save your progress'
                    : (_isFirstLaunch
                        ? 'Create an account or sign in to start playing'
                        : 'Sign in to continue playing'),
                style: AppTypography.body(context).copyWith(
                  color: context.colors.textSecondary,
                ),
              ),
              const SizedBox(height: AppSpacing.xxl),

              // Form
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    // Name field (sign up only)
                    if (_isSignUp) ...[
                      _buildTextField(
                        controller: _nameController,
                        hint: 'Display Name (optional)',
                        icon: Icons.person_outline,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],

                    // Email field
                    _buildTextField(
                      controller: _emailController,
                      hint: 'Email',
                      icon: Icons.email_outlined,
                      keyboardType: TextInputType.emailAddress,
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your email';
                        }
                        if (!value.contains('@')) {
                          return 'Please enter a valid email';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: AppSpacing.lg),

                    // Password field
                    _buildTextField(
                      controller: _passwordController,
                      hint: 'Password',
                      icon: Icons.lock_outline,
                      obscureText: _obscurePassword,
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: context.colors.textTertiary,
                        ),
                        onPressed: () {
                          setState(() => _obscurePassword = !_obscurePassword);
                        },
                      ),
                      validator: (value) {
                        if (value == null || value.isEmpty) {
                          return 'Please enter your password';
                        }
                        if (_isSignUp && value.length < 6) {
                          return 'Password must be at least 6 characters';
                        }
                        return null;
                      },
                    ),

                    // Forgot password (sign in only)
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
                      Icon(
                        Icons.error_outline,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
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

              // Toggle sign in / sign up
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isSignUp
                        ? 'Already have an account?'
                        : "Don't have an account?",
                    style: AppTypography.bodySmall(context),
                  ),
                  TextButton(
                    onPressed: _isLoading ? null : _toggleMode,
                    child: Text(
                      _isSignUp ? 'Sign In' : 'Sign Up',
                      style: AppTypography.label(context).copyWith(
                        color: AppColors.purple,
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Divider with "or"
              Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 1,
                      color: context.colors.surface,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                    child: Text(
                      'or',
                      style: AppTypography.bodySmall(context).copyWith(
                        color: context.colors.textTertiary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Container(
                      height: 1,
                      color: context.colors.surface,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: AppSpacing.lg),

              // Sign in with Apple button
              SizedBox(
                width: double.infinity,
                child: SignInWithAppleButton(
                  onPressed: _isLoading ? () {} : _signInWithApple,
                  style: SignInWithAppleButtonStyle.black,
                  borderRadius: BorderRadius.circular(AppRadius.button),
                  height: 56,
                ),
              ),

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
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      obscureText: obscureText,
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
