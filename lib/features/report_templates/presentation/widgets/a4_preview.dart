import 'package:flutter/material.dart';
import '../../data/report_layout_template.dart';
import 'draggable_logo.dart';

/// A live, to-scale A4 preview of one template's header/footer - the
/// same header/footer layout logic `PdfReportBuilder` uses (logo-side
/// text anchoring, a 3-column footer row), reimplemented in Flutter
/// widgets so what the admin drags/toggles here is what the generated
/// PDF actually looks like. The body is a placeholder box - this isn't a
/// full document preview, just the letterhead being designed.
class A4Preview extends StatelessWidget {
  const A4Preview({
    super.key,
    required this.header,
    required this.footer,
    this.landscape = false,
    this.onLogoPlacementChanged,
  });

  final ReportHeaderConfig header;
  final ReportFooterConfig footer;
  final bool landscape;

  /// Non-null enables dragging/resizing the logo; omit for a read-only
  /// preview (e.g. shown next to an export screen's template picker).
  final void Function(double x, double y, double width)? onLogoPlacementChanged;

  @override
  Widget build(BuildContext context) {
    final aspect = landscape ? 297 / 210 : 210 / 297;
    final hasLogo = header.logoUrl != null && header.logoUrl!.isNotEmpty;

    return AspectRatio(
      aspectRatio: aspect,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: Colors.black26),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 6, offset: Offset(0, 2))],
        ),
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            SizedBox(height: 90, child: LayoutBuilder(builder: (context, constraints) => _header(constraints.biggest, hasLogo))),
            const Divider(height: 12),
            Expanded(
              child: Container(
                width: double.infinity,
                decoration: BoxDecoration(border: Border.all(color: Colors.black12)),
                alignment: Alignment.center,
                child: const Text('Report content here', style: TextStyle(color: Colors.black26, fontSize: 11)),
              ),
            ),
            const Divider(height: 12),
            SizedBox(height: 34, child: _footer()),
          ],
        ),
      ),
    );
  }

  Widget _header(Size headerSize, bool hasLogo) {
    final logoOnLeftHalf = header.logoXFraction < 0.5;
    final align = logoOnLeftHalf ? TextAlign.right : TextAlign.left;
    final textLines = <Widget>[
      if (header.showInstituteName && header.instituteName.isNotEmpty)
        Text(header.instituteName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14), textAlign: align),
      if (header.showTagline && header.tagline.isNotEmpty)
        Text(header.tagline, style: const TextStyle(fontSize: 9, color: Colors.black54), textAlign: align),
      if (header.showAddress && header.address.isNotEmpty) Text(header.address, style: const TextStyle(fontSize: 8), textAlign: align),
      if (header.showContact && header.contact.isNotEmpty) Text(header.contact, style: const TextStyle(fontSize: 8), textAlign: align),
      if (header.showOtherText && header.otherText.isNotEmpty)
        Text(header.otherText, style: const TextStyle(fontSize: 8), textAlign: align),
    ];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        if (hasLogo && onLogoPlacementChanged != null)
          DraggableLogo(
            logoUrl: header.logoUrl!,
            xFraction: header.logoXFraction,
            yFraction: header.logoYFraction,
            widthFraction: header.logoWidthFraction,
            headerSize: headerSize,
            onChanged: onLogoPlacementChanged!,
          )
        else if (hasLogo)
          Positioned(
            left: header.logoXFraction * headerSize.width,
            top: header.logoYFraction * headerSize.height,
            child: Image.network(
              header.logoUrl!,
              width: header.logoWidthFraction * headerSize.width,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.broken_image_outlined),
            ),
          ),
        if (textLines.isNotEmpty)
          Positioned(
            left: logoOnLeftHalf ? headerSize.width * 0.38 : 0,
            right: logoOnLeftHalf ? 0 : headerSize.width * 0.38,
            top: 0,
            child: Column(
              crossAxisAlignment: logoOnLeftHalf ? CrossAxisAlignment.end : CrossAxisAlignment.start,
              children: textLines,
            ),
          ),
      ],
    );
  }

  Widget _footer() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (footer.showSignature) ...[
                Container(width: 60, height: 0.6, color: Colors.black54),
                Text(footer.signatureLabel, style: const TextStyle(fontSize: 7)),
              ],
            ],
          ),
        ),
        if (footer.showFooterText && footer.footerText.isNotEmpty)
          Expanded(
            child: Center(child: Text(footer.footerText, style: const TextStyle(fontSize: 7), textAlign: TextAlign.center)),
          ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (footer.showDate) const Text('Date: --/--/----', style: TextStyle(fontSize: 7)),
              if (footer.showFooterContact && footer.contactText.isNotEmpty) Text(footer.contactText, style: const TextStyle(fontSize: 7)),
              if (footer.showPageNumber) const Text('Page 1 of 1', style: TextStyle(fontSize: 7, color: Colors.black54)),
            ],
          ),
        ),
      ],
    );
  }
}
