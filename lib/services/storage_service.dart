import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';

class StorageService {
  final _client = SupabaseConfig.client;

  Future<String> uploadLeaveAttachment({
    required String userId,
    required String fileName,
    required Uint8List bytes,
  }) async {
    final safeName = fileName.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path = '$userId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _client.storage.from(AppConstants.storageLeaveAttachments).uploadBinary(
          path,
          bytes,
          fileOptions: const FileOptions(upsert: false),
        );

    return path;
  }

  Future<String> getSignedUrl(String path) async {
    if (path.isEmpty) return '';
    return _client.storage
        .from(AppConstants.storageLeaveAttachments)
        .createSignedUrl(path, 3600);
  }
}
