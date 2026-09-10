import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'export_dataset.dart';

/// Renders an [ExportDataset] to PDF bytes - A4, portrait or landscape
/// (see [ExportDataset.isLandscape]), auto-paginated with a repeating
/// table header and a "Page X of Y" footer on every page. This is the
/// one place PDF layout is implemented; every export module reuses it
/// instead of building its own PDF.
class PdfReportBuilder {
  const PdfReportBuilder();

  Future<Uint8List> build(ExportDataset dataset) async {
    final doc = pw.Document();
    final pageFormat = dataset.isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

    doc.addPage(
      pw.MultiPage(
        pageFormat: pageFormat.copyWith(marginLeft: 24, marginRight: 24, marginTop: 28, marginBottom: 28),
        header: (context) {
          if (context.pageNumber > 1) return pw.SizedBox.shrink();
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(dataset.title, style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              if (dataset.subtitle != null && dataset.subtitle!.isNotEmpty)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(top: 2),
                  child: pw.Text(dataset.subtitle!, style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
                ),
              pw.SizedBox(height: 10),
            ],
          );
        },
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text(
            'Page ${context.pageNumber} of ${context.pagesCount}',
            style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600),
          ),
        ),
        build: (context) => [
          pw.TableHelper.fromTextArray(
            headers: dataset.columns,
            data: dataset.rows,
            headerStyle: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: const pw.BoxDecoration(color: PdfColors.blueGrey700),
            cellStyle: const pw.TextStyle(fontSize: 8.5),
            cellHeight: 22,
            cellAlignment: pw.Alignment.centerLeft,
            headerAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 3),
            border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.4),
          ),
        ],
      ),
    );

    return doc.save();
  }
}
