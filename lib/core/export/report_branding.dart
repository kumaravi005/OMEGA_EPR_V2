/// A logo's position/size within the header area, as fractions of the
/// header's own width/height (0..1) - not pixels or PDF points. Using
/// fractions is what lets the exact same numbers drive both the live
/// Flutter preview (any screen size) and the PDF header block (a fixed
/// point width) without a unit-conversion step either place has to get
/// right.
class LogoPlacement {
  const LogoPlacement({this.xFraction = 0.0, this.yFraction = 0.0, this.widthFraction = 0.18});

  final double xFraction;
  final double yFraction;
  final double widthFraction;
}

class ReportHeaderBranding {
  const ReportHeaderBranding({
    this.logoUrl,
    this.logoPlacement = const LogoPlacement(),
    this.instituteName,
    this.tagline,
    this.address,
    this.contact,
    this.otherText,
  });

  final String? logoUrl;
  final LogoPlacement logoPlacement;

  /// Each of these is null exactly when the admin hid that element -
  /// "show/hide" has already been resolved by the time this reaches a
  /// renderer, so a builder only ever has to ask "is this null".
  final String? instituteName;
  final String? tagline;
  final String? address;
  final String? contact;
  final String? otherText;
}

class ReportFooterBranding {
  const ReportFooterBranding({
    this.footerText,
    this.showSignature = false,
    this.signatureLabel,
    this.showPageNumber = true,
    this.showDate = false,
    this.contactText,
  });

  final String? footerText;
  final bool showSignature;
  final String? signatureLabel;
  final bool showPageNumber;
  final bool showDate;
  final String? contactText;
}

/// A baked snapshot of one saved [ReportLayoutTemplate], as resolved by
/// `ReportLayoutTemplate.toBranding()` at the moment a report is
/// generated - never a live reference to the Firestore document. This is
/// what guarantees a report already generated doesn't change if the
/// template is edited afterward: the generator reads the template once,
/// bakes it into this plain value object, and every builder renders from
/// that snapshot into final bytes - there is no code path that re-reads
/// the template later.
class ReportBranding {
  const ReportBranding({required this.templateName, required this.header, required this.footer});

  final String templateName;
  final ReportHeaderBranding header;
  final ReportFooterBranding footer;
}
