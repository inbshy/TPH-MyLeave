import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_type.dart';

class LeaveRequest {
  final int? id;
  final DateTime dateStart;
  final DateTime dateEnd;
  final LeaveType leaveType;
  final int employeeID;
  final int totalLeave;
  final String approveBy;
  final String status;
  final String employeeComment;
  final String attachmentPath;
  final String adminComment;
  final String rejectedReason;

  LeaveRequest({
    this.id,
    required this.dateStart,
    required this.dateEnd,
    required this.leaveType,
    required this.employeeID,
    required this.totalLeave,
    required this.approveBy,
    this.status = 'pending',
    this.employeeComment = '',
    this.attachmentPath = '',
    this.adminComment = '',
    this.rejectedReason = '',
  });

  factory LeaveRequest.fromJson(Map<String, dynamic> json) {
    return LeaveRequest(
      id: json['id'] as int?,
      dateStart: DateTime.parse(json['date_start'] as String),
      dateEnd: DateTime.parse(json['date_end'] as String),
      leaveType: LeaveType.fromStorage(json['leave_type'] as String?),
      employeeID: json['employeeID'] as int,
      totalLeave: json['totalLeave'] as int,
      approveBy: json['approveBy'] as String? ?? '',
      status: json['status'] as String? ?? 'pending',
      employeeComment: json['employee_comment'] as String? ?? '',
      attachmentPath: json['attachment_path'] as String? ?? '',
      adminComment: json['admin_comment'] as String? ?? '',
      rejectedReason: json['rejected_reason'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'date_start': dateStart.toIso8601String(),
      'date_end': dateEnd.toIso8601String(),
      'leave_type': leaveType.storageValue,
      'employeeID': employeeID,
      'totalLeave': totalLeave,
      'approveBy': approveBy,
      'status': status,
      'employee_comment': employeeComment,
      'attachment_path': attachmentPath,
      'admin_comment': adminComment,
      'rejected_reason': rejectedReason,
    };
  }

  Map<String, dynamic> toInsertJson() {
    final m = toJson();
    m.remove('id');
    return m;
  }

  static int calculateTotalLeave(DateTime start, DateTime end) {
    final s = DateTime(start.year, start.month, start.day);
    final e = DateTime(end.year, end.month, end.day);
    return AppDateUtils.inclusiveDays(s, e);
  }
}
