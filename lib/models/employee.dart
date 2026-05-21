class Employee {
  final int employeeID;
  final String name;
  final String role;
  final int id;
  final int? companyId;

  Employee({
    required this.employeeID,
    required this.name,
    required this.role,
    required this.id,
    this.companyId,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    final eid = json['employee_id'] ?? json['employeeID'];
    final pk = json['id'];
    return Employee(
      employeeID: eid as int,
      name: json['name'] as String,
      role: json['role'] as String,
      id: pk is int ? pk : int.parse(pk.toString()),
      companyId: json['company_id'] as int?,
    );
  }
}
