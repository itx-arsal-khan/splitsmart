import 'dart:math' as math;
import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../services/backend_service.dart';
import '../theme/app_colors.dart';
import '../theme/app_styles.dart';
import '../utils/snackbar_util.dart';
import '../utils/phone_utils.dart';
import '../widgets/custom_button.dart';
import '../widgets/custom_text_field.dart';
import 'home_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> with SingleTickerProviderStateMixin {
  bool _isLogin = true;
  bool _obscurePassword = true;
  bool _isLoading = false;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _phoneController = TextEditingController();

  Timer? _debounce;
  String _usernameStatus = '';
  String _phoneStatus = '';

  late final AnimationController _floatingController;

  @override
  void initState() {
    super.initState();
    _floatingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _floatingController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _usernameController.dispose();
    _phoneController.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_isLoading) {
      return;
    }

    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (_isLogin) {
      if (email.isEmpty || password.isEmpty) {
        SnackbarUtil.showError(context, 'Please fill in all required fields.');
        return;
      }
    } else {
      final name = _nameController.text.trim();
      final username = _usernameController.text.trim().toLowerCase();
      final phone = _phoneController.text.trim();
      final confirmPassword = _confirmPasswordController.text.trim();

      if (email.isEmpty || password.isEmpty || name.isEmpty || username.isEmpty || phone.isEmpty || confirmPassword.isEmpty) {
        SnackbarUtil.showError(context, 'Please fill in all required fields.');
        return;
      }

      if (password != confirmPassword) {
        SnackbarUtil.showError(context, 'Passwords do not match.');
        return;
      }

      // Validate Username
      if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
        SnackbarUtil.showError(context, 'Username must be 3-20 characters long and contain only lowercase letters, numbers, and underscores.');
        return;
      }

      // Validate Phone
      if (!PhoneUtils.isValidPakistaniPhone(phone)) {
        SnackbarUtil.showError(context, 'Please enter a valid Pakistani phone number (e.g. 03001234567 or +923001234567).');
        return;
      }

      if (_usernameStatus == 'taken' || _phoneStatus == 'taken') {
        SnackbarUtil.showError(context, 'Please fix username or phone number errors.');
        return;
      }
    }

    setState(() {
      _isLoading = true;
    });

    try {
      if (BackendService.isFirebaseReady) {
        if (_isLogin) {
          await FirebaseAuth.instance.signInWithEmailAndPassword(
            email: email,
            password: password,
          );
        } else {
          final normalizedPhone = PhoneUtils.normalizePhone(_phoneController.text.trim());
          await BackendService.signUpUser(
            email: email,
            password: password,
            name: _nameController.text.trim(),
            username: _usernameController.text.trim().toLowerCase(),
            normalizedPhone: normalizedPhone,
          );
        }
      }

      if (!mounted) {
        return;
      }

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => const HomeDashboard()),
        (route) => false,
      );
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      SnackbarUtil.showError(context, error.message ?? 'Authentication failed');
    } catch (e) {
      if (!mounted) return;
      SnackbarUtil.showError(context, e.toString());
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onUsernameChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final username = value.trim().toLowerCase();
    
    if (username.isEmpty) {
      setState(() => _usernameStatus = '');
      return;
    }
    
    if (!RegExp(r'^[a-z0-9_]{3,20}$').hasMatch(username)) {
      setState(() => _usernameStatus = 'invalid format');
      return;
    }

    setState(() => _usernameStatus = 'checking...');
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final available = await BackendService.checkUsernameAvailable(username);
      if (mounted) {
        setState(() => _usernameStatus = available ? 'available' : 'taken');
      }
    });
  }

  void _onPhoneChanged(String value) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    final phone = value.trim();
    
    if (phone.isEmpty) {
      setState(() => _phoneStatus = '');
      return;
    }
    
    if (!PhoneUtils.isValidPakistaniPhone(phone)) {
      setState(() => _phoneStatus = 'invalid format');
      return;
    }

    setState(() => _phoneStatus = 'checking...');
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      final normalized = PhoneUtils.normalizePhone(phone);
      final available = await BackendService.checkPhoneAvailable(normalized);
      if (mounted) {
        setState(() => _phoneStatus = available ? 'available' : 'taken');
      }
    });
  }

  Widget _buildStatusIndicator(String status) {
    if (status.isEmpty) return const SizedBox.shrink();
    Color color = Colors.grey;
    IconData icon = Icons.info_outline;
    if (status == 'available') {
      color = Colors.green;
      icon = Icons.check_circle;
    } else if (status == 'taken' || status == 'invalid format') {
      color = Colors.red;
      icon = Icons.error_outline;
    } else if (status == 'checking...') {
      color = Colors.orange;
      icon = Icons.hourglass_empty;
    }
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 4),
        Text(status, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const SizedBox(height: 60),
              
              // Animated Floating Logo Text
              AnimatedBuilder(
                animation: _floatingController,
                builder: (context, child) {
                  final dy = math.sin(_floatingController.value * 2 * math.pi) * 8;
                  return Transform.translate(
                    offset: Offset(0, dy),
                    child: child,
                  );
                },
                child: TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween(begin: 0.0, end: 1.0),
                  curve: Curves.easeOutBack,
                  builder: (context, value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: child,
                      ),
                    );
                  },
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                              blurRadius: 30,
                              spreadRadius: 5,
                            )
                          ]
                        ),
                        child: Icon(
                          Icons.account_balance_wallet_rounded,
                          size: 48,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'SplitSmart',
                        style: Theme.of(context).textTheme.displaySmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -1,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      Text(
                        'Bills between friends, sorted.',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              const SizedBox(height: 48),
              
              TweenAnimationBuilder<double>(
                duration: const Duration(milliseconds: 600),
                tween: Tween(begin: 0.0, end: 1.0),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) {
                  return Transform.translate(
                    offset: Offset(0, 30 * (1 - value)),
                    child: Opacity(
                      opacity: value.clamp(0.0, 1.0),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).colorScheme.shadow.withOpacity(0.08),
                        blurRadius: 30,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLogin = true),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: _isLogin
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                  fontWeight: _isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: _isLogin
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                child: const Text('Log In'),
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _isLogin = false),
                            behavior: HitTestBehavior.opaque,
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
                              decoration: BoxDecoration(
                                border: Border(
                                  bottom: BorderSide(
                                    color: !_isLogin
                                        ? Theme.of(context).colorScheme.primary
                                        : Colors.transparent,
                                    width: 3,
                                  ),
                                ),
                              ),
                              alignment: Alignment.center,
                              child: AnimatedDefaultTextStyle(
                                duration: const Duration(milliseconds: 300),
                                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                                  fontWeight: !_isLogin ? FontWeight.bold : FontWeight.w500,
                                  color: !_isLogin
                                      ? Theme.of(context).colorScheme.primary
                                      : Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                child: const Text('Sign Up'),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 400),
                      curve: Curves.fastOutSlowIn,
                      child: Padding(
                        padding: const EdgeInsets.all(AppSpacing.xl),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!_isLogin) ...[
                              Text(
                                'Name',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              CustomTextField(
                                controller: _nameController,
                                hintText: 'Ali Hassan',
                                prefixIcon: Icons.person_outline,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Username',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  _buildStatusIndicator(_usernameStatus),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              CustomTextField(
                                controller: _usernameController,
                                hintText: 'alihassan_123',
                                prefixIcon: Icons.alternate_email,
                                onChanged: _onUsernameChanged,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    'Phone Number',
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                                  ),
                                  _buildStatusIndicator(_phoneStatus),
                                ],
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              CustomTextField(
                                controller: _phoneController,
                                hintText: '03001234567',
                                prefixIcon: Icons.phone_outlined,
                                keyboardType: TextInputType.phone,
                                onChanged: _onPhoneChanged,
                              ),
                              const SizedBox(height: AppSpacing.lg),
                            ],
                            Text(
                              'Email',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            CustomTextField(
                              controller: _emailController,
                              hintText: 'hello@example.com',
                              prefixIcon: Icons.email_outlined,
                              keyboardType: TextInputType.emailAddress,
                            ),
                            const SizedBox(height: AppSpacing.lg),
                            Text(
                              'Password',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: AppSpacing.xs),
                            CustomTextField(
                              controller: _passwordController,
                              hintText: '••••••••',
                              obscureText: _obscurePassword,
                              suffixIcon: IconButton(
                                icon: Icon(_obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            if (!_isLogin) ...[
                              const SizedBox(height: AppSpacing.lg),
                              Text(
                                'Confirm Password',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: AppSpacing.xs),
                              CustomTextField(
                                controller: _confirmPasswordController,
                                hintText: '••••••••',
                                obscureText: _obscurePassword,
                                prefixIcon: Icons.lock_outline,
                              ),
                            ],
                            if (_isLogin) ...[
                              const SizedBox(height: AppSpacing.sm),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: BackendService.isFirebaseReady
                                      ? () async {
                                          final email = _emailController.text.trim();
                                          if (email.isEmpty) {
                                            SnackbarUtil.showError(context, 'Enter your email to reset your password.');
                                            return;
                                          }

                                          await FirebaseAuth.instance.sendPasswordResetEmail(
                                            email: email,
                                          );

                                          if (!mounted) {
                                            return;
                                          }

                                          SnackbarUtil.showSuccess(context, 'Password reset email sent.');
                                        }
                                      : null,
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context).colorScheme.primary,
                                  ),
                                  child: const Text(
                                    'Forgot password?',
                                    style: TextStyle(fontWeight: FontWeight.w600),
                                  ),
                                ),
                              ),
                            ] else
                              const SizedBox(height: AppSpacing.xl),
                            SizedBox(
                              width: double.infinity,
                              height: 56, // Modern taller button
                              child: CustomButton(
                                text: _isLogin ? "Let's Go" : 'Create Account',
                                type: ButtonType.primary,
                                isLoading: _isLoading,
                                onPressed: _submit,
                              ),
                            ),

                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              ),
              const SizedBox(height: 32),
              RichText(
                text: TextSpan(
                  text: _isLogin
                      ? "Don't have an account? "
                      : 'Already have an account? ',
                  style: Theme.of(context).textTheme.titleMedium,
                  children: [
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () => setState(() => _isLogin = !_isLogin),
                        child: Text(
                          _isLogin ? 'Sign Up' : 'Log In',
                          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w700,
                          ),
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
    );
  }
}
