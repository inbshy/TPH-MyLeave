import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/team_calendar_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class TeamCalendarPage extends ConsumerStatefulWidget {
  const TeamCalendarPage({super.key});

  @override
  ConsumerState<TeamCalendarPage> createState() => _TeamCalendarPageState();
}

class _TeamCalendarPageState extends ConsumerState<TeamCalendarPage> {
  DateTime _selectedDay = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    final canView = role == AppConstants.roleAdmin || role == AppConstants.roleManager;

    if (!canView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final focused = ref.watch(teamCalendarMonthProvider);
    final leavesAsync = ref.watch(teamCalendarLeavesProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Team Leave Calendar'),
        elevation: 0,
      ),
      body: leavesAsync.when(
        data: (leaves) {
          final events = _eventsByDay(leaves);
          final dayEvents = events[_dayKey(_selectedDay)] ?? [];

          return Column(
            children: [
              // ==================== COMPACT CALENDAR ====================
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Card(
                  elevation: 0,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: TableCalendar<LeaveRequestDetail>(
                      firstDay: DateTime.utc(2020, 1, 1),
                      lastDay: DateTime.utc(2035, 12, 31),
                      focusedDay: focused,
                      calendarFormat: CalendarFormat.month,
                      selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                      eventLoader: (d) => events[_dayKey(d)] ?? [],
                      rowHeight: 42, // ← Moved here (correct location)
                      onDaySelected: (selected, focus) {
                        setState(() => _selectedDay = selected);
                        ref.read(teamCalendarMonthProvider.notifier).state =
                            DateTime(focus.year, focus.month);
                      },
                      onPageChanged: (focus) {
                        ref.read(teamCalendarMonthProvider.notifier).state =
                            DateTime(focus.year, focus.month);
                        ref.invalidate(teamCalendarLeavesProvider);
                      },
                      headerStyle: const HeaderStyle(
                        formatButtonVisible: false,
                        titleCentered: true,
                        titleTextStyle: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      calendarStyle: CalendarStyle(
                        selectedDecoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        todayDecoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          shape: BoxShape.circle,
                        ),
                        markerDecoration: BoxDecoration(
                          color: colorScheme.primary,
                          shape: BoxShape.circle,
                        ),
                        markersMaxCount: 3,
                        markerSize: 6,
                      ),
                      daysOfWeekStyle: const DaysOfWeekStyle(
                        weekdayStyle: TextStyle(fontSize: 12),
                        weekendStyle: TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ),

              // Selected Day Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
                child: Row(
                  children: [
                    Text(
                      AppDateUtils.formatDate(_selectedDay),
                      style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const Spacer(),
                    if (dayEvents.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: colorScheme.primaryContainer,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${dayEvents.length} on leave',
                          style: theme.textTheme.labelMedium?.copyWith(
                            color: colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
              ),

              const Divider(height: 1),

              // Employee List
              Expanded(
                child: dayEvents.isEmpty
                    ? _buildEmptyState(context)
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                        itemCount: dayEvents.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final d = dayEvents[index];
                          final r = d.request;

                          return Card(
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                              leading: CircleAvatar(
                                backgroundColor: colorScheme.primaryContainer,
                                child: Text(
                                  d.employeeName.isNotEmpty ? d.employeeName[0].toUpperCase() : '?',
                                  style: TextStyle(
                                    color: colorScheme.onPrimaryContainer,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              title: Text(
                                d.employeeName,
                                style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              subtitle: Padding(
                                padding: const EdgeInsets.only(top: 4),
                                child: Text(
                                  '${r.leaveType.displayLabel} · ${r.totalLeave} day(s) · ${d.companyName}',
                                ),
                              ),
                              trailing: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(r.status).withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  r.status,
                                  style: TextStyle(
                                    color: _getStatusColor(r.status),
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(message: 'Loading team calendar...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Error: $e'),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
        return Colors.green;
      case 'pending':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Map<String, List<LeaveRequestDetail>> _eventsByDay(List<LeaveRequestDetail> leaves) {
    final map = <String, List<LeaveRequestDetail>>{};
    for (final d in leaves) {
      var cursor = DateTime(d.request.dateStart.year, d.request.dateStart.month, d.request.dateStart.day);
      final end = DateTime(d.request.dateEnd.year, d.request.dateEnd.month, d.request.dateEnd.day);
      while (!cursor.isAfter(end)) {
        final key = _dayKey(cursor);
        map.putIfAbsent(key, () => []).add(d);
        cursor = cursor.add(const Duration(days: 1));
      }
    }
    return map;
  }

  String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available_outlined, size: 64, color: colorScheme.primary.withValues(alpha: 0.3)),
          const SizedBox(height: 16),
          Text('No one is on leave today', style: theme.textTheme.titleMedium),
        ],
      ),
    );
  }
}