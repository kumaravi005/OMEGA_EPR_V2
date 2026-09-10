import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:excel/excel.dart' as xls;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:omega_epr_v2/core/export/docx_report_builder.dart';
import 'package:omega_epr_v2/core/export/excel_report_builder.dart';
import 'package:omega_epr_v2/core/export/export_dataset.dart';
import 'package:omega_epr_v2/core/export/pdf_report_builder.dart';
import 'package:omega_epr_v2/core/export/report_branding.dart';
import 'package:xml/xml.dart';

// A minimal valid 1x1 transparent PNG, used to test logo fetching without
// a real network call.
final _tinyPngBytes = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII=',
);

ReportBranding _branding({String? logoUrl}) => ReportBranding(
  templateName: 'Letterhead',
  header: ReportHeaderBranding(
    logoUrl: logoUrl,
    logoPlacement: const LogoPlacement(xFraction: 0.02, yFraction: 0.1, widthFraction: 0.2),
    instituteName: 'Omega Education Centre',
    tagline: 'Excellence in learning',
    address: '123 Main Street',
    contact: '+91 90000 00000',
  ),
  footer: const ReportFooterBranding(
    footerText: 'This is a computer-generated report.',
    showSignature: true,
    signatureLabel: 'Principal',
    showPageNumber: true,
    showDate: true,
    contactText: 'www.example.org',
  ),
);

ExportDataset _smallDataset() => ExportDataset(
  title: 'Student List',
  subtitle: 'Batch: Class 9 Science | Session: 2025-26',
  columns: ['Name', 'Father name', 'Class', 'Final fee', 'Paid', 'Due'],
  rows: [
    ['Aarav Sharma', 'Rakesh Sharma', 'Class 9', 'Rs. 9000', 'Rs. 9000', 'Paid in full'],
    ['Diya Verma', 'Suresh Verma', 'Class 9', 'Rs. 9000', 'Rs. 5000', 'Due Rs. 4000'],
  ],
);

ExportDataset _wideDataset({required int columnCount, required int rowCount}) {
  final columns = [for (var c = 0; c < columnCount; c++) 'Column $c'];
  final rows = [
    for (var r = 0; r < rowCount; r++) [for (var c = 0; c < columnCount; c++) 'R${r}C$c - a fairly long cell value'],
  ];
  return ExportDataset(title: 'Wide report', columns: columns, rows: rows);
}

void main() {
  group('ExportDataset orientation', () {
    test('auto stays portrait for 6 or fewer columns', () {
      expect(_wideDataset(columnCount: 6, rowCount: 1).isLandscape, isFalse);
    });

    test('auto switches to landscape beyond 6 columns', () {
      expect(_wideDataset(columnCount: 7, rowCount: 1).isLandscape, isTrue);
    });

    test('an explicit orientation overrides the column-count heuristic', () {
      final forced = ExportDataset(
        title: 't',
        columns: const ['a'],
        rows: const [],
        orientation: ReportOrientation.landscape,
      );
      expect(forced.isLandscape, isTrue);
    });
  });

  group('PdfReportBuilder', () {
    test('produces a non-empty PDF for a small dataset', () async {
      final bytes = await const PdfReportBuilder().build(_smallDataset());
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('does not throw for a wide, many-row dataset (multi-page + landscape)', () async {
      final bytes = await const PdfReportBuilder().build(_wideDataset(columnCount: 10, rowCount: 120));
      expect(bytes, isNotEmpty);
    });

    test('renders a branded header/footer with a fetched logo', () async {
      final client = MockClient((request) async => http.Response.bytes(_tinyPngBytes, 200));
      final dataset = _smallDataset();
      final branded = ExportDataset(
        title: dataset.title,
        subtitle: dataset.subtitle,
        columns: dataset.columns,
        rows: dataset.rows,
        branding: _branding(logoUrl: 'https://example.org/logo.png'),
      );

      final bytes = await PdfReportBuilder(httpClient: client).build(branded);
      expect(bytes, isNotEmpty);
      expect(String.fromCharCodes(bytes.take(5)), '%PDF-');
    });

    test('a broken/unreachable logo URL does not fail the export', () async {
      final client = MockClient((request) async => http.Response('not found', 404));
      final dataset = _smallDataset();
      final branded = ExportDataset(
        title: dataset.title,
        columns: dataset.columns,
        rows: dataset.rows,
        branding: _branding(logoUrl: 'https://example.org/missing.png'),
      );

      final bytes = await PdfReportBuilder(httpClient: client).build(branded);
      expect(bytes, isNotEmpty);
    });

    test('renders branded header/footer text even with no logo configured', () async {
      final dataset = _smallDataset();
      final branded = ExportDataset(
        title: dataset.title,
        columns: dataset.columns,
        rows: dataset.rows,
        branding: _branding(),
      );

      final bytes = await const PdfReportBuilder().build(branded);
      expect(bytes, isNotEmpty);
    });
  });

  group('ExcelReportBuilder', () {
    test('round-trips headers and row count through a real xlsx decode', () {
      final bytes = const ExcelReportBuilder().build(_smallDataset());
      expect(bytes, isNotEmpty);

      final decoded = xls.Excel.decodeBytes(bytes);
      final sheet = decoded.tables[decoded.tables.keys.first]!;
      final rows = sheet.rows;

      // Row 0: title, row 1: subtitle, row 2: blank, row 3: header, then data.
      final headerRow = rows[3].map((cell) => cell?.value.toString()).toList();
      expect(headerRow, ['Name', 'Father name', 'Class', 'Final fee', 'Paid', 'Due']);
      expect(rows.length, 6); // title + subtitle + blank + header + 2 data rows
      expect(rows[4][0]?.value.toString(), 'Aarav Sharma');
    });
  });

  group('DocxReportBuilder', () {
    test('produces a valid zip containing a well-formed word/document.xml', () {
      final bytes = const DocxReportBuilder().build(_smallDataset());
      expect(bytes, isNotEmpty);

      final archive = ZipDecoder().decodeBytes(bytes);
      final names = archive.files.map((f) => f.name).toSet();
      expect(names, containsAll(['[Content_Types].xml', '_rels/.rels', 'word/document.xml']));

      final documentXmlBytes = archive.findFile('word/document.xml')!.content as List<int>;
      final documentXml = XmlDocument.parse(String.fromCharCodes(documentXmlBytes));
      expect(documentXml.toXmlString(), contains('Student List'));
      expect(documentXml.toXmlString(), contains('Aarav Sharma'));
      expect(documentXml.findAllElements('w:tr').length, 3); // header row + 2 data rows
    });

    test('switches page size to landscape for a wide dataset', () {
      final bytes = const DocxReportBuilder().build(_wideDataset(columnCount: 8, rowCount: 2));
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlBytes = archive.findFile('word/document.xml')!.content as List<int>;
      final documentXml = XmlDocument.parse(String.fromCharCodes(documentXmlBytes));
      final pgSz = documentXml.findAllElements('w:pgSz').first;
      expect(pgSz.getAttribute('w:orient'), 'landscape');
    });

    test('XML-escapes cell text that contains special characters', () {
      final dataset = ExportDataset(title: 'A & B <report>', columns: const ['Name'], rows: const [['O\'Brien & "Sons"']]);
      final bytes = const DocxReportBuilder().build(dataset);
      final archive = ZipDecoder().decodeBytes(bytes);
      final documentXmlBytes = archive.findFile('word/document.xml')!.content as List<int>;
      // Must parse without throwing - proves special characters were escaped, not
      // concatenated raw into the XML.
      final documentXml = XmlDocument.parse(String.fromCharCodes(documentXmlBytes));
      expect(documentXml.toXmlString(), contains("O'Brien"));
    });
  });
}
