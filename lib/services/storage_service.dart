import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';

class StorageService {
  final _client = SupabaseConfig.client;

  Future<String> uploadLeaveAttachment({
    required String userId,
    required Uint8List bytes,
    required String fileName,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    try {
      await _client.storage
          .from(AppConstants.storageLeaveAttachments)
          .uploadBinary(
            path,
            bytes,
            fileOptions: FileOptions(
              contentType: _contentType(fileName),
              upsert: true,
            ),
          );
    } on StorageException catch (e) {
      throw Exception(_uploadErrorMessage(e));
    }

    return path;
  }

  Future<String> getSignedUrl(String path) async {
    try {
      return await _client.storage
          .from(AppConstants.storageLeaveAttachments)
          .createSignedUrl(path, 3600);
    } on StorageException catch (e) {
      throw Exception(_uploadErrorMessage(e));
    }
  }

  static String _contentType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) {
      return 'image/jpeg';
    }
    if (lower.endsWith('.doc')) return 'application/msword';
    if (lower.endsWith('.docx')) {
      return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
    }
    return 'application/octet-stream';
  }

  static String _uploadErrorMessage(StorageException e) {
    final text = '${e.message} ${e.error}'.toLowerCase();
    if (text.contains('bucket') && text.contains('not found')) {
      return 'Storage bucket "leave-attachments" is missing. '
          'In Supabase SQL Editor, run: supabase/fix_storage_attachments.sql';
    }
    if (text.contains('policy') ||
        text.contains('row-level security') ||
        text.contains('403') ||
        text.contains('unauthorized')) {
      return 'Storage permission denied. '
          'In Supabase SQL Editor, run: supabase/fix_storage_attachments.sql';
    }
    final msg = e.message.trim();
    if (msg.isNotEmpty) return msg;
    final err = e.error?.toString().trim();
    if (err != null && err.isNotEmpty) return err;
    return 'Storage upload failed';
  }
}
