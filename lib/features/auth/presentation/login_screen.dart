import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../application/auth_providers.dart';

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: AppSpacing.lg),
                    Center(
                      child: Container(
                        width: 96,
                        height: 96,
                        padding: const EdgeInsets.all(AppSpacing.xs),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          shape: BoxShape.circle,
                        ),
                        child: ClipOval(
                          child: Image.asset(
                            'assets/branding/logo.png',
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: AppSpacing.md),
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(color: Colors.white),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    Container(
                      padding: const EdgeInsets.all(AppSpacing.lg),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(
                          AppSpacing.radiusLg,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Login to your account',
                            style: Theme.of(context).textTheme.titleLarge,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.xs),
                          Text(
                            'Use the Account ID and password given to you by your administrator.',
                            style: Theme.of(context).textTheme.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          if (_errorMessage != null) ...[
                            Container(
                              padding: const EdgeInsets.all(AppSpacing.sm),
                              decoration: BoxDecoration(
                                color: AppColors.error.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(
                                  AppSpacing.radiusSm,
                                ),
                              ),
                              child: Text(
                                _errorMessage!,
                                style: Theme.of(context).textTheme.bodyMedium
                                    ?.copyWith(color: AppColors.error),
                              ),
                            ),
                            const SizedBox(height: AppSpacing.md),
                          ],
                          AppTextField(
                            controller: _accountIdController,
                            label: 'Account ID',
                            enabled: !_isSubmitting,
                            validator: _validateAccountId,
                            textInputAction: TextInputAction.next,
                            autofillHints: const [AutofillHints.username],
                          ),
                          const SizedBox(height: AppSpacing.md),
                          AppTextField(
                            controller: _passwordController,
                            label: 'Password',
                            enabled: !_isSubmitting,
                            obscureText: _obscurePassword,
                            validator: (value) => Validators.required(
                              value,
                              message: 'Password is required',
                            ),
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            suffixIcon: IconButton(
                              icon: Icon(
                                _obscurePassword
                                    ? Icons.visibility_outlined
                                    : Icons.visibility_off_outlined,
                              ),
                              tooltip: _obscurePassword
                                  ? 'Show password'
                                  : 'Hide password',
                              onPressed: () => setState(
                                () => _obscurePassword = !_obscurePassword,
                              ),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(
                            label: 'Login',
                            isLoading: _isSubmitting,
                            onPressed: _submit,
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
    );
  }
}
