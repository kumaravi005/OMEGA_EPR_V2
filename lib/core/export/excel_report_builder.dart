import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'export_dataset.dart';

/// Renders an [ExportDataset] to a single-sheet .xlsx workbook - a bold
/// header row, one data row per row, and a title row above the header.
/// The one place Excel generation is implemented; every export module
/// reuses it.
///
/// When [ExportDataset.branding] is set, the institute name/tagline/
/// address/contact are added as plain text rows above the title - a
/// simple text letterhead, not a visual replica of the PDF's positioned
/// logo (Excel has no meaningful "logo position" concept the way a
/// printed page does, and the `excel` package version here has no
/// print-header/footer API to hook a page-numbered footer into either).
class ExcelReportBuilder {
  const ExcelReportBuilder();

  Uint8List build(ExportDataset dataset) {
    final workbook = Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet()!;
    const sheetName = 'Report';
    workbook.rename(defaultSheetName, sheetName);
    final sheet = workbook[sheetName];

    final brandingStyle = CellStyle(bold: true, fontSize: 13);
    final brandingSubStyle = CellStyle(
      fontColorHex: ExcelColor.grey700,
      fontSize: 9,
    );
    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = CellStyle(
      fontColorHex: ExcelColor.grey700,
      fontSize: 10,
    );
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blueGrey700,
    );

    final header = dataset.branding?.header;
    if (header != null) {
      for (final (text, style) in [
        (header.instituteName, brandingStyle),
        (header.tagline, brandingSubStyle),
        (header.address, brandingSubStyle),
        (header.contact, brandingSubStyle),
        (header.otherText, brandingSubStyle),
      ]) {
        if (text == null) continue;
        final rowIndex = sheet.maxRows;
        sheet.appendRow([TextCellValue(text)]);
        sheet
                .cell(
                  CellIndex.indexByColumnRow(
                    columnIndex: 0,
                    rowIndex: rowIndex,
                  ),
                )
                .cellStyle =
            style;
      }
      sheet.appendRow([TextCellValue('')]);
    }

    final titleRowIndex = sheet.maxRows;
    sheet.appendRow([TextCellValue(dataset.title)]);
    sheet
            .cell(
              CellIndex.indexByColumnRow(
                columnIndex: 0,
                rowIndex: titleRowIndex,
              ),
            )
            .cellStyle =
        titleStyle;

    if (dataset.subtitle != null && dataset.subtitle!.isNotEmpty) {
      final subtitleRowIndex = sheet.maxRows;
      sheet.appendRow([TextCellValue(dataset.subtitle!)]);
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: 0,
                  rowIndex: subtitleRowIndex,
                ),
              )
              .cellStyle =
          subtitleStyle;
    }
    // A real (non-empty) blank row: an all-null appendRow is a no-op for
    // row count, since nothing is actually written to any cell.
    sheet.appendRow([TextCellValue('')]);

    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([
      for (final column in dataset.columns) TextCellValue(column),
    ]);
    for (var c = 0; c < dataset.columns.length; c++) {
      sheet
              .cell(
                CellIndex.indexByColumnRow(
                  columnIndex: c,
                  rowIndex: headerRowIndex,
                ),
              )
              .cellStyle =
          headerStyle;
    }

    for (final row in dataset.rows) {
      sheet.appendRow([for (final cell in row) TextCellValue(cell)]);
    }

    for (var c = 0; c < dataset.columns.length; c++) {
      final width = dataset.columns[c].length.clamp(10, 40).toDouble();
      sheet.setColumnWidth(c, width);
    }

    return Uint8List.fromList(workbook.encode()!);
  }
}
