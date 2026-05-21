import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';

class LeaveCsvExport {
  LeaveCsvExport._();

  static String build(List<LeaveRequestDetail> rows) {
    final buffer = StringBuffer();
    buffer.writeln(
      'Employee,Email,Company,Group,Leave Type,Start,End,Days,Status,Comment',
    );
    for (final d in rows) {
      final r = d.request;
      buffer.writeln([
        _escape(d.employeeName),
        _escape(d.employeeEmail ?? ''),
        _escape(d.companyName),
        _escape(d.groupName ?? ''),
        _escape(r.leaveType.displayLabel),
        AppDateUtils.formatDate(r.dateStart),
        AppDateUtils.formatDate(r.dateEnd),
        '${r.totalLeave}',
        r.status,
        _escape(r.employeeComment),
      ].join(','));
    }
    return buffer.toString();
  }

  static String _escape(String value) {
    if (value.contains(',') || value.contains('"') || value.contains('\n')) {
      return '"${value.replaceAll('"', '""')}"';
    }
    return value;
  }
}
