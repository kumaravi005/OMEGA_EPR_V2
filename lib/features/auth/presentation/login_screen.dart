import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_shadows.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../public/data/public_content_repositories.dart';
import '../application/auth_providers.dart';

/// Login-screen-local design tokens (per the post-Set-33 redesign brief)
/// that are more precise than the app-wide [AppSpacing] scale calls for
/// elsewhere - kept local rather than widening the shared theme, since
/// this brief only covers the public landing page and this screen.
const _kFieldRadius = 14.0;

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _accountIdController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => _consumeSessionMessage(),
    );
  }

  @override
  void dispose() {
    _accountIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _consumeSessionMessage() {
    final message = ref.read(sessionMessageProvider);
    if (message == null) return;
    ref.read(sessionMessageProvider.notifier).state = null;
    setState(() => _errorMessage = message);
  }

  Future<void> _submit() async {
    if (_isSubmitting) return;
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      await ref
          .read(authControllerProvider)
          .login(
            accountId: _accountIdController.text,
            password: _passwordController.text,
          );
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateAccountId(String? value) {
    final requiredError = Validators.required(
      value,
      message: 'Account ID is required',
    );
    if (requiredError != null) return requiredError;
    if (!AppConstants.accountIdPattern.hasMatch(value!.trim().toLowerCase())) {
      return 'Enter a valid Account ID';
    }
    return null;
  }

  void _showForgotPasswordHelp(String? contactPhone, String? contactEmail) {
    final hasContact =
        (contactPhone != null && contactPhone.isNotEmpty) ||
        (contactEmail != null && contactEmail.isNotEmpty);
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot password?'),
        content: Text(
          hasContact
              ? 'Passwords are reset by your centre administrator. '
                    'Contact your centre'
                    '${contactPhone != null && contactPhone.isNotEmpty ? ' at $contactPhone' : ''}'
                    '${contactEmail != null && contactEmail.isNotEmpty ? ' ($contactEmail)' : ''} '
                    'to have it reset.'
              : 'Passwords are reset by your centre administrator. '
                    'Please contact your centre to have it reset.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(instituteProfileProvider);
    final profile = profileAsync.valueOrNull;
    final instituteName = profile?.name ?? AppConstants.appName;
    final tagline = profile?.tagline;
    final logoUrl = profile?.logoUrl;
    final hasNetworkLogo = logoUrl != null && logoUrl.isNotEmpty;

    return Scaffold(
      body: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [AppColors.primary, AppColors.primaryDark],
          ),
        ),
        child: Stack(
          children: [
            const Positioned(
              top: -60,
              right: -60,
              child: _FaintCircle(diameter: 220),
            ),
            const Positioned(
              bottom: 40,
              left: -70,
              child: _FaintCircle(diameter: 180),
            ),
            SafeArea(
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 420),
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.md,
                      vertical: AppSpacing.lg,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: AppSpacing.lg),
                          Center(
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(
                                _kFieldRadius,
                              ),
                              child: SizedBox(
                                width: 112,
                                height: 112,
                                child: hasNetworkLogo
                                    ? Image.network(
                                        logoUrl,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, _, _) =>
                                            Image.asset(
                                              'assets/branding/logo.png',
                                              fit: BoxFit.cover,
                                            ),
                                      )
                                    : Image.asset(
                                        'assets/branding/logo.png',
                                        fit: BoxFit.cover,
                                      ),
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.md),
                          Text(
                            instituteName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.w800,
                              height: 28 / 22,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          if (tagline != null && tagline.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              tagline,
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                                height: 18 / 13,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                          const SizedBox(height: AppSpacing.xl),
                          Container(
                            padding: const EdgeInsets.all(AppSpacing.lg),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(
                                AppSpacing.radiusLg,
                              ),
                              boxShadow: AppShadows.card,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Container(
                                      width: 20,
                                      height: 2,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                    Flexible(
                                      child: Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: AppSpacing.sm,
                                        ),
                                        child: Text(
                                          'Login to your account',
                                          style: Theme.of(
                                            context,
                                          ).textTheme.titleLarge,
                                          textAlign: TextAlign.center,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      width: 20,
                                      height: 2,
                                      color: AppColors.primary.withValues(
                                        alpha: 0.35,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: AppSpacing.xs),
                                Text(
                                  'Use the Account ID and password given to '
                                  'you by your administrator.',
                                  style: Theme.of(context).textTheme.bodySmall,
                                  textAlign: TextAlign.center,
                                ),
                                const SizedBox(height: AppSpacing.lg),
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(
                                      AppSpacing.sm,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(
                                        alpha: 0.08,
                                      ),
                                      borderRadius: BorderRadius.circular(
                                        AppSpacing.radiusSm,
                                      ),
                                    ),
                                    child: Text(
                                      _errorMessage!,
                                      style: Theme.of(context)
                                          .textTheme
                                          .bodyMedium
                                          ?.copyWith(color: AppColors.error),
                                    ),
                                  ),
                                  const SizedBox(height: AppSpacing.md),
                                ],
                                Theme(
                                  data: Theme.of(context).copyWith(
                                    inputDecorationTheme: InputDecorationTheme(
                                      filled: true,
                                      fillColor: AppColors.surfaceSunken,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpacing.md,
                                            vertical: 14,
                                          ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kFieldRadius,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kFieldRadius,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.border,
                                        ),
                                      ),
                                      focusedBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kFieldRadius,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.primary,
                                          width: 1.8,
                                        ),
                                      ),
                                      errorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kFieldRadius,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.error,
                                        ),
                                      ),
                                      focusedErrorBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(
                                          _kFieldRadius,
                                        ),
                                        borderSide: const BorderSide(
                                          color: AppColors.error,
                                          width: 1.8,
                                        ),
                                      ),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.stretch,
                                    children: [
                                      AppTextField(
                                        controller: _accountIdController,
                                        label: 'Account ID',
                                        enabled: !_isSubmitting,
                                        validator: _validateAccountId,
                                        textInputAction: TextInputAction.next,
                                        autofillHints: const [
                                          AutofillHints.username,
                                        ],
                                        prefixIcon: const Icon(
                                          Icons.person_outline,
                                        ),
                                      ),
                                      const SizedBox(height: AppSpacing.md),
                                      AppTextField(
                                        controller: _passwordController,
                                        label: 'Password',
                                        enabled: !_isSubmitting,
                                        obscureText: _obscurePassword,
                                        validator: (value) =>
                                            Validators.required(
                                              value,
                                              message: 'Password is required',
                                            ),
                                        textInputAction: TextInputAction.done,
                                        autofillHints: const [
                                          AutofillHints.password,
                                        ],
                                        prefixIcon: const Icon(
                                          Icons.lock_outline,
                                        ),
                                        suffixIcon: IconButton(
                                          icon: Icon(
                                            _obscurePassword
                                                ? Icons.visibility_outlined
                                                : Icons
                                                      .visibility_off_outlined,
                                          ),
                                          tooltip: _obscurePassword
                                              ? 'Show password'
                                              : 'Hide password',
                                          onPressed: () => setState(
                                            () => _obscurePassword =
                                                !_obscurePassword,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () => _showForgotPasswordHelp(
                                      profile?.contactPhone,
                                      profile?.contactEmail,
                                    ),
                                    child: const Text('Forgot password?'),
                                  ),
                                ),
                                const SizedBox(height: AppSpacing.sm),
                                SizedBox(
                                  height: 54,
                                  child: AppButton(
                                    label: 'Login',
                                    isLoading: _isSubmitting,
                                    onPressed: _submit,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A faint outlined circle used for subtle header depth, per the redesign
/// brief ("two faint 8%-opacity linework shapes").
class _FaintCircle extends StatelessWidget {
  const _FaintCircle({required this.diameter});

  final double diameter;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: diameter,
        height: diameter,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 24,
          ),
        ),
      ),
    );
  }
}
