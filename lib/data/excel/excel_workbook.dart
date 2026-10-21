import 'dart:convert';

import 'package:archive/archive.dart';
import 'package:excel/excel.dart';

import '../../core/utils/date_format.dart';
import '../local/failures.dart';

/// One column of a sheet the app writes and reads back.
class ExcelColumn {
  const ExcelColumn(this.key, this.header, {this.required = false, this.width = 18, this.aliases = const []});

  final String key;

  /// Arabic header written in the first row.
  final String header;
  final bool required;
  final double width;

  /// Other header spellings accepted on import.
  final List<String> aliases;

  String get title => required ? '$header *' : header;
}

/// A data row read from a sheet, keyed by [ExcelColumn.key], with its Excel row number.
class ExcelRow {
  const ExcelRow(this.number, this.values);

  final int number;
  final Map<String, String> values;

  String? operator [](String key) {
    final value = values[key]?.trim();
    return value == null || value.isEmpty ? null : value;
  }

  bool get isEmpty => values.values.every((value) => value.trim().isEmpty);
}

abstract final class ExcelWorkbook {
  static final _headerStyle = CellStyle(
    bold: true,
    fontColorHex: ExcelColor.fromHexString('#FFFFFF'),
    backgroundColorHex: ExcelColor.fromHexString('#12324D'),
    horizontalAlign: HorizontalAlign.Center,
    verticalAlign: VerticalAlign.Center,
  );

  static final _titleStyle = CellStyle(bold: true, fontSize: 14);

  static Excel create() => Excel.createExcel();

  /// Adds a right-to-left sheet with a styled header row and the given rows.
  static void addTable(Excel excel, String sheetName, List<ExcelColumn> columns, List<List<CellValue?>> rows) {
    final sheet = _sheet(excel, sheetName);
    sheet.isRTL = true;
    for (var i = 0; i < columns.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        TextCellValue(columns[i].title),
        cellStyle: _headerStyle,
      );
      sheet.setColumnWidth(i, columns[i].width);
    }
    for (final row in rows) {
      sheet.appendRow(row);
    }
  }

  /// Adds a sheet of free text lines; the first line is the title.
  static void addNotes(Excel excel, String sheetName, List<String> lines) {
    final sheet = _sheet(excel, sheetName);
    sheet.isRTL = true;
    sheet.setColumnWidth(0, 90);
    for (var i = 0; i < lines.length; i++) {
      sheet.updateCell(
        CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: i),
        TextCellValue(lines[i]),
        cellStyle: i == 0 ? _titleStyle : null,
      );
    }
  }

  static List<int> encode(Excel excel, String firstSheet) {
    excel.setDefaultSheet(firstSheet);
    final bytes = excel.encode();
    if (bytes == null) throw const LocalFailure('Could not create the Excel file');
    return _rightToLeft(bytes);
  }

  /// The excel package only keeps `isRTL` on the workbook's original sheet, so every sheet
  /// is switched to right-to-left here, directly in the saved file.
  static List<int> _rightToLeft(List<int> bytes) {
    final source = ZipDecoder().decodeBytes(bytes);
    final output = Archive();
    for (final file in source.files) {
      if (file.isFile && file.name.startsWith('xl/worksheets/sheet') && file.name.endsWith('.xml')) {
        final xml = utf8
            .decode(file.content as List<int>)
            .replaceAll(RegExp(r'\s+rightToLeft="[01]"'), '')
            .replaceAll('<sheetView ', '<sheetView rightToLeft="1" ');
        final content = utf8.encode(xml);
        output.addFile(ArchiveFile(file.name, content.length, content));
      } else {
        output.addFile(file);
      }
    }
    return ZipEncoder().encode(output)!;
  }

  /// Files written by openpyxl, LibreOffice and some other tools link their sheets with
  /// absolute paths ("/xl/worksheets/sheet1.xml"), which the excel package cannot follow.
  /// The links are rewritten relative to xl/, the way Excel itself writes them.
  static List<int> _relativeTargets(List<int> bytes) {
    final Archive source;
    try {
      source = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      return bytes;
    }
    final rels = source.findFile('xl/_rels/workbook.xml.rels');
    if (rels == null) return bytes;
    final xml = utf8.decode(rels.content as List<int>);
    if (!xml.contains('Target="/')) return bytes;
    final fixed = utf8.encode(xml.replaceAll('Target="/xl/', 'Target="').replaceAll('Target="/', 'Target="../'));
    final output = Archive();
    for (final file in source.files) {
      output.addFile(file.name == rels.name ? ArchiveFile(file.name, fixed.length, fixed) : file);
    }
    return ZipEncoder().encode(output) ?? bytes;
  }

  /// Finds the sheet holding [columns] and returns its non-empty data rows.
  static List<ExcelRow> read(List<int> bytes, List<ExcelColumn> columns) {
    final Excel excel;
    try {
      excel = Excel.decodeBytes(_relativeTargets(bytes));
    } catch (_) {
      throw const LocalFailure('The file is not a valid .xlsx file');
    }
    for (final sheet in excel.tables.values) {
      final rows = sheet.rows;
      for (var r = 0; r < rows.length && r < 15; r++) {
        final index = _headerIndex(rows[r], columns);
        if (index == null) continue;
        final data = <ExcelRow>[];
        for (var i = r + 1; i < rows.length; i++) {
          final row = ExcelRow(i + 1, {
            for (final entry in index.entries)
              entry.key: entry.value < rows[i].length ? cellText(rows[i][entry.value]?.value) : '',
          });
          if (!row.isEmpty) data.add(row);
        }
        return data;
      }
    }
    final missing = columns.where((column) => column.required).map((column) => column.header).join('، ');
    throw LocalFailure('الملف لا يطابق القالب. الأعمدة المطلوبة: $missing');
  }

  /// Column key → index when the row contains every required header.
  static Map<String, int>? _headerIndex(List<Data?> row, List<ExcelColumn> columns) {
    final found = <String, int>{};
    for (var c = 0; c < row.length; c++) {
      final text = _normalize(cellText(row[c]?.value));
      if (text.isEmpty) continue;
      for (final column in columns) {
        final names = [column.header, ...column.aliases].map(_normalize);
        if (!found.containsKey(column.key) && names.contains(text)) {
          found[column.key] = c;
          break;
        }
      }
    }
    final complete = columns.where((column) => column.required).every((column) => found.containsKey(column.key));
    return complete ? found : null;
  }

  static String _normalize(String text) {
    return text
        .replaceAll('*', '')
        .replaceAll(RegExp(r'[\s_\-ـ]+'), '')
        .replaceAll(RegExp('[أإآ]'), 'ا')
        .replaceAll('ة', 'ه')
        .toLowerCase();
  }

  /// Any cell as plain text. Dates become yyyy-MM-dd and whole numbers lose their ".0".
  static String cellText(CellValue? value) {
    return switch (value) {
      null => '',
      TextCellValue() => value.value.toString().trim(),
      IntCellValue() => value.value.toString(),
      DoubleCellValue() =>
        value.value == value.value.roundToDouble() ? value.value.toInt().toString() : value.value.toString(),
      DateCellValue() => dateKey(DateTime(value.year, value.month, value.day)),
      DateTimeCellValue() => dateKey(DateTime(value.year, value.month, value.day)),
      BoolCellValue() => value.value ? '1' : '0',
      FormulaCellValue() => '',
      TimeCellValue() => value.toString(),
    };
  }

  /// Reads a date cell that may be text, a real Excel date or an Excel serial number.
  static String? dateText(String? text) {
    if (text == null) return null;
    final parsed = parseDate(text);
    if (parsed != null) return dateKey(parsed);
    final serial = int.tryParse(text);
    if (serial != null && serial > 20000 && serial < 80000) {
      return dateKey(DateTime(1899, 12, 30).add(Duration(days: serial)));
    }
    return null;
  }

  static TextCellValue? text(String? value) => value == null ? null : TextCellValue(value);

  static Sheet _sheet(Excel excel, String name) {
    // A new workbook starts with one empty "Sheet1"; reuse it for the first sheet.
    if (excel.tables.containsKey('Sheet1') && excel.tables.length == 1 && excel['Sheet1'].maxRows == 0) {
      excel.rename('Sheet1', name);
    }
    return excel[name];
  }
}
