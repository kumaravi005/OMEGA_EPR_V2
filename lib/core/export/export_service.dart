import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'docx_report_builder.dart';
import 'excel_report_builder.dart';
import 'export_dataset.dart';
import 'export_format.dart';
import 'pdf_report_builder.dart';

/// The export "engine" facade - every export module (student, fee dues,
/// test result) calls this with its own [ExportDataset]; the per-format
/// rendering (PDF/Excel/DOCX) and file delivery live here exactly once.
class ExportService {
  const ExportService({
    this.pdfBuilder = const PdfReportBuilder(),
    this.excelBuilder = const ExcelReportBuilder(),
    this.docxBuilder = const DocxReportBuilder(),
  });

  final PdfReportBuilder pdfBuilder;
  final ExcelReportBuilder excelBuilder;
  final DocxReportBuilder docxBuilder;

  Future<Uint8List> buildBytes(ExportDataset dataset, ExportFormat format) {
    return switch (format) {
      ExportFormat.pdf => pdfBuilder.build(dataset),
      ExportFormat.excel => Future.value(excelBuilder.build(dataset)),
      ExportFormat.docx => Future.value(docxBuilder.build(dataset)),
    };
  }

  /// Hands the rendered report to the user. PDF opens the native
  /// print/save preview (this is deliberately not just a download - the
  /// fee-dues report in particular is meant to be printed and handed to
  /// staff for manual calling). Excel/DOCX are handed to the platform
  /// share sheet (a download on web, the share sheet on Android), since
  /// neither format has anything print-preview-shaped to open.
  Future<void> export(
    ExportDataset dataset,
    ExportFormat format, {
    String? fileName,
  }) async {
    final name = fileName ?? _slugify(dataset.title);
    final bytes = await buildBytes(dataset, format);

    if (format == ExportFormat.pdf) {
      await Printing.layoutPdf(
        onLayout: (_) async => bytes,
        name: '$name.${format.fileExtension}',
        format: dataset.isLandscape
            ? PdfPageFormat.a4.landscape
            : PdfPageFormat.a4,
      );
      return;
    }

    await Share.shareXFiles(
      [
        XFile.fromData(
          bytes,
          name: '$name.${format.fileExtension}',
          mimeType: _mimeType(format),
        ),
      ],
      fileNameOverrides: ['$name.${format.fileExtension}'],
    );
  }

  String _mimeType(ExportFormat format) => switch (format) {
    ExportFormat.pdf => 'application/pdf',
    ExportFormat.excel =>
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    ExportFormat.docx =>
      'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
  };

  String _slugify(String title) =>
      title.trim().replaceAll(RegExp(r'\s+'), '_').toLowerCase();
}
