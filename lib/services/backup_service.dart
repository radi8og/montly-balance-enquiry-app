import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'storage_service.dart';

bool get _isDesktop =>
    !kIsWeb && (Platform.isWindows || Platform.isLinux || Platform.isMacOS);

/// Thrown when a picked backup file doesn't have the expected MonoBal
/// backup structure.
class InvalidBackupException implements Exception {
  final String message;
  InvalidBackupException(this.message);

  @override
  String toString() => message;
}

/// Handles exporting all app data to a shareable JSON file, and restoring
/// from a previously exported file.
class BackupService {
  final StorageService storage;

  BackupService(this.storage);

  String _todayFilename() {
    final now = DateTime.now();
    final y = now.year.toString().padLeft(4, '0');
    final m = now.month.toString().padLeft(2, '0');
    final d = now.day.toString().padLeft(2, '0');
    return 'monobal_backup_${y}_${m}_$d.json';
  }

  /// Builds the backup JSON file and saves/shares it depending on platform.
  /// Returns the saved file path on desktop (null if the user cancelled the
  /// save dialog), or null on mobile since the share sheet handles the rest.
  /// Throws on failure — callers should wrap this in a try/catch and show
  /// a SnackBar.
  Future<String?> exportAndShare() async {
    final data = await storage.exportAllData();
    final jsonStr = const JsonEncoder.withIndent('  ').convert(data);
    final filename = _todayFilename();

    if (_isDesktop) {
      final savedPath = await FilePicker.platform.saveFile(
        dialogTitle: 'Save Backup',
        fileName: filename,
        bytes: Uint8List.fromList(utf8.encode(jsonStr)),
      );
      return savedPath; // null if the user cancelled the dialog
    }

    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/$filename');
    await file.writeAsString(jsonStr);

    await Share.shareXFiles(
      [XFile(file.path)],
      text: 'MonoBal backup',
    );
    return null;
  }

  /// Lets the user pick a .json backup file, validates its structure, and
  /// returns the decoded data WITHOUT writing it yet — the caller is
  /// expected to show a confirmation dialog before calling [applyRestore].
  ///
  /// Returns null if the user cancelled the file picker.
  /// Throws [InvalidBackupException] if the file isn't a valid backup.
  Future<Map<String, dynamic>?> pickAndValidateBackup() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );

    if (result == null || result.files.single.path == null) {
      return null; // user cancelled
    }

    final file = File(result.files.single.path!);
    final content = await file.readAsString();

    late final dynamic decoded;
    try {
      decoded = jsonDecode(content);
    } on FormatException {
      throw InvalidBackupException('That file isn\'t valid JSON.');
    }

    if (decoded is! Map<String, dynamic>) {
      throw InvalidBackupException('That file isn\'t a MonoBal backup.');
    }
    if (!storage.isValidBackup(decoded)) {
      throw InvalidBackupException(
          'That file is missing expected MonoBal backup data.');
    }

    return decoded;
  }

  /// Actually overwrites local storage with the given (already-validated)
  /// backup data. Call only after the user has confirmed the overwrite.
  Future<void> applyRestore(Map<String, dynamic> data) async {
    await storage.importAllData(data);
  }
}