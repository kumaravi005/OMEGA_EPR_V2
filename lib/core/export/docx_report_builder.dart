import 'dart:convert';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:xml/xml.dart';
import 'export_dataset.dart';

/// Renders an [ExportDataset] to a minimal, valid .docx (WordprocessingML
/// zipped with [ZipEncoder]) - a title, optional subtitle, and a table
/// with as many columns as the dataset needs (dynamic column counts rule
/// out a pre-made template with a fixed table shape, which is why this
/// builds the XML directly instead of using a template-filling package).
/// Word paginates and wraps table text on its own, so there's no manual
/// page-break/page-numbering logic here - see docs/database-architecture.md.
///
/// When [ExportDataset.branding] is set, the institute name/tagline/
/// address/contact are added as plain paragraphs above the title - a
/// simple text letterhead. The logo image and footer (signature/date/
/// page number) are PDF-only (see [PdfReportBuilder]) - a real image
/// header/footer in docx needs extra zip parts this builder deliberately
/// doesn't add, matching the same "no manual page numbering" scope
/// decision already made for the plain page-count footer.
class DocxReportBuilder {
  const DocxReportBuilder();

  // Twentieths of a point (docx's unit for page dimensions/margins).
  static const _a4WidthPortrait = 11906;
  static const _a4HeightPortrait = 16838;
  static const _margin = 720;

  Uint8List build(ExportDataset dataset) {
    final documentXml = _buildDocumentXml(dataset);

    final archive = Archive()
      ..addFile(_textFile('[Content_Types].xml', _contentTypesXml))
      ..addFile(_textFile('_rels/.rels', _relsXml))
      ..addFile(_textFile('word/document.xml', documentXml));

    final bytes = ZipEncoder().encode(archive);
    if (bytes == null) throw StateError('Failed to build the .docx archive.');
    return Uint8List.fromList(bytes);
  }

  ArchiveFile _textFile(String path, String content) {
    final bytes = utf8.encode(content);
    return ArchiveFile(path, bytes.length, bytes);
  }

  String _buildDocumentXml(ExportDataset dataset) {
    final builder = XmlBuilder();
    builder.processing('xml', 'version="1.0" encoding="UTF-8" standalone="yes"');
    builder.element(
      'w:document',
      namespaces: {'http://schemas.openxmlformats.org/wordprocessingml/2006/main': 'w'},
      nest: () {
        builder.element(
          'w:body',
          nest: () {
            final header = dataset.branding?.header;
            if (header != null) {
              for (final (text, bold, size) in [
                (header.instituteName, true, 28),
                (header.tagline, false, 18),
                (header.address, false, 16),
                (header.contact, false, 16),
                (header.otherText, false, 16),
              ]) {
                if (text != null) _paragraph(builder, text, bold: bold, size: size, color: bold ? null : '616161');
              }
              _emptyParagraph(builder);
            }
            _paragraph(builder, dataset.title, bold: true, size: 32);
            if (dataset.subtitle != null && dataset.subtitle!.isNotEmpty) {
              _paragraph(builder, dataset.subtitle!, size: 18, color: '616161');
            }
            _emptyParagraph(builder);
            _table(builder, dataset);
            _sectionProperties(builder, landscape: dataset.isLandscape);
          },
        );
      },
    );
    return builder.buildDocument().toXmlString();
  }

  void _paragraph(XmlBuilder builder, String text, {bool bold = false, int size = 20, String? color}) {
    builder.element(
      'w:p',
      nest: () {
        builder.element(
          'w:r',
          nest: () {
            builder.element(
              'w:rPr',
              nest: () {
                if (bold) builder.element('w:b');
                builder.element('w:sz', attributes: {'w:val': '$size'});
                if (color != null) builder.element('w:color', attributes: {'w:val': color});
              },
            );
            builder.element('w:t', attributes: {'xml:space': 'preserve'}, nest: text);
          },
        );
      },
    );
  }

  void _emptyParagraph(XmlBuilder builder) => builder.element('w:p');

  void _table(XmlBuilder builder, ExportDataset dataset) {
    builder.element(
      'w:tbl',
      nest: () {
        builder.element(
          'w:tblPr',
          nest: () {
            builder.element('w:tblStyle', attributes: {'w:val': 'TableGrid'});
            builder.element(
              'w:tblBorders',
              nest: () {
                for (final edge in ['top', 'left', 'bottom', 'right', 'insideH', 'insideV']) {
                  builder.element(
                    'w:$edge',
                    attributes: {'w:val': 'single', 'w:sz': '4', 'w:space': '0', 'w:color': 'BFBFBF'},
                  );
                }
              },
            );
          },
        );
        _tableRow(builder, dataset.columns, bold: true, shadingHex: '455A64', textColorHex: 'FFFFFF');
        for (final row in dataset.rows) {
          _tableRow(builder, row);
        }
      },
    );
  }

  void _tableRow(XmlBuilder builder, List<String> cells, {bool bold = false, String? shadingHex, String? textColorHex}) {
    builder.element(
      'w:tr',
      nest: () {
        for (final cell in cells) {
          builder.element(
            'w:tc',
            nest: () {
              if (shadingHex != null) {
                builder.element(
                  'w:tcPr',
                  nest: () => builder.element('w:shd', attributes: {'w:val': 'clear', 'w:fill': shadingHex}),
                );
              }
              _paragraph(builder, cell, bold: bold, size: 18, color: textColorHex);
            },
          );
        }
      },
    );
  }

  void _sectionProperties(XmlBuilder builder, {required bool landscape}) {
    final width = landscape ? _a4HeightPortrait : _a4WidthPortrait;
    final height = landscape ? _a4WidthPortrait : _a4HeightPortrait;
    builder.element(
      'w:sectPr',
      nest: () {
        builder.element(
          'w:pgSz',
          attributes: {'w:w': '$width', 'w:h': '$height', if (landscape) 'w:orient': 'landscape'},
        );
        builder.element(
          'w:pgMar',
          attributes: {
            'w:top': '$_margin',
            'w:right': '$_margin',
            'w:bottom': '$_margin',
            'w:left': '$_margin',
            'w:header': '0',
            'w:footer': '0',
            'w:gutter': '0',
          },
        );
      },
    );
  }

  static const _contentTypesXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
      '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
      '<Default Extension="xml" ContentType="application/xml"/>'
      '<Override PartName="/word/document.xml" '
      'ContentType="application/vnd.openxmlformats-officedocument.wordprocessingml.document.main+xml"/>'
      '</Types>';

  static const _relsXml =
      '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
      '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
      '<Relationship Id="rId1" '
      'Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" '
      'Target="word/document.xml"/>'
      '</Relationships>';
}
