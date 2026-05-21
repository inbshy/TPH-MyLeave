class LeaveApprovalAudit {
  const LeaveApprovalAudit({
    required this.id,
    required this.leaveId,
    required this.actorName,
    required this.actorRole,
    required this.action,
    required this.comment,
    required this.createdAt,
  });

  final int id;
  final int leaveId;
  final String actorName;
  final String actorRole;
  final String action;
  final String comment;
  final DateTime createdAt;

  String get actionLabel => switch (action) {
        'manager_approved' => 'Manager approved',
        'final_approved' => 'Admin approved',
        'rejected' => 'Rejected',
        'cancelled' => 'Cancelled',
        _ => action,
      };

  factory LeaveApprovalAudit.fromJson(Map<String, dynamic> json) {
    return LeaveApprovalAudit(
      id: json['id'] as int,
      leaveId: json['leave_id'] as int,
      actorName: json['actor_name'] as String? ?? '—',
      actorRole: json['actor_role'] as String? ?? '',
      action: json['action'] as String,
      comment: json['comment'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
