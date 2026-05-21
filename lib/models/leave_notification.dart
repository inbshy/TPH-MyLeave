class LeaveNotification {
  const LeaveNotification({
    required this.id,
    required this.title,
    required this.body,
    this.leaveId,
    required this.createdAt,
    this.readAt,
  });

  final int id;
  final String title;
  final String body;
  final int? leaveId;
  final DateTime createdAt;
  final DateTime? readAt;

  bool get isRead => readAt != null;

  factory LeaveNotification.fromJson(Map<String, dynamic> json) {
    return LeaveNotification(
      id: json['id'] as int,
      title: json['title'] as String,
      body: json['body'] as String,
      leaveId: json['leave_id'] as int?,
      createdAt: DateTime.parse(json['created_at'] as String),
      readAt: json['read_at'] != null
          ? DateTime.parse(json['read_at'] as String)
          : null,
    );
  }
}
