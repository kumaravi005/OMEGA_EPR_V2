import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/app_text_field.dart';
import '../../../../core/widgets/error_view.dart';
import '../../../../core/widgets/loading_view.dart';
import '../../application/public_content_controller.dart';
import '../../data/public_content_repositories.dart';

/// Single settings form for the one institute-profile document that
/// powers the public site's branding/about/contact sections.
class InstituteProfileScreen extends ConsumerWidget {
  const InstituteProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(instituteProfileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Institute profile')),
      body: SafeArea(
        child: profileAsync.when(
          loading: () => const LoadingView(),
          error: (error, stackTrace) => ErrorView(message: 'Could not load the profile.\n$error'),
          data: (profile) => _ProfileForm(
            name: profile?.name ?? '',
            tagline: profile?.tagline ?? '',
            about: profile?.about ?? '',
            contactPhone: profile?.contactPhone ?? '',
            contactEmail: profile?.contactEmail ?? '',
            address: profile?.address ?? '',
          ),
        ),
      ),
    );
  }
}

class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({
    required this.name,
    required this.tagline,
    required this.about,
    required this.contactPhone,
    required this.contactEmail,
    required this.address,
  });

  final String name;
  final String tagline;
  final String about;
  final String contactPhone;
  final String contactEmail;
  final String address;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  final _formKey = GlobalKey<FormState>();
  late final _nameController = TextEditingController(text: widget.name);
  late final _taglineController = TextEditingController(text: widget.tagline);
  late final _aboutController = TextEditingController(text: widget.about);
  late final _contactPhoneController = TextEditingController(text: widget.contactPhone);
  late final _contactEmailController = TextEditingController(text: widget.contactEmail);
  late final _addressController = TextEditingController(text: widget.address);

  bool _isSubmitting = false;
  String? _errorMessage;
  String? _successMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _taglineController.dispose();
    _aboutController.dispose();
    _contactPhoneController.dispose();
    _contactEmailController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final form = _formKey.currentState;
    if (form == null || !form.validate()) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
      _successMessage = null;
    });

    try {
      await ref
          .read(publicContentControllerProvider)
          .saveInstituteProfile(
            name: _nameController.text,
            tagline: _taglineController.text,
            about: _aboutController.text,
            contactPhone: _contactPhoneController.text,
            contactEmail: _contactEmailController.text,
            address: _addressController.text,
          );
      if (mounted) setState(() => _successMessage = 'Saved.');
    } on PublicContentFailure catch (failure) {
      setState(() => _errorMessage = failure.message);
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Form(
            key: _formKey,
            child: AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  if (_successMessage != null) ...[
                    Text(_successMessage!, style: TextStyle(color: Theme.of(context).colorScheme.primary)),
                    const SizedBox(height: AppSpacing.sm),
                  ],
                  AppTextField(
                    controller: _nameController,
                    label: 'Institute name',
                    enabled: !_isSubmitting,
                    validator: (value) => Validators.required(value, message: 'Name is required'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _taglineController, label: 'Tagline (optional)', enabled: !_isSubmitting),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _aboutController, label: 'About (optional)', enabled: !_isSubmitting),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(
                    controller: _contactPhoneController,
                    label: 'Contact phone (optional)',
                    enabled: !_isSubmitting,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _contactEmailController, label: 'Contact email (optional)', enabled: !_isSubmitting),
                  const SizedBox(height: AppSpacing.sm),
                  AppTextField(controller: _addressController, label: 'Address (optional)', enabled: !_isSubmitting),
                  const SizedBox(height: AppSpacing.lg),
                  AppButton(label: 'Save', isLoading: _isSubmitting, onPressed: _submit),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
