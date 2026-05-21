class StaffDirectoryEntry {
  const StaffDirectoryEntry({
    required this.userId,
    required this.employeeId,
    required this.name,
    required this.email,
    required this.role,
    required this.staffType,
    required this.companyId,
    required this.companyName,
    this.groupName,
    this.managerName,
  });

  final String userId;
  final int employeeId;
  final String name;
  final String email;
  final String role;
  final String staffType;
  final int companyId;
  final String companyName;
  final String? groupName;
  final String? managerName;

  factory StaffDirectoryEntry.fromJson(Map<String, dynamic> json) {
    final company = json['company'];
    String companyName = '—';
    String? groupName;
    if (company is Map) {
      companyName = company['companyName'] as String? ?? companyName;
      final g = company['company_groups'];
      if (g is Map) groupName = g['groupName'] as String?;
    }

    return StaffDirectoryEntry(
      userId: json['id'] as String,
      employeeId: json['employee_id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      role: json['role'] as String,
      staffType: json['staff_type'] as String? ?? 'permanent',
      companyId: json['company_id'] as int,
      companyName: companyName,
      groupName: groupName,
      managerName: null,
    );
  }
}
