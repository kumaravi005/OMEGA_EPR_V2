import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'export_dataset.dart';

/// Renders an [ExportDataset] to a single-sheet .xlsx workbook - a bold
/// header row, one data row per row, and a title row above the header.
/// The one place Excel generation is implemented; every export module
/// reuses it.
class ExcelReportBuilder {
  const ExcelReportBuilder();

  Uint8List build(ExportDataset dataset) {
    final workbook = Excel.createExcel();
    final defaultSheetName = workbook.getDefaultSheet()!;
    const sheetName = 'Report';
    workbook.rename(defaultSheetName, sheetName);
    final sheet = workbook[sheetName];

    final titleStyle = CellStyle(bold: true, fontSize: 14);
    final subtitleStyle = CellStyle(fontColorHex: ExcelColor.grey700, fontSize: 10);
    final headerStyle = CellStyle(
      bold: true,
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.blueGrey700,
    );

    sheet.appendRow([TextCellValue(dataset.title)]);
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0)).cellStyle = titleStyle;

    if (dataset.subtitle != null && dataset.subtitle!.isNotEmpty) {
      sheet.appendRow([TextCellValue(dataset.subtitle!)]);
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1)).cellStyle = subtitleStyle;
    }
    // A real (non-empty) blank row: an all-null appendRow is a no-op for
    // row count, since nothing is actually written to any cell.
    sheet.appendRow([TextCellValue('')]);

    final headerRowIndex = sheet.maxRows;
    sheet.appendRow([for (final column in dataset.columns) TextCellValue(column)]);
    for (var c = 0; c < dataset.columns.length; c++) {
      sheet.cell(CellIndex.indexByColumnRow(columnIndex: c, rowIndex: headerRowIndex)).cellStyle = headerStyle;
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
