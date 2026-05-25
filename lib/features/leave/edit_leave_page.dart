import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/core/utils/leave_validators.dart';
import 'package:tph_myleave/features/leave/leave_controller.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class EditLeavePage extends ConsumerStatefulWidget {
  const EditLeavePage({super.key, required this.leaveId});

  final int leaveId;

  @override
  ConsumerState<EditLeavePage> createState() => _EditLeavePageState();
}

class _EditLeavePageState extends ConsumerState<EditLeavePage> {
  LeaveType? _leaveType;
  DateTime? _start;
  DateTime? _end;
  bool _oneDay = false;
  final _commentController = TextEditingController();
  bool _initialized = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  void _initFrom(LeaveRequest leave) {
    if (_initialized) return;
    _initialized = true;
    _leaveType = leave.leaveType;
    _start = leave.dateStart;
    _end = leave.dateEnd;
    _oneDay = leave.dateStart.year == leave.dateEnd.year &&
        leave.dateStart.month == leave.dateEnd.month &&
        leave.dateStart.day == leave.dateEnd.day;
    _commentController.text = leave.employeeComment ?? '';
  }

  DateTime? get _effectiveEnd => _oneDay ? _start : _end;

  Future<void> _save(LeaveRequest original) async {
    if (_leaveType == null || _start == null || _effectiveEnd == null) return;

    final updated = LeaveRequest(
      id: original.id,
      dateStart: LeaveValidators.dateOnly(_start!),
      dateEnd: LeaveValidators.dateOnly(_effectiveEnd!),
      leaveType: _leaveType!,
      employeeID: original.employeeID,
      totalLeave: LeaveRequest.calculateTotalLeave(_start!, _effectiveEnd!),
      approveBy: original.approveBy,
      status: original.status,
      employeeComment: _commentController.text.trim(),
      attachmentPath: original.attachmentPath,
    );

    await ref.read(leaveFormControllerProvider.notifier).updatePending(updated);
    final err = ref.read(leaveFormControllerProvider).error;
    if (!mounted) return;
    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(_leaveByIdProvider(widget.leaveId));
    final submit = ref.watch(leaveFormControllerProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Leave Request'),
        elevation: 0,
      ),
      body: async.when(
        data: (leave) {
          if (leave == null) {
            return const Center(child: Text('Request not found.'));
          }
          if (!AppConstants.isPendingLeaveStatus(leave.status)) {
            return const Center(
              child: Text('Only pending requests can be edited.'),
            );
          }

          _initFrom(leave);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit Leave Request',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Make changes to your pending request',
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),

                const SizedBox(height: 32),

                // Preview Card
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
                            Icon(Icons.edit_note, color: colorScheme.primary),
                            const SizedBox(width: 10),
                            Text(
                              'Current Request',
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Text(
                          leave.leaveType.displayLabel,
                          style: theme.textTheme.titleMedium,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          AppDateUtils.formatDateRange(leave.dateStart, leave.dateEnd),
                          style: theme.textTheme.bodyLarge,
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                // Edit Form
                Text(
                  'Update Details',
                  style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 16),

                Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        DropdownButtonFormField<LeaveType>(
                          value: _leaveType,
                          decoration: InputDecoration(
                            labelText: 'Leave Type',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          ),
                          items: LeaveType.values
                              .map((t) => DropdownMenuItem(
                                    value: t,
                                    child: Text(t.displayLabel),
                                  ))
                              .toList(),
                          onChanged: (v) => setState(() => _leaveType = v),
                        ),

                        const SizedBox(height: 20),

                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('One-day leave'),
                          subtitle: const Text('Start and end date will be the same'),
                          value: _oneDay,
                          onChanged: (v) => setState(() {
                            _oneDay = v;
                            if (v && _start != null) _end = _start;
                          }),
                        ),

                        const SizedBox(height: 16),

                        _buildDateTile(
                          title: 'Start Date',
                          value: _start,
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: context,
                              initialDate: _start ?? DateTime.now(),
                              firstDate: LeaveValidators.earliestLeaveDay(),
                              lastDate: LeaveValidators.latestLeaveDay(),
                            );
                            if (picked != null) {
                              setState(() {
                                _start = picked;
                                if (_oneDay) _end = picked;
                              });
                            }
                          },
                        ),

                        if (!_oneDay) ...[
                          const SizedBox(height: 12),
                          _buildDateTile(
                            title: 'End Date',
                            value: _effectiveEnd,
                            onTap: () async {
                              final picked = await showDatePicker(
                                context: context,
                                initialDate: _effectiveEnd ?? _start ?? DateTime.now(),
                                firstDate: _start ?? LeaveValidators.earliestLeaveDay(),
                                lastDate: LeaveValidators.latestLeaveDay(),
                              );
                              if (picked != null) {
                                setState(() => _end = picked);
                              }
                            },
                          ),
                        ],

                        const SizedBox(height: 24),

                        TextField(
                          controller: _commentController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            labelText: 'Reason / Comment',
                            hintText: 'Update your reason if needed...',
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                            alignLabelWithHint: true,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 40),

                PrimaryButton(
                  label: submit.isLoading ? 'Saving Changes...' : 'Save Changes',
                  icon: Icons.save_rounded,
                  onPressed: submit.isLoading ? null : () => _save(leave),
                ),
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

  Widget _buildDateTile({
    required String title,
    required DateTime? value,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: title,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          suffixIcon: const Icon(Icons.calendar_today_outlined),
        ),
        child: Text(
          value != null ? AppDateUtils.formatDate(value) : 'Select date',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

final _leaveByIdProvider = FutureProvider.family<LeaveRequest?, int>((ref, id) async {
  return ref.watch(leaveServiceProvider).fetchLeaveById(id);
});