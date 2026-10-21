/// What happened when an Excel file was imported.
class ImportReport {
  const ImportReport({this.added = 0, this.updated = 0, this.skipped = 0, this.errors = const []});

  final int added;
  final int updated;

  /// Rows left empty on purpose, e.g. a student with no status yet.
  final int skipped;

  /// One line per rejected row: "Row 7: ...".
  final List<String> errors;

  int get imported => added + updated;
}
