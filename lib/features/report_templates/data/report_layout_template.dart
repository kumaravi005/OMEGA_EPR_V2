import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/export/report_branding.dart';
import '../../../data/models/firestore_document.dart';

/// The header half of a saved [ReportLayoutTemplate] - the editable,
/// storable form (text + a separate show/hide flag per element, so
/// hiding something doesn't lose what was typed). [logoXFraction]/
/// [logoYFraction]/[logoWidthFraction] are 0..1 fractions of the header
/// area (see [LogoPlacement]), set by dragging/resizing the logo in the
/// designer's A4 preview.
class ReportHeaderConfig {
  const ReportHeaderConfig({
    this.logoUrl,
    this.logoXFraction = 0.0,
    this.logoYFraction = 0.15,
    this.logoWidthFraction = 0.18,
    this.instituteName = '',
    this.showInstituteName = true,
    this.tagline = '',
    this.showTagline = true,
    this.address = '',
    this.showAddress = true,
    this.contact = '',
    this.showContact = true,
    this.otherText = '',
    this.showOtherText = false,
  });

  factory ReportHeaderConfig.fromMap(Map<String, dynamic> map) {
    return ReportHeaderConfig(
      logoUrl: map['logoUrl'] as String?,
      logoXFraction: (map['logoXFraction'] as num?)?.toDouble() ?? 0.0,
      logoYFraction: (map['logoYFraction'] as num?)?.toDouble() ?? 0.15,
      logoWidthFraction: (map['logoWidthFraction'] as num?)?.toDouble() ?? 0.18,
      instituteName: map['instituteName'] as String? ?? '',
      showInstituteName: map['showInstituteName'] as bool? ?? true,
      tagline: map['tagline'] as String? ?? '',
      showTagline: map['showTagline'] as bool? ?? true,
      address: map['address'] as String? ?? '',
      showAddress: map['showAddress'] as bool? ?? true,
      contact: map['contact'] as String? ?? '',
      showContact: map['showContact'] as bool? ?? true,
      otherText: map['otherText'] as String? ?? '',
      showOtherText: map['showOtherText'] as bool? ?? false,
    );
  }

  final String? logoUrl;
  final double logoXFraction;
  final double logoYFraction;
  final double logoWidthFraction;
  final String instituteName;
  final bool showInstituteName;
  final String tagline;
  final bool showTagline;
  final String address;
  final bool showAddress;
  final String contact;
  final bool showContact;
  final String otherText;
  final bool showOtherText;

  ReportHeaderConfig copyWith({
    String? logoUrl,
    bool clearLogoUrl = false,
    double? logoXFraction,
    double? logoYFraction,
    double? logoWidthFraction,
    String? instituteName,
    bool? showInstituteName,
    String? tagline,
    bool? showTagline,
    String? address,
    bool? showAddress,
    String? contact,
    bool? showContact,
    String? otherText,
    bool? showOtherText,
  }) {
    return ReportHeaderConfig(
      logoUrl: clearLogoUrl ? null : (logoUrl ?? this.logoUrl),
      logoXFraction: logoXFraction ?? this.logoXFraction,
      logoYFraction: logoYFraction ?? this.logoYFraction,
      logoWidthFraction: logoWidthFraction ?? this.logoWidthFraction,
      instituteName: instituteName ?? this.instituteName,
      showInstituteName: showInstituteName ?? this.showInstituteName,
      tagline: tagline ?? this.tagline,
      showTagline: showTagline ?? this.showTagline,
      address: address ?? this.address,
      showAddress: showAddress ?? this.showAddress,
      contact: contact ?? this.contact,
      showContact: showContact ?? this.showContact,
      otherText: otherText ?? this.otherText,
      showOtherText: showOtherText ?? this.showOtherText,
    );
  }

  Map<String, dynamic> toMap() => {
    'logoUrl': logoUrl,
    'logoXFraction': logoXFraction,
    'logoYFraction': logoYFraction,
    'logoWidthFraction': logoWidthFraction,
    'instituteName': instituteName,
    'showInstituteName': showInstituteName,
    'tagline': tagline,
    'showTagline': showTagline,
    'address': address,
    'showAddress': showAddress,
    'contact': contact,
    'showContact': showContact,
    'otherText': otherText,
    'showOtherText': showOtherText,
  };
}

/// The footer half of a saved [ReportLayoutTemplate].
class ReportFooterConfig {
  const ReportFooterConfig({
    this.footerText = '',
    this.showFooterText = false,
    this.showSignature = false,
    this.signatureLabel = 'Authorized Signatory',
    this.showPageNumber = true,
    this.showDate = false,
    this.contactText = '',
    this.showFooterContact = false,
  });

  factory ReportFooterConfig.fromMap(Map<String, dynamic> map) {
    return ReportFooterConfig(
      footerText: map['footerText'] as String? ?? '',
      showFooterText: map['showFooterText'] as bool? ?? false,
      showSignature: map['showSignature'] as bool? ?? false,
      signatureLabel: map['signatureLabel'] as String? ?? 'Authorized Signatory',
      showPageNumber: map['showPageNumber'] as bool? ?? true,
      showDate: map['showDate'] as bool? ?? false,
      contactText: map['contactText'] as String? ?? '',
      showFooterContact: map['showFooterContact'] as bool? ?? false,
    );
  }

  final String footerText;
  final bool showFooterText;
  final bool showSignature;
  final String signatureLabel;
  final bool showPageNumber;
  final bool showDate;
  final String contactText;
  final bool showFooterContact;

  ReportFooterConfig copyWith({
    String? footerText,
    bool? showFooterText,
    bool? showSignature,
    String? signatureLabel,
    bool? showPageNumber,
    bool? showDate,
    String? contactText,
    bool? showFooterContact,
  }) {
    return ReportFooterConfig(
      footerText: footerText ?? this.footerText,
      showFooterText: showFooterText ?? this.showFooterText,
      showSignature: showSignature ?? this.showSignature,
      signatureLabel: signatureLabel ?? this.signatureLabel,
      showPageNumber: showPageNumber ?? this.showPageNumber,
      showDate: showDate ?? this.showDate,
      contactText: contactText ?? this.contactText,
      showFooterContact: showFooterContact ?? this.showFooterContact,
    );
  }

  Map<String, dynamic> toMap() => {
    'footerText': footerText,
    'showFooterText': showFooterText,
    'showSignature': showSignature,
    'signatureLabel': signatureLabel,
    'showPageNumber': showPageNumber,
    'showDate': showDate,
    'contactText': contactText,
    'showFooterContact': showFooterContact,
  };
}

/// An admin-designed, reusable A4 report letterhead - saved once, then
/// picked by name from any compatible export screen (student list, fee
/// dues, test result, ...). [toBranding] is called once per report
/// generation to bake a snapshot (see [ReportBranding]'s doc comment for
/// why that's what keeps an already-generated report from changing when
/// the template is edited afterward).
class ReportLayoutTemplate implements FirestoreDocument {
  const ReportLayoutTemplate({
    required this.templateId,
    required this.name,
    required this.header,
    required this.footer,
    required this.createdAt,
    required this.updatedAt,
  });

  factory ReportLayoutTemplate.fromMap(String id, Map<String, dynamic> map) {
    return ReportLayoutTemplate(
      templateId: id,
      name: map['name'] as String,
      header: ReportHeaderConfig.fromMap(Map<String, dynamic>.from(map['header'] as Map? ?? const {})),
      footer: ReportFooterConfig.fromMap(Map<String, dynamic>.from(map['footer'] as Map? ?? const {})),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String templateId;
  final String name;
  final ReportHeaderConfig header;
  final ReportFooterConfig footer;
  final DateTime createdAt;
  final DateTime updatedAt;

  ReportBranding toBranding() => ReportBranding(
    templateName: name,
    header: ReportHeaderBranding(
      logoUrl: header.logoUrl,
      logoPlacement: LogoPlacement(
        xFraction: header.logoXFraction,
        yFraction: header.logoYFraction,
        widthFraction: header.logoWidthFraction,
      ),
      instituteName: header.showInstituteName && header.instituteName.isNotEmpty ? header.instituteName : null,
      tagline: header.showTagline && header.tagline.isNotEmpty ? header.tagline : null,
      address: header.showAddress && header.address.isNotEmpty ? header.address : null,
      contact: header.showContact && header.contact.isNotEmpty ? header.contact : null,
      otherText: header.showOtherText && header.otherText.isNotEmpty ? header.otherText : null,
    ),
    footer: ReportFooterBranding(
      footerText: footer.showFooterText && footer.footerText.isNotEmpty ? footer.footerText : null,
      showSignature: footer.showSignature,
      signatureLabel: footer.signatureLabel,
      showPageNumber: footer.showPageNumber,
      showDate: footer.showDate,
      contactText: footer.showFooterContact && footer.contactText.isNotEmpty ? footer.contactText : null,
    ),
  );

  @override
  String get id => templateId;

  @override
  Map<String, dynamic> toMap() => {
    'name': name,
    'header': header.toMap(),
    'footer': footer.toMap(),
    'createdAt': Timestamp.fromDate(createdAt),
    'updatedAt': Timestamp.fromDate(updatedAt),
  };
}
