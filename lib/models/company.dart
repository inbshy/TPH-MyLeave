class Company {
  final int id;
  final String companyName;
  final int? groupId;
  final String? groupName;

  Company({
    required this.id,
    required this.companyName,
    this.groupId,
    this.groupName,
  });

  factory Company.fromJson(Map<String, dynamic> json) {
    final rawId = json['company_id'] ?? json['id'];
    final group = json['company_groups'];
    String? groupName;
    int? groupId;
    if (group is Map) {
      groupName = group['groupName'] as String?;
      groupId = group['group_id'] as int?;
    }
    groupId ??= json['group_id'] as int?;

    return Company(
      id: rawId as int,
      companyName: json['companyName'] as String,
      groupId: groupId,
      groupName: groupName,
    );
  }

  Map<String, dynamic> toJson() => {
        'company_id': id,
        'companyName': companyName,
        if (groupId != null) 'group_id': groupId,
      };

  Map<String, dynamic> toInsertJson({required String name, required int groupId}) =>
      {
        'companyName': name.trim(),
        'group_id': groupId,
      };
}
