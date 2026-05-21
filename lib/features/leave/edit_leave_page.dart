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
    _commentController.text = leave.employeeComment;
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
      totalLeave:
          LeaveRequest.calculateTotalLeave(_start!, _effectiveEnd!),
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

    return Scaffold(
      appBar: AppBar(title: const Text('Edit leave request')),
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

          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              DropdownButtonFormField<LeaveType>(
                initialValue: _leaveType,
                decoration: const InputDecoration(
                  labelText: 'Leave type',
                  border: OutlineInputBorder(),
                ),
                items: LeaveType.values
                    .map(
                      (t) => DropdownMenuItem(
                        value: t,
                        child: Text(t.displayLabel),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _leaveType = v),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('One-day leave'),
                value: _oneDay,
                onChanged: (v) => setState(() {
                  _oneDay = v;
                  if (_oneDay && _start != null) _end = _start;
                }),
              ),
              ListTile(
                title: Text(
                  _start == null
                      ? 'Start date'
                      : AppDateUtils.formatDate(_start!),
                ),
                trailing: const Icon(Icons.calendar_today),
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
              ListTile(
                enabled: !_oneDay,
                title: Text(
                  _effectiveEnd == null
                      ? 'End date'
                      : AppDateUtils.formatDate(_effectiveEnd!),
                ),
                trailing: const Icon(Icons.calendar_today),
                onTap: _oneDay
                    ? null
                    : () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _effectiveEnd ?? _start ?? DateTime.now(),
                          firstDate: _start ?? LeaveValidators.earliestLeaveDay(),
                          lastDate: LeaveValidators.latestLeaveDay(),
                        );
                        if (picked != null) setState(() => _end = picked);
                      },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _commentController,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Comment',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 24),
              PrimaryButton(
                label: 'Save changes',
                icon: Icons.save_outlined,
                onPressed: submit.isLoading ? null : () => _save(leave),
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

final _leaveByIdProvider =
    FutureProvider.family<LeaveRequest?, int>((ref, id) async {
  return ref.watch(leaveServiceProvider).fetchLeaveById(id);
});
