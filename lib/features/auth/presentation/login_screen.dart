import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_card.dart';
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
    WidgetsBinding.instance.addPostFrameCallback((_) => _consumeSessionMessage());
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
          .login(accountId: _accountIdController.text, password: _passwordController.text);
    } on AuthFailure catch (failure) {
      if (!mounted) return;
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String? _validateAccountId(String? value) {
    final requiredError = Validators.required(value, message: 'Account ID is required');
    if (requiredError != null) return requiredError;
    if (!AppConstants.accountIdPattern.hasMatch(value!.trim().toLowerCase())) {
      return 'Enter a valid Account ID';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Sign in')),
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
                    Text(
                      AppConstants.appName,
                      style: Theme.of(context).textTheme.headlineMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      'Sign in with the Account ID and password given to you by your administrator.',
                      style: Theme.of(context).textTheme.bodyMedium,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    AppCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_errorMessage != null) ...[
                            Text(
                              _errorMessage!,
                              style: Theme.of(
                                context,
                              ).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.error),
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
                            validator: (value) => Validators.required(value, message: 'Password is required'),
                            textInputAction: TextInputAction.done,
                            autofillHints: const [AutofillHints.password],
                            suffixIcon: IconButton(
                              icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                              tooltip: _obscurePassword ? 'Show password' : 'Hide password',
                              onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            ),
                          ),
                          const SizedBox(height: AppSpacing.lg),
                          AppButton(label: 'Sign in', isLoading: _isSubmitting, onPressed: _submit),
                        ],
                      ),
                    ),
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
