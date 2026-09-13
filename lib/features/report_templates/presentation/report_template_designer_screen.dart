import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/app_text_field.dart';
import '../../../core/widgets/loading_view.dart';
import '../../public/data/public_content_repositories.dart';
import '../application/report_layout_template_controller.dart';
import '../data/report_layout_template.dart';
import '../data/report_layout_template_repository.dart';
import 'widgets/a4_preview.dart';

/// Create/edit one A4 report letterhead template. A4 preview up top with
/// a draggable/resizable logo; every other header/footer element is a
/// text field plus a show/hide switch below it - "keep the editor
/// simple", not a full drag-everything design canvas.
class ReportTemplateDesignerScreen extends ConsumerStatefulWidget {
  const ReportTemplateDesignerScreen({super.key, this.templateId});

  final String? templateId;

  @override
  ConsumerState<ReportTemplateDesignerScreen> createState() =>
      _ReportTemplateDesignerScreenState();
}

class _ReportTemplateDesignerScreenState
    extends ConsumerState<ReportTemplateDesignerScreen> {
  final _nameController = TextEditingController();
  final _logoUrlController = TextEditingController();
  final _instituteNameController = TextEditingController();
  final _taglineController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _secondaryPhoneController = TextEditingController();
  final _websiteController = TextEditingController();
  final _otherTextController = TextEditingController();
  final _footerTextController = TextEditingController();
  final _signatureLabelController = TextEditingController(
    text: 'Authorized Signatory',
  );
  final _footerContactController = TextEditingController();

  double _logoX = 0.0;
  double _logoY = 0.15;
  double _logoWidth = 0.18;
  bool _showInstituteName = true;
  bool _showTagline = true;
  bool _showAddress = true;
  bool _showContact = true;
  bool _showSecondaryPhone = false;
  bool _showWebsite = false;
  bool _showOtherText = false;
  bool _showFooterText = false;
  bool _showSignature = false;
  bool _showPageNumber = true;
  bool _showDate = false;
  bool _showFooterContact = false;

  bool _landscapePreview = false;
  bool _isSaving = false;
  bool _isLoading = true;
  ReportLayoutTemplate? _existing;

  List<TextEditingController> get _allControllers => [
    _nameController,
    _logoUrlController,
    _instituteNameController,
    _taglineController,
    _addressController,
    _contactController,
    _secondaryPhoneController,
    _websiteController,
    _otherTextController,
    _footerTextController,
    _signatureLabelController,
    _footerContactController,
  ];

  ReportHeaderConfig get _headerConfig => ReportHeaderConfig(
    logoUrl: _logoUrlController.text.trim().isEmpty
        ? null
        : _logoUrlController.text.trim(),
    logoXFraction: _logoX,
    logoYFraction: _logoY,
    logoWidthFraction: _logoWidth,
    instituteName: _instituteNameController.text.trim(),
    showInstituteName: _showInstituteName,
    tagline: _taglineController.text.trim(),
    showTagline: _showTagline,
    address: _addressController.text.trim(),
    showAddress: _showAddress,
    contact: _contactController.text.trim(),
    showContact: _showContact,
    secondaryPhone: _secondaryPhoneController.text.trim(),
    showSecondaryPhone: _showSecondaryPhone,
    website: _websiteController.text.trim(),
    showWebsite: _showWebsite,
    otherText: _otherTextController.text.trim(),
    showOtherText: _showOtherText,
  );

  ReportFooterConfig get _footerConfig => ReportFooterConfig(
    footerText: _footerTextController.text.trim(),
    showFooterText: _showFooterText,
    showSignature: _showSignature,
    signatureLabel: _signatureLabelController.text.trim().isEmpty
        ? 'Authorized Signatory'
        : _signatureLabelController.text.trim(),
    showPageNumber: _showPageNumber,
    showDate: _showDate,
    contactText: _footerContactController.text.trim(),
    showFooterContact: _showFooterContact,
  );

  @override
  void initState() {
    super.initState();
    for (final controller in _allControllers) {
      controller.addListener(() => setState(() {}));
    }
    if (widget.templateId == null) {
      _isLoading = false;
    } else {
      _loadExisting(widget.templateId!);
    }
  }

  Future<void> _loadExisting(String templateId) async {
    final template = await ref
        .read(reportLayoutTemplateRepositoryProvider)
        .getById(templateId);
    if (!mounted) return;
    if (template == null) {
      setState(() => _isLoading = false);
      return;
    }
    _existing = template;
    _nameController.text = template.name;
    _logoUrlController.text = template.header.logoUrl ?? '';
    _logoX = template.header.logoXFraction;
    _logoY = template.header.logoYFraction;
    _logoWidth = template.header.logoWidthFraction;
    _instituteNameController.text = template.header.instituteName;
    _showInstituteName = template.header.showInstituteName;
    _taglineController.text = template.header.tagline;
    _showTagline = template.header.showTagline;
    _addressController.text = template.header.address;
    _showAddress = template.header.showAddress;
    _contactController.text = template.header.contact;
    _showContact = template.header.showContact;
    _secondaryPhoneController.text = template.header.secondaryPhone;
    _showSecondaryPhone = template.header.showSecondaryPhone;
    _websiteController.text = template.header.website;
    _showWebsite = template.header.showWebsite;
    _otherTextController.text = template.header.otherText;
    _showOtherText = template.header.showOtherText;
    _footerTextController.text = template.footer.footerText;
    _showFooterText = template.footer.showFooterText;
    _showSignature = template.footer.showSignature;
    _signatureLabelController.text = template.footer.signatureLabel;
    _showPageNumber = template.footer.showPageNumber;
    _showDate = template.footer.showDate;
    _footerContactController.text = template.footer.contactText;
    _showFooterContact = template.footer.showFooterContact;
    setState(() => _isLoading = false);
  }

  /// Pre-fills header fields from the configured institute profile (Set
  /// 9's `institutes/main`) - a one-time copy, not a live link, matching
  /// this project's established "snapshot, never re-read later" template
  /// philosophy (see `ReportBranding`'s doc comment). Admin can freely
  /// edit or hide anything afterward; tapping this again just re-copies
  /// the current profile values. "Do not invent institute fields that
  /// don't exist" (Set 21 section 3) - only fields `InstituteProfile`
  /// actually has are used.
  void _autofillFromInstituteProfile() {
    final profile = ref.read(instituteProfileProvider).valueOrNull;
    if (profile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No institute profile is configured yet.')),
      );
      return;
    }
    setState(() {
      _instituteNameController.text = profile.name;
      if (profile.logoUrl != null) _logoUrlController.text = profile.logoUrl!;
      if (profile.tagline != null) _taglineController.text = profile.tagline!;
      if (profile.address != null) _addressController.text = profile.address!;
      if (profile.contactPhone != null) {
        _contactController.text = profile.contactPhone!;
      }
      if (profile.secondaryPhone != null && profile.secondaryPhone!.isNotEmpty) {
        _secondaryPhoneController.text = profile.secondaryPhone!;
        _showSecondaryPhone = true;
      }
      if (profile.website != null && profile.website!.isNotEmpty) {
        _websiteController.text = profile.website!;
        _showWebsite = true;
      }
    });
  }

  @override
  void dispose() {
    for (final controller in _allControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          _existing == null ? 'New report template' : 'Edit report template',
        ),
      ),
      body: SafeArea(
        child: _isLoading
            ? const LoadingView()
            : Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 640),
                  child: ListView(
                    padding: const EdgeInsets.all(AppSpacing.md),
                    children: [
                      AppTextField(
                        controller: _nameController,
                        label: 'Template name',
                        hintText: 'e.g. Standard Letterhead',
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Preview: '),
                          ChoiceChip(
                            label: const Text('Portrait'),
                            selected: !_landscapePreview,
                            onSelected: (_) =>
                                setState(() => _landscapePreview = false),
                          ),
                          const SizedBox(width: AppSpacing.xs),
                          ChoiceChip(
                            label: const Text('Landscape'),
                            selected: _landscapePreview,
                            onSelected: (_) =>
                                setState(() => _landscapePreview = true),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      Center(
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 420),
                          child: A4Preview(
                            header: _headerConfig,
                            footer: _footerConfig,
                            landscape: _landscapePreview,
                            onLogoPlacementChanged: (x, y, width) =>
                                setState(() {
                                  _logoX = x;
                                  _logoY = y;
                                  _logoWidth = width;
                                }),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Header',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: _autofillFromInstituteProfile,
                            icon: const Icon(Icons.sync_outlined, size: 18),
                            label: const Text('Use institute profile'),
                          ),
                        ],
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      AppTextField(
                        controller: _logoUrlController,
                        label: 'Logo image URL',
                        hintText: 'https://... (drag/resize it above once set)',
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _toggleableField(
                        'Institute name',
                        _instituteNameController,
                        _showInstituteName,
                        (v) => _showInstituteName = v,
                      ),
                      _toggleableField(
                        'Tagline',
                        _taglineController,
                        _showTagline,
                        (v) => _showTagline = v,
                      ),
                      _toggleableField(
                        'Address',
                        _addressController,
                        _showAddress,
                        (v) => _showAddress = v,
                      ),
                      _toggleableField(
                        'Primary phone / contact',
                        _contactController,
                        _showContact,
                        (v) => _showContact = v,
                      ),
                      _toggleableField(
                        'Secondary phone',
                        _secondaryPhoneController,
                        _showSecondaryPhone,
                        (v) => _showSecondaryPhone = v,
                      ),
                      _toggleableField(
                        'Website',
                        _websiteController,
                        _showWebsite,
                        (v) => _showWebsite = v,
                      ),
                      _toggleableField(
                        'Other header text',
                        _otherTextController,
                        _showOtherText,
                        (v) => _showOtherText = v,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      Text(
                        'Footer',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.sm),
                      _toggleableField(
                        'Footer text',
                        _footerTextController,
                        _showFooterText,
                        (v) => _showFooterText = v,
                      ),
                      Row(
                        children: [
                          Expanded(
                            child: AppTextField(
                              controller: _signatureLabelController,
                              label: 'Signature label',
                            ),
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Switch(
                            value: _showSignature,
                            onChanged: (v) =>
                                setState(() => _showSignature = v),
                          ),
                        ],
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Page number'),
                        value: _showPageNumber,
                        onChanged: (v) => setState(() => _showPageNumber = v),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('Date'),
                        value: _showDate,
                        onChanged: (v) => setState(() => _showDate = v),
                      ),
                      _toggleableField(
                        'Footer contact info',
                        _footerContactController,
                        _showFooterContact,
                        (v) => _showFooterContact = v,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      AppButton(
                        label: 'Save template',
                        isLoading: _isSaving,
                        onPressed: _save,
                      ),
                      const SizedBox(height: AppSpacing.lg),
                    ],
                  ),
                ),
              ),
      ),
    );
  }

  Widget _toggleableField(
    String label,
    TextEditingController controller,
    bool show,
    void Function(bool) setShow,
  ) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: AppTextField(controller: controller, label: label),
          ),
          const SizedBox(width: AppSpacing.sm),
          Switch(
            value: show,
            onChanged: (value) => setState(() => setShow(value)),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a template name.')));
      return;
    }

    setState(() => _isSaving = true);
    try {
      if (_existing == null) {
        await ref
            .read(reportLayoutTemplateControllerProvider)
            .create(name: name, header: _headerConfig, footer: _footerConfig);
      } else {
        await ref
            .read(reportLayoutTemplateControllerProvider)
            .update(
              _existing!,
              name: name,
              header: _headerConfig,
              footer: _footerConfig,
            );
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Template saved.')));
        Navigator.of(context).pop();
      }
    } on ReportLayoutTemplateFailure catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(error.message)));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}
