import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/features/approval/approval_controller.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/providers/storage_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';
import 'package:url_launcher/url_launcher.dart';

class ApprovalDetailsPage extends ConsumerStatefulWidget {
  const ApprovalDetailsPage({super.key, required this.leaveId});

  final int leaveId;

  @override
  ConsumerState<ApprovalDetailsPage> createState() =>
      _ApprovalDetailsPageState();
}

class _ApprovalDetailsPageState extends ConsumerState<ApprovalDetailsPage> {
  final _adminCommentController = TextEditingController();

  @override
  void dispose() {
    _adminCommentController.dispose();
    super.dispose();
  }

  Future<void> _openAttachment(String path) async {
    try {
      final url = await ref.read(storageServiceProvider).getSignedUrl(path);
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not open attachment: $e')),
      );
    }
  }

  Future<void> _reject() async {
    final reasonController = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reject leave'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Rejection reason (required)',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;

    final reason = reasonController.text.trim();
    if (reason.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a rejection reason.')),
      );
      return;
    }

    await ref.read(approvalControllerProvider.notifier).reject(
          widget.leaveId,
          rejectedReason: reason,
          adminComment: _adminCommentController.text,
        );
    if (!mounted) return;
    final err = ref.read(approvalControllerProvider).error;
    if (err == null) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveDetailProvider(widget.leaveId));
    final action = ref.watch(approvalControllerProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Review leave')),
      body: async.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Request not found.'));
          }
          final leave = detail.request;
          final canAct = leave.status == AppConstants.leaveStatusPending;

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              _InfoRow(label: 'Employee', value: detail.employeeName),
              if (detail.employeeEmail != null)
                _InfoRow(label: 'Email', value: detail.employeeEmail!),
              _InfoRow(label: 'Company', value: detail.companyName),
              if (detail.groupName != null)
                _InfoRow(label: 'Group', value: detail.groupName!),
              _InfoRow(
                label: 'Dates',
                value: AppDateUtils.formatDateRange(leave.dateStart, leave.dateEnd),
              ),
              _InfoRow(label: 'Leave type', value: leave.leaveType.displayLabel),
              _InfoRow(label: 'Total days', value: '${leave.totalLeave}'),
              _InfoRow(label: 'Status', value: leave.status),
              const SizedBox(height: 16),
              Text(
                'Employee comment',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),
              Text(
                leave.employeeComment.isEmpty
                    ? '(none)'
                    : leave.employeeComment,
              ),
              if (leave.attachmentPath.isNotEmpty) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _openAttachment(leave.attachmentPath),
                  icon: const Icon(Icons.attach_file),
                  label: const Text('View attachment'),
                ),
              ],
              if (leave.rejectedReason.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Rejection reason',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
                Text(leave.rejectedReason),
              ],
              if (leave.adminComment.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  'Admin comment',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                Text(leave.adminComment),
              ],
              const SizedBox(height: 24),
              if (canAct) ...[
                TextField(
                  controller: _adminCommentController,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Admin comment (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                if (action.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      action.error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
                FilledButton(
                  onPressed: action.processingId == widget.leaveId
                      ? null
                      : () async {
                          await ref
                              .read(approvalControllerProvider.notifier)
                              .approve(
                                widget.leaveId,
                                adminComment: _adminCommentController.text,
                              );
                          if (!context.mounted) return;
                          if (ref.read(approvalControllerProvider).error ==
                              null) {
                            context.pop();
                          }
                        },
                  child: const Text('Approve'),
                ),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: action.processingId == widget.leaveId
                      ? null
                      : _reject,
                  child: const Text('Reject with reason'),
                ),
              ] else
                Text(
                  'This request is already ${leave.status}.',
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}
