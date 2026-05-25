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

  // ==================== All your original methods (unchanged) ====================
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

  // ==================== Improved UI ====================
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

    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Apply for Leave'),
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Text(
              'New Leave Request',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Please fill in the details carefully',
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
                        Icon(Icons.visibility_outlined, color: colorScheme.primary),
                        const SizedBox(width: 10),
                        Text(
                          'Request Preview',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (_leaveType != null)
                      Row(
                        children: [
                          Icon(Icons.event_note, color: colorScheme.primary),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _leaveType!.displayLabel,
                              style: theme.textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        Chip(
                          avatar: const Icon(Icons.date_range, size: 18),
                          label: Text(
                            _start == null || _effectiveEnd == null
                                ? 'No dates selected'
                                : AppDateUtils.formatDateRange(_start!, _effectiveEnd!),
                          ),
                        ),
                        Chip(
                          avatar: const Icon(Icons.timelapse, size: 18),
                          label: Text(
                            _totalDays == null
                                ? 'Total: -'
                                : 'Total: $_totalDays day${_totalDays! > 1 ? 's' : ''}',
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 28),

            // Form Fields
            Text(
              'Leave Details',
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
                    // Leave Type
                    DropdownButtonFormField<LeaveType>(
                      value: _leaveType,
                      hint: const Text('Select leave type'),
                      decoration: InputDecoration(
                        labelText: 'Leave Type *',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: LeaveType.values
                          .map((t) => DropdownMenuItem(value: t, child: Text(t.displayLabel)))
                          .toList(),
                      onChanged: submit.isLoading
                          ? null
                          : (v) => setState(() => _leaveType = v),
                    ),

                    const SizedBox(height: 20),

                    // One Day Switch
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('One-day leave'),
                      subtitle: const Text('Start and end date will be the same'),
                      value: _oneDay,
                      onChanged: submit.isLoading
                          ? null
                          : (v) {
                              setState(() {
                                _oneDay = v;
                                if (v && _start != null) _end = _start;
                              });
                            },
                    ),

                    const SizedBox(height: 16),

                    // Dates
                    _buildDateTile(
                      title: 'Start Date',
                      value: _start,
                      onTap: submit.isLoading ? null : () => _pickDate(start: true),
                    ),

                    if (!_oneDay) ...[
                      const SizedBox(height: 12),
                      _buildDateTile(
                        title: 'End Date',
                        value: _effectiveEnd,
                        onTap: submit.isLoading ? null : () => _pickDate(start: false),
                      ),
                    ],

                    if (_leaveType != null && remaining != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer.withAlpha(40),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'Remaining balance this year: $remaining day(s)',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // Reason
                    TextField(
                      controller: _commentController,
                      maxLines: 4,
                      enabled: !submit.isLoading,
                      decoration: InputDecoration(
                        labelText: 'Reason / Comment (Optional)',
                        hintText: 'Please explain the purpose of your leave...',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        alignLabelWithHint: true,
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Attachment
                    OutlinedButton.icon(
                      onPressed: submit.isLoading ? null : _pickAttachment,
                      icon: const Icon(Icons.attach_file_rounded),
                      label: Text(
                        _pickedFileName ?? 'Attach supporting document (optional)',
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(double.infinity, 54),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),

                    if (_pickedFileName != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Chip(
                          label: Text(_pickedFileName!),
                          deleteIcon: const Icon(Icons.close),
                          onDeleted: submit.isLoading
                              ? null
                              : () => setState(() {
                                    _pickedFileName = null;
                                    _pickedBytes = null;
                                  }),
                        ),
                      ),

                    // Validation Message
                    if (!validation.isValid &&
                        _leaveType != null &&
                        (_start != null || _effectiveEnd != null))
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(Icons.error_outline, color: colorScheme.error),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                validation.message!,
                                style: TextStyle(color: colorScheme.error),
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 40),

            // Submit Button
            PrimaryButton(
              label: submit.isLoading ? 'Submitting...' : 'Submit Leave Request',
              icon: Icons.send_rounded,
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
                        builder: (context) => AlertDialog(
                          title: const Text('Confirm Submission'),
                          content: Text(
                            'Submit ${leaveType.displayLabel} from '
                            '${AppDateUtils.formatDate(_start!)} to '
                            '${AppDateUtils.formatDate(end)} '
                            '($total day${total > 1 ? 's' : ''})?',
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
                        ),
                      );

                      if (!mounted || ok != true) return;
                      await _submit(end: end, totalDays: total);
                    },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDateTile({
    required String title,
    required DateTime? value,
    required VoidCallback? onTap,
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