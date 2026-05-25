import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_type.dart';

/// Result of validating a leave application form.
class LeaveValidationResult {
  const LeaveValidationResult._({required this.isValid, this.message});

  const LeaveValidationResult.valid() : this._(isValid: true);

  const LeaveValidationResult.invalid(String message)
      : this._(isValid: false, message: message);

  final bool isValid;
  final String? message;
}

/// Rules for employee leave applications.
class LeaveValidators {
  LeaveValidators._(); 

  /// Earliest selectable leave day (today, local calendar).
  static DateTime earliestLeaveDay([DateTime? appliedOn]) {
    final now = appliedOn ?? DateTime.now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Latest selectable leave day (default: 2 years ahead).
  static DateTime latestLeaveDay([DateTime? appliedOn]) {
    final base = appliedOn ?? DateTime.now();
    return DateTime(base.year + 2, 12, 31);
  }

  static int? maxDaysPerRequest(LeaveType type) => type.maxDaysPerRequest;

  static DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Validates leave type and date range relative to [appliedOn] (defaults to now).
  static LeaveValidationResult validate({
    required LeaveType? leaveType,
    required DateTime? start,
    required DateTime? end,
    DateTime? appliedOn,
    int? remainingDaysThisYear,
  }) {
    if (leaveType == null) {
      return const LeaveValidationResult.invalid('Please select a leave type.');
    }
    if (start == null) {
      return const LeaveValidationResult.invalid('Please select a start date.');
    }
    if (end == null) {
      return const LeaveValidationResult.invalid('Please select an end date.');
    }

    final applied = dateOnly(appliedOn ?? DateTime.now());
    final startDay = dateOnly(start);
    final endDay = dateOnly(end);

    if (startDay.isBefore(applied)) {
      return LeaveValidationResult.invalid(
        'Start date cannot be before today (${AppDateUtils.formatDate(applied)}).',
      );
    }

    if (endDay.isBefore(applied)) {
      return LeaveValidationResult.invalid(
        'End date cannot be before today (${AppDateUtils.formatDate(applied)}).',
      );
    }

    if (endDay.isBefore(startDay)) {
      return const LeaveValidationResult.invalid(
        'End date cannot be earlier than the start date.',
      );
    }

    final totalDays = AppDateUtils.inclusiveDays(startDay, endDay);
    if (totalDays < 1) {
      return const LeaveValidationResult.invalid(
        'Leave must be at least 1 day.',
      );
    }

    final maxDays = maxDaysPerRequest(leaveType);
    if (maxDays != null && totalDays > maxDays) {
      return LeaveValidationResult.invalid(
        '${leaveType.displayLabel} cannot exceed $maxDays day(s) per request.',
      );
    }

    if (remainingDaysThisYear != null && totalDays > remainingDaysThisYear) {
      return LeaveValidationResult.invalid(
        'Only $remainingDaysThisYear day(s) remaining for '
        '${leaveType.displayLabel} this year.',
      );
    }

    final latest = latestLeaveDay(appliedOn);
    if (startDay.isAfter(latest) || endDay.isAfter(latest)) {
      return LeaveValidationResult.invalid(
        'Leave cannot be scheduled after ${AppDateUtils.formatDate(latest)}.',
      );
    }

    return const LeaveValidationResult.valid();
  }
}
