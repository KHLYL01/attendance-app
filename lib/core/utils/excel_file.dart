import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

const _mime = 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

/// Lets the user choose where to save an .xlsx file. Returns false when cancelled.
Future<bool> saveExcel(List<int> bytes, String filename) async {
  final data = bytes is Uint8List ? bytes : Uint8List.fromList(bytes);
  final path = await FilePicker.platform.saveFile(
    fileName: filename,
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    bytes: data,
  );
  if (path == null) return false;
  // Desktop pickers return the path without writing the bytes.
  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    await File(path).writeAsBytes(data, flush: true);
  }
  return true;
}

/// Opens the system share sheet with the file (WhatsApp, Drive, e-mail...).
Future<void> shareExcel(List<int> bytes, String filename) async {
  final directory = await getTemporaryDirectory();
  final file = File('${directory.path}/$filename');
  await file.writeAsBytes(bytes, flush: true);
  await Share.shareXFiles([XFile(file.path, mimeType: _mime, name: filename)]);
}

/// Asks the user for an .xlsx file and returns its bytes, or null when cancelled.
Future<List<int>?> pickExcel() async {
  final result = await FilePicker.platform.pickFiles(
    type: FileType.custom,
    allowedExtensions: const ['xlsx'],
    withData: true,
  );
  final file = result?.files.singleOrNull;
  if (file == null) return null;
  if (file.bytes != null) return file.bytes;
  if (file.path != null) return File(file.path!).readAsBytes();
  return null;
}
