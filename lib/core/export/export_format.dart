enum ExportFormat {
  pdf,
  excel,
  docx;

  String get label => switch (this) {
    ExportFormat.pdf => 'PDF',
    ExportFormat.excel => 'Excel',
    ExportFormat.docx => 'Word (DOCX)',
  };

  String get fileExtension => switch (this) {
    ExportFormat.pdf => 'pdf',
    ExportFormat.excel => 'xlsx',
    ExportFormat.docx => 'docx',
  };
}
