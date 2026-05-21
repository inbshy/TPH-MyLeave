import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/core/utils/leave_validators.dart';
import 'package:tph_myleave/features/leave/leave_controller.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/employee_provider.dart';
import 'package:tph_myleave/providers/leave_balance_provider.dart';
import 'package:tph_myleave/providers/storage_provider.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class ApplyLeavePage extends ConsumerStatefulWidget {
  const ApplyLeavePage({super.key});

  @override
  ConsumerState<ApplyLeavePage> createState() => _ApplyLeavePageState();
}

class _ApplyLeavePageState extends ConsumerState<ApplyLeavePage> {
  final _commentController = TextEditingController();
  LeaveType? _leaveType;
  DateTime? _start;
  DateTime? _end;
  bool _oneDay = false;
  String? _pickedFileName;
  Uint8List? _pickedBytes;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _pickAttachment() async {
    final result = await FilePicker.platform.pickFiles(
      withData: true,
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    if (file.bytes == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not read file. Try another file.')),
      );
      return;
    }
    setState(() {
      _pickedFileName = file.name;
      _pickedBytes = file.bytes;
    });
  }

  DateTime get _today => LeaveValidators.earliestLeaveDay();

  DateTime get _maxDate => LeaveValidators.latestLeaveDay();

  DateTime? get _effectiveEnd => _oneDay ? _start : _end;

  int? get _totalDays =>
      (_start != null && _effectiveEnd != null)
          ? LeaveRequest.calculateTotalLeave(_start!, _effectiveEnd!)
          : null;

  int? _remainingDays(WidgetRef ref) {
    if (_leaveType == null) return null;
    final balances = ref.watch(myLeaveBalancesProvider).valueOrNull;
    if (balances == null) return null;
    return LeaveBalanceCalculator.entryForType(balances, _leaveType!)
        ?.remainingDays;
  }

  LeaveValidationResult _validation(WidgetRef ref) => LeaveValidators.validate(
        leaveType: _leaveType,
        start: _start,
        end: _effectiveEnd,
        remainingDaysThisYear: _remainingDays(ref),
      );

  Future<void> _pickDate({required bool start}) async {
    final earliest = _today;
    final latest = _maxDate;

    final initial = start
        ? (_start ?? earliest)
        : (_effectiveEnd ?? _start ?? earliest);

    final firstDate = start
        ? earliest
        : (_start != null && _start!.isAfter(earliest) ? _start! : earliest);

    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(firstDate)
          ? firstDate
          : (initial.isAfter(latest) ? latest : initial),
      firstDate: firstDate,
      lastDate: latest,
    );

    if (picked != null) {
      setState(() {
        final day = LeaveValidators.dateOnly(picked);
        if (start) {
          _start = day;
          if (_oneDay) {
            _end = day;
          } else {
            _end ??= day;
            if (_end!.isBefore(_start!)) _end = _start;
          }
        } else {
          _end = day;
          if (_start != null && _end!.isBefore(_start!)) {
            _end = _start;
          }
        }
      });
    }
  }

  void _showValidationError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> _submit({required DateTime end, required int totalDays}) async {
    final check = LeaveValidators.validate(
      leaveType: _leaveType,
      start: _start,
      end: end,
      remainingDaysThisYear: _remainingDays(ref),
    );
    if (!check.isValid) {
      _showValidationError(check.message!);
      return;
    }

    final user = ref.read(authProvider).user;
    if (user == null) return;

    final eid =
        await ref.read(employeeServiceProvider).resolveEmployeeIdForUser(user.id);
    if (eid == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Your profile has no employee id. Ask an admin to link your account.',
          ),
        ),
      );
      return;
    }

    var attachmentPath = '';
    if (_pickedBytes != null && _pickedFileName != null) {
      try {
        attachmentPath = await ref.read(storageServiceProvider).uploadLeaveAttachment(
              userId: user.id,
              bytes: _pickedBytes!,
              fileName: _pickedFileName!,
            );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: $e')),
        );
        return;
      }
    }

    final request = LeaveRequest(
      dateStart: LeaveValidators.dateOnly(_start!),
      dateEnd: LeaveValidators.dateOnly(end),
      leaveType: _leaveType!,
      employeeID: eid,
      totalLeave: totalDays,
      approveBy: '',
      employeeComment: _commentController.text.trim(),
      attachmentPath: attachmentPath,
    );

    await ref.read(leaveFormControllerProvider.notifier).submit(request);

    final err = ref.read(leaveFormControllerProvider).error;
    if (!mounted) return;

    if (err != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Leave submitted.')),
    );
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    if (!AppConstants.canApplyLeave(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final submit = ref.watch(leaveFormControllerProvider);
    final validation = _validation(ref);
    final remaining = _remainingDays(ref);
    final canSubmit = !submit.isLoading &&
        _leaveType != null &&
        _start != null &&
        _effectiveEnd != null &&
        _totalDays != null &&
        validation.isValid;

    final errorColor = Theme.of(context).colorScheme.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Apply for leave')),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Text(
            'Leave request preview',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.event_note_outlined,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        _leaveType?.displayLabel ?? 'Select leave type',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    children: [
                      Chip(
                        label: Text(
                          _start == null || _effectiveEnd == null
                              ? 'Pick dates'
                              : AppDateUtils.formatDateRange(
                                  _start!,
                                  _effectiveEnd!,
                                ),
                        ),
                      ),
                      Chip(
                        label: Text(
                          _totalDays == null
                              ? 'Total: -'
                              : 'Total: $_totalDays day(s)',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'After submitting, your request will be sent to an approver.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Details',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Rules: dates cannot be before today; end must be on or after start. '
            '${LeaveType.rulesSummary()}.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Leave type',
                      border: OutlineInputBorder(),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<LeaveType>(
                        isExpanded: true,
                        value: _leaveType,
                        hint: const Text('Select type'),
                        items: LeaveType.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(t.displayLabel),
                              ),
                            )
                            .toList(),
                        onChanged: submit.isLoading
                            ? null
                            : (v) => setState(() => _leaveType = v),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('One-day leave'),
                    subtitle: Text(
                      _start == null
                          ? 'Select a start date first'
                          : 'End date will match the start date',
                    ),
                    value: _oneDay,
                    onChanged: submit.isLoading
                        ? null
                        : (v) {
                            setState(() {
                              _oneDay = v;
                              if (_oneDay && _start != null) {
                                _end = _start;
                              }
                              if (!_oneDay && _end == null && _start != null) {
                                _end = _start;
                              }
                            });
                          },
                  ),
                  const SizedBox(height: 8),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _start == null
                          ? 'Start date'
                          : AppDateUtils.formatDate(_start!),
                    ),
                    subtitle: const Text('Cannot be before today'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: submit.isLoading ? null : () => _pickDate(start: true),
                  ),
                  ListTile(
                    enabled: !_oneDay,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      _effectiveEnd == null
                          ? 'End date'
                          : AppDateUtils.formatDate(_effectiveEnd!),
                    ),
                    subtitle: const Text('Must be on or after start date'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: (submit.isLoading || _oneDay)
                        ? null
                        : () => _pickDate(start: false),
                  ),
                  if (_leaveType != null && remaining != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      'Remaining this year: $remaining day(s)',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    controller: _commentController,
                    maxLines: 4,
                    enabled: !submit.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Comment / reason (optional)',
                      hintText: 'Explain your leave request…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: submit.isLoading ? null : _pickAttachment,
                    icon: const Icon(Icons.upload_file),
                    label: Text(
                      _pickedFileName ?? 'Upload supporting letter (optional)',
                    ),
                  ),
                  if (_pickedFileName != null)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton(
                        onPressed: submit.isLoading
                            ? null
                            : () => setState(() {
                                  _pickedFileName = null;
                                  _pickedBytes = null;
                                }),
                        child: const Text('Remove attachment'),
                      ),
                    ),
                  if (!validation.isValid &&
                      _leaveType != null &&
                      (_start != null || _effectiveEnd != null)) ...[
                    const SizedBox(height: 12),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.error_outline, size: 20, color: errorColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            validation.message!,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: errorColor),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          PrimaryButton(
            label: submit.isLoading ? 'Submitting…' : 'Submit request',
            onPressed: !canSubmit
                ? null
                : () async {
                    final end = _effectiveEnd!;
                    final total = _totalDays!;
                    final leaveType = _leaveType!;

                    final check = LeaveValidators.validate(
                      leaveType: leaveType,
                      start: _start,
                      end: end,
                      remainingDaysThisYear: _remainingDays(ref),
                    );
                    if (!check.isValid) {
                      _showValidationError(check.message!);
                      return;
                    }

                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (context) {
                        return AlertDialog(
                          title: const Text('Confirm submission'),
                          content: Text(
                            'Submit ${leaveType.displayLabel} from '
                            '${AppDateUtils.formatDate(_start!)} to '
                            '${AppDateUtils.formatDate(end)} '
                            '($total day(s))?',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Confirm'),
                            ),
                          ],
                        );
                      },
                    );

                    if (!mounted || ok != true) return;
                    await _submit(end: end, totalDays: total);
                  },
          ),
        ],
      ),
    );
  }
}
