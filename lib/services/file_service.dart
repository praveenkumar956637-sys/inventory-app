import 'dart:typed_data';
import 'dart:ui' show Rect;

import 'package:file_picker/file_picker.dart'
    show FilePicker, FileType, PlatformFile;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:share_plus/share_plus.dart'
    show ShareParams, SharePlus, ShareResult, ShareResultStatus, XFile;

import 'auth_service.dart';

/// A file the admin picked.
class PickedExcel {
  const PickedExcel({required this.name, required this.bytes});

  final String name;
  final Uint8List bytes;
}

/// Picks, saves and shares files. All package-specific calls live here.
class FileService {
  const FileService();

  static const String xlsxMimeType =
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';

  /// Lets the admin choose an Excel file. Returns null when cancelled.
  /// .xls is allowed in the picker only so the importer can explain that
  /// old .xls files are not supported.
  Future<PickedExcel?> pickExcel() async {
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: 'Choose an Excel file',
        type: FileType.custom,
        allowedExtensions: const <String>['xlsx', 'xls'],
      );
      if (file == null) return null;
      final Uint8List bytes = await file.readAsBytes();
      return PickedExcel(name: file.name, bytes: bytes);
    } catch (_) {
      throw const AppException('Could not open the file. Please try again.');
    }
  }

  /// Saves a file where the admin chooses (or downloads it on the web).
  /// Returns false when the admin cancels.
  Future<bool> saveBytes({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final Uri? saved = await FilePicker.saveFile(
        dialogTitle: 'Save Excel file',
        fileName: fileName,
        bytes: bytes,
        mimeType: xlsxMimeType,
        type: FileType.custom,
        allowedExtensions: const <String>['xlsx'],
      );
      // On the web the browser downloads the file and gives no result.
      return kIsWeb || saved != null;
    } catch (_) {
      throw const AppException('Could not save the file. Please try again.');
    }
  }

  /// Opens the share sheet (WhatsApp, email, Drive, ...).
  /// Returns true only when the system reports the share as completed.
  Future<bool> shareBytes({
    required String fileName,
    required Uint8List bytes,
    String? title,
    Rect? origin,
  }) async {
    try {
      final ShareResult result = await SharePlus.instance.share(
        ShareParams(
          title: title,
          files: <XFile>[XFile.fromData(bytes, mimeType: xlsxMimeType)],
          fileNameOverrides: <String>[fileName],
          sharePositionOrigin: origin,
        ),
      );
      return result.status == ShareResultStatus.success;
    } catch (_) {
      throw const AppException(
        'Could not open the share options. Please try again.',
      );
    }
  }
}
