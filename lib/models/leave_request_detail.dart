import 'package:tph_myleave/models/leave_request.dart';

class LeaveRequestDetail {
  const LeaveRequestDetail({
    required this.request,
    required this.employeeName,
    required this.companyName,
    this.groupName,
    this.employeeEmail,
  });

  final LeaveRequest request;
  final String employeeName;
  final String companyName;
  final String? groupName;
  final String? employeeEmail;
}
