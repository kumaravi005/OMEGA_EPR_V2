import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'export_dataset.dart';
import 'report_branding.dart';

/// Renders an [ExportDataset] to PDF bytes - A4, portrait or landscape
/// (see [ExportDataset.isLandscape]), auto-paginated with a repeating
/// table header and a "Page X of Y" footer on every page. This is the
/// one place PDF layout is implemented; every export module reuses it
/// instead of building its own PDF.
///
/// When [ExportDataset.branding] is set (Set 7's report-layout
/// templates), every page also gets a letterhead-style header (logo +
/// institute text, positioned per the template) and a richer footer
/// (signature area / date / contact alongside the page number). Without
/// it, this renders exactly as it did in Set 6 - existing callers that
/// never pick a template are unaffected.
class PdfReportBuilder {
  // ignore: prefer_initializing_formals
  const PdfReportBuilder({http.Client? httpClient}) : _httpClient = httpClient;

  final http.Client? _httpClient;

  static const _headerHeight = 64.0;
  static const _margin = 24.0;

  Future<Uint8List> build(ExportDataset dataset) async {
    final doc = pw.Document();
    final pageFormat =
        (dataset.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4)
            .copyWith(
              marginLeft: _margin,
              marginRight: _margin,
              marginTop: _margin + 4,
              marginBottom: _margin + 4,
            );
    final contentWidth =
        pageFormat.width - pageFormat.marginLeft - pageFormat.marginRight;

    final branding = dataset.branding;
    final logo = branding?.header.logoUrl == null
        ? null
        : await _fetchLogo(branding!.header.logoUrl!);

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat,
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            if (branding != null) ...[
              _brandingHeader(branding.header, logo, contentWidth),
              pw.SizedBox(height: 6),
              pw.Divider(color: PdfColors.grey400, thickness: 0.6),
              pw.SizedBox(height: 6),
            ],
            if (context.pageNumber == 1) ...[
              pw.Text(
                dataset.title,
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (dataset.subtitle != null && dataset.subtitle!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(
                    dataset.subtitle!,
                    style: const pw.TextStyle(
                      fontSize: 10,
                      color: PdfColors.grey700,
                    ),
                  ),
                ),
              pw.SizedBox(height: 10),
            ],
          ],
        ),
        footer: (context) => branding == null
            ? _plainFooter(context)
            : _brandingFooter(branding.footer, context),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: dataset.columns,
            data: dataset.rows,
            headerStyle: pw.TextStyle(
              fontSize: 9,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white,
            ),
            headerDecoration: const pw.BoxDecoration(
              color: PdfColors.blueGrey700,
            ),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellHeight: 22,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(
              horizontal: 4,
              vertical: 3,
            ),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),
        ],
      ),
    );

    return doc.save();
  }

  pw.Widget _plainFooter(pw.Context context) => pw.Align(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      'Page ${context.pageNumber} of ${context.pagesCount}',
      style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
    ),
  );

  pw.Widget _brandingHeader(
    ReportHeaderBranding header,
    pw.MemoryImage? logo,
    double contentWidth,
  ) {
    final placement = header.logoPlacement;
    final logoOnLeftHalf = placement.xFraction < 0.5;

    final textLines = <pw.Widget>[
      if (header.instituteName != null)
        pw.Text(
          header.instituteName!,
          style: pw.TextStyle(fontSize: 15, fontWeight: pw.FontWeight.bold),
        ),
      if (header.tagline != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.tagline!,
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey700),
          ),
        ),
      if (header.address != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.address!,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      if (header.contact != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.contact!,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      if (header.secondaryPhone != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.secondaryPhone!,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      if (header.website != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.website!,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
      if (header.otherText != null)
        pw.Padding(
          padding: const pw.EdgeInsets.only(top: 1),
          child: pw.Text(
            header.otherText!,
            style: const pw.TextStyle(fontSize: 8),
          ),
        ),
    ];

    pw.Widget? logoWidget;
    if (logo != null) {
      final sourceWidth = logo.width ?? 1;
      final sourceHeight = logo.height ?? sourceWidth;
      final logoWidth = (placement.widthFraction * contentWidth).clamp(
        16.0,
        contentWidth,
      );
      final logoHeight = logoWidth * (sourceHeight / sourceWidth);
      final left = (placement.xFraction * contentWidth).clamp(
        0.0,
        contentWidth - logoWidth,
      );
      final top = (placement.yFraction * _headerHeight).clamp(
        0.0,
        (_headerHeight - logoHeight).clamp(0.0, _headerHeight),
      );
      logoWidget = pw.Positioned(
        left: left,
        top: top,
        child: pw.Image(logo, width: logoWidth, height: logoHeight),
      );
    }

    final textWidget = pw.Positioned(
      left: logoOnLeftHalf ? null : 0,
      right: logoOnLeftHalf ? 0 : null,
      top: 0,
      child: pw.SizedBox(
        width: contentWidth * 0.62,
        child: pw.Column(
          crossAxisAlignment: logoOnLeftHalf
              ? pw.CrossAxisAlignment.end
              : pw.CrossAxisAlignment.start,
          children: textLines,
        ),
      ),
    );

    return pw.SizedBox(
      height: _headerHeight,
      width: contentWidth,
      child: pw.Stack(
        children: [?logoWidget, if (textLines.isNotEmpty) textWidget],
      ),
    );
  }

  pw.Widget _brandingFooter(ReportFooterBranding footer, pw.Context context) {
    final leftChildren = <pw.Widget>[
      if (footer.showSignature) ...[
        pw.Container(
          width: 130,
          height: 0.6,
          color: PdfColors.grey600,
          margin: const pw.EdgeInsets.only(bottom: 2),
        ),
        pw.Text(
          footer.signatureLabel ?? 'Authorized Signatory',
          style: const pw.TextStyle(fontSize: 8),
        ),
      ],
    ];

    final rightChildren = <pw.Widget>[
      if (footer.showDate)
        pw.Text(
          'Date: ${_todayLabel()}',
          style: const pw.TextStyle(fontSize: 8),
        ),
      if (footer.contactText != null)
        pw.Text(footer.contactText!, style: const pw.TextStyle(fontSize: 8)),
      if (footer.showPageNumber)
        pw.Text(
          'Page ${context.pageNumber} of ${context.pagesCount}',
          style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600),
        ),
    ];

    return pw.Column(
      children: [
        pw.Divider(color: PdfColors.grey400, thickness: 0.6),
        pw.Row(
          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
          crossAxisAlignment: pw.CrossAxisAlignment.end,
          children: [
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: leftChildren,
            ),
            if (footer.footerText != null)
              pw.Expanded(
                child: pw.Center(
                  child: pw.Text(
                    footer.footerText!,
                    style: const pw.TextStyle(fontSize: 8),
                  ),
                ),
              ),
            pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: rightChildren,
            ),
          ],
        ),
      ],
    );
  }

  String _todayLabel() {
    final now = DateTime.now();
    return '${now.day.toString().padLeft(2, '0')}-${now.month.toString().padLeft(2, '0')}-${now.year}';
  }

  Future<pw.MemoryImage?> _fetchLogo(String url) async {
    final client = _httpClient ?? http.Client();
    try {
      final response = await client
          .get(Uri.parse(url))
          .timeout(const Duration(seconds: 8));
      if (response.statusCode != 200 || response.bodyBytes.isEmpty) return null;
      return pw.MemoryImage(response.bodyBytes);
    } catch (_) {
      // A bad/unreachable logo URL should never fail the whole export -
      // the report still generates, just without the logo.
      return null;
    } finally {
      if (_httpClient == null) client.close();
    }
  }
}
