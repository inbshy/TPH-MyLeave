import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/leave_csv_export.dart';
import 'package:tph_myleave/providers/admin_report_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';

Future<void> exportAdminLeaveCsv(BuildContext context, WidgetRef ref) async {
  final companyId = ref.read(adminSelectedCompanyIdProvider);
  final messenger = ScaffoldMessenger.of(context);

  try {
    messenger.showSnackBar(
      const SnackBar(content: Text('Preparing export…')),
    );
    final rows = await ref.read(leaveServiceProvider).fetchLeaveDetailsForExport(
          companyId: companyId,
          year: DateTime.now().year,
        );
    final csv = LeaveCsvExport.build(rows);
    final bytes = utf8.encode(csv);

    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'Save leave report',
      fileName: 'leave_report_${DateTime.now().year}.csv',
      type: FileType.custom,
      allowedExtensions: ['csv'],
      bytes: bytes,
    );

    if (!context.mounted) return;
    if (path != null) {
      messenger.showSnackBar(
        SnackBar(content: Text('Saved to $path')),
      );
    } else {
      messenger.showSnackBar(
        const SnackBar(content: Text('Export cancelled.')),
      );
    }
  } catch (e) {
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text('Export failed: $e')),
    );
  }
}
