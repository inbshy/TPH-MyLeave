class CompanyGroup {
  const CompanyGroup({required this.id, required this.groupName});

  final int id;
  final String groupName;

  factory CompanyGroup.fromJson(Map<String, dynamic> json) {
    return CompanyGroup(
      id: json['group_id'] as int,
      groupName: json['groupName'] as String,
    );
  }

  Map<String, dynamic> toInsertJson(String name) => {'groupName': name.trim()};
}
