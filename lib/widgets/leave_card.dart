import 'package:flutter/material.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';

class LeaveCard extends StatelessWidget {
  const LeaveCard({
    super.key,
    required this.request,
    this.onTap,
    this.margin = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
  });

  final LeaveRequest request;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry margin;

  Color _statusColor(BuildContext context) {
    final s = request.status.toLowerCase();
    if (s == 'approved') return Colors.green.shade700;
    if (s == 'rejected') return Colors.red.shade700;
    if (s == 'cancelled') return Colors.grey.shade600;
    return Theme.of(context).colorScheme.tertiary;
  }

  IconData _typeIcon() => switch (request.leaveType) {
        LeaveType.annual => Icons.beach_access_outlined,
        LeaveType.sick => Icons.medical_services_outlined,
        LeaveType.maternity => Icons.child_care_outlined,
        LeaveType.hospitalisation => Icons.local_hospital_outlined,
        LeaveType.paternity => Icons.family_restroom_outlined,
        LeaveType.compassionate => Icons.favorite_border_outlined,
        LeaveType.unpaid => Icons.money_off_outlined,
      };

  Color _typeColor(BuildContext context) => switch (request.leaveType) {
        LeaveType.annual => Colors.teal.shade700,
        LeaveType.sick => Colors.red.shade700,
        LeaveType.maternity => Colors.purple.shade700,
        LeaveType.hospitalisation => Colors.orange.shade800,
        LeaveType.paternity => Colors.blue.shade700,
        LeaveType.compassionate => Colors.brown.shade600,
        LeaveType.unpaid => Colors.grey.shade700,
      };

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: margin,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(
          backgroundColor: _typeColor(context).withValues(alpha: 0.15),
          foregroundColor: _typeColor(context),
          child: Icon(_typeIcon(), size: 20),
        ),
        title: Text(
          AppDateUtils.formatDateRange(request.dateStart, request.dateEnd),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              '${request.leaveType.displayLabel} · ${request.totalLeave} day(s)',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (request.approveBy.isNotEmpty)
              Text(
                'Approver: ${request.approveBy}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        trailing: Chip(
          label: Text(
            request.status,
            style: const TextStyle(fontSize: 12),
          ),
          backgroundColor: _statusColor(context).withValues(alpha: 0.15),
          side: BorderSide(color: _statusColor(context)),
        ),
      ),
    );
  }
}
