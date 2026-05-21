/// Leave categories stored in Supabase as snake_case strings.
enum LeaveType {
  annual,
  sick,
  maternity,
  hospitalisation,
  paternity,
  compassionate,
  unpaid;

  String get storageValue => name;

  /// Annual entitlement (days per calendar year); `null` = unlimited.
  int? get yearlyEntitlement => switch (this) {
        LeaveType.annual => 20,
        LeaveType.sick => 14,
        LeaveType.maternity => 30,
        LeaveType.hospitalisation => 60,
        LeaveType.paternity => 7,
        LeaveType.compassionate => 5,
        LeaveType.unpaid => null,
      };

  /// Max days per single request; `null` = no limit (unpaid leave).
  int? get maxDaysPerRequest => yearlyEntitlement;

  String get displayLabel => switch (this) {
        LeaveType.annual => 'Annual Leave',
        LeaveType.sick => 'Sick Leave',
        LeaveType.maternity => 'Maternity Leave',
        LeaveType.hospitalisation => 'Hospitalisation Leave',
        LeaveType.paternity => 'Paternity Leave',
        LeaveType.compassionate => 'Compassionate Leave',
        LeaveType.unpaid => 'Unpaid Leave',
      };

  static LeaveType fromStorage(String? value) {
    switch (value) {
      case 'annual':
      case 'el':
        return LeaveType.annual;
      case 'sick':
      case 'mc':
        return LeaveType.sick;
      case 'maternity':
        return LeaveType.maternity;
      case 'hospitalisation':
        return LeaveType.hospitalisation;
      case 'paternity':
        return LeaveType.paternity;
      case 'compassionate':
        return LeaveType.compassionate;
      case 'unpaid':
        return LeaveType.unpaid;
      default:
        return LeaveType.annual;
    }
  }

  /// One-line summary of per-type limits for the apply-leave form.
  static String rulesSummary() {
    final parts = LeaveType.values.map((t) {
      final max = t.maxDaysPerRequest;
      if (max == null) {
        return '${t.displayLabel}: no day limit';
      }
      return '${t.displayLabel}: max $max day(s)';
    });
    return parts.join(' · ');
  }
}
