/// Orientation for a printed/paginated report (PDF). `auto` picks
/// landscape once there are more columns than comfortably fit a portrait
/// A4 page (see [ExportDataset.isLandscape]) - Excel/DOCX ignore this
/// except to set the same default page-size hint.
enum ReportOrientation { auto, portrait, landscape }

/// The one shape every export format renders from - the "engine" input.
/// A module (student/fee-dues/test-result export) is responsible for
/// building this (its own data source + filters + selected columns +
/// sorting); everything after that - PDF/Excel/DOCX rendering, page
/// orientation, multi-page layout - is shared, not reimplemented per
/// module.
class ExportDataset {
  ExportDataset({
    required this.title,
    this.subtitle,
    required this.columns,
    required this.rows,
    this.orientation = ReportOrientation.auto,
  }) : assert(columns.isNotEmpty, 'An export must have at least one column');

  /// Report title, shown at the top of every output format (e.g.
  /// "Student List", "Fee Dues Report").
  final String title;

  /// Optional second line under the title (e.g. the applied filters, so
  /// the printed page shows what it is a report *of*).
  final String? subtitle;

  /// Column header labels, in display order.
  final List<String> columns;

  /// Each row's cells, already formatted as display strings, in the same
  /// order as [columns]. Every row must be the same length as [columns].
  final List<List<String>> rows;

  final ReportOrientation orientation;

  /// More than 6 columns stops fitting a portrait A4 page comfortably at
  /// a readable font size, so `auto` switches to landscape from there.
  bool get isLandscape =>
      orientation == ReportOrientation.landscape || (orientation == ReportOrientation.auto && columns.length > 6);
}
