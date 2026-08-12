import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import 'flowdo_data_sync_adapter.dart';

/// 端末内の JSON ファイル経由でエクスポート／インポートする。
class LocalFileDataSyncAdapter implements FlowDoDataSyncAdapter {
  const LocalFileDataSyncAdapter();

  @override
  Future<String?> pickImportJson() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['json'],
      withData: true,
      allowMultiple: false,
    );

    if (result == null || result.files.isEmpty) return null;

    final file = result.files.single;
    if (file.bytes != null) {
      return utf8.decode(file.bytes!);
    }

    final path = file.path;
    if (path == null) return null;

    try {
      return await File(path).readAsString();
    } catch (error, stack) {
      debugPrint('Failed to read import file: $error');
      debugPrint(stack.toString());
      return null;
    }
  }

  @override
  Future<void> shareExportJson({
    required String json,
    required String fileName,
  }) async {
    if (kIsWeb) {
      await Share.share(json, subject: fileName);
      return;
    }

    final directory = await getTemporaryDirectory();
    final file = File('${directory.path}/$fileName');
    await file.writeAsString(json, flush: true);

    await Share.shareXFiles(
      [XFile(file.path, mimeType: 'application/json', name: fileName)],
      subject: 'FlowDo バックアップ',
      text: 'FlowDo のタスクとカテゴリーのバックアップ',
    );
  }
}
