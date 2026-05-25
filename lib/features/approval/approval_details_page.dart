import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/features/approval/approval_controller.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/providers/storage_provider.dart';
import 'package:tph_myleave/widgets/approval_audit_timeline.dart';
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
        title: const Text('Reject Leave Request'),
        content: TextField(
          controller: reasonController,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: 'Rejection Reason (required)',
            border: OutlineInputBorder(),
            hintText: 'Please provide a clear reason...',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Reject Request'),
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
          leaveId: widget.leaveId,
          rejectedReason: reason,
          adminComment: _adminCommentController.text.trim(),
        );

    if (!mounted) return;
    final state = ref.read(approvalControllerProvider);
    if (state.error == null) {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(leaveDetailProvider(widget.leaveId));
    final action = ref.watch(approvalControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final role = ref.watch(authProvider).role;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Leave Request'),
        elevation: 0,
      ),
      body: async.when(
        data: (detail) {
          if (detail == null) {
            return const Center(child: Text('Request not found.'));
          }

          final leave = detail.request;
          final canAct = AppConstants.isPendingLeaveStatus(leave.status);
          final approveLabel = role == AppConstants.roleAdmin
              ? 'Approve'
              : 'Approve (Send to Admin)';

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.person_outline, color: colorScheme.primary),
                            const SizedBox(width: 12),
                            Text(
                              detail.employeeName,
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        if (detail.employeeEmail != null) ...[
                          const SizedBox(height: 4),
                          Text(
                            detail.employeeEmail!,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _InfoRow(label: 'Company', value: detail.companyName),
                        if (detail.groupName != null)
                          _InfoRow(label: 'Group', value: detail.groupName!),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Leave Details Card
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Leave Details',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        _InfoRow(
                          label: 'Dates',
                          value: AppDateUtils.formatDateRange(leave.dateStart, leave.dateEnd),
                        ),
                        _InfoRow(label: 'Leave Type', value: leave.leaveType.displayLabel),
                        _InfoRow(label: 'Total Days', value: '${leave.totalLeave}'),
                        _InfoRow(
                          label: 'Status',
                          value: AppConstants.pendingStatusLabel(leave.status),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Employee Comment
                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Employee Comment',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          leave.employeeComment.isEmpty
                              ? '(No comment provided)'
                              : leave.employeeComment,
                          style: theme.textTheme.bodyLarge,
                        ),
                        if (leave.attachmentPath.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          OutlinedButton.icon(
                            onPressed: () => _openAttachment(leave.attachmentPath),
                            icon: const Icon(Icons.attach_file_rounded),
                            label: const Text('View Supporting Document'),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 48),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // Rejection / Admin Comment (if exists)
                if (leave.rejectedReason.isNotEmpty || leave.adminComment.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (leave.rejectedReason.isNotEmpty) ...[
                            Text(
                              'Rejection Reason',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                                color: colorScheme.error,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(leave.rejectedReason),
                          ],
                          if (leave.adminComment.isNotEmpty) ...[
                            if (leave.rejectedReason.isNotEmpty) const SizedBox(height: 16),
                            Text(
                              'Admin Comment',
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(leave.adminComment),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                ApprovalAuditTimeline(leaveId: widget.leaveId),

                // Action Section
                if (canAct) ...[
                  const SizedBox(height: 32),
                  Text(
                    'Your Decision',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Admin Comment
                  TextField(
                    controller: _adminCommentController,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'Comment (Optional)',
                      hintText: 'Add any notes for the employee...',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Error Message
                  if (action.error != null)
                    Container(
                      padding: const EdgeInsets.all(12),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer.withAlpha(30),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: colorScheme.error),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              action.error!,
                              style: TextStyle(color: colorScheme.error),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Approve Button
                  FilledButton.icon(
                    onPressed: action.processingId == widget.leaveId
                        ? null
                        : () async {
                            await ref
                                .read(approvalControllerProvider.notifier)
                                .approve(
                                  widget.leaveId,
                                  adminComment: _adminCommentController.text.trim(),
                                );
                            if (!mounted) return;
                            if (ref.read(approvalControllerProvider).error == null) {
                              context.pop();
                            }
                          },
                    icon: action.processingId == widget.leaveId
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(approveLabel),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      backgroundColor: Colors.green.shade600,
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Reject Button
                  OutlinedButton.icon(
                    onPressed: action.processingId == widget.leaveId ? null : _reject,
                    icon: const Icon(Icons.cancel_outlined),
                    label: const Text('Reject with Reason'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(double.infinity, 54),
                      foregroundColor: colorScheme.error,
                    ),
                  ),
                ] else ...[
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: colorScheme.primary),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'This request is already ${leave.status}.',
                            style: theme.textTheme.bodyLarge,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
        loading: () => const AppLoadingIndicator(message: 'Loading request...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Error: $e'),
          ),
        ),
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
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}