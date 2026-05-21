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
    final canView = role == AppConstants.roleAdmin ||
        role == AppConstants.roleManager;

    if (!canView) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final focused = ref.watch(teamCalendarMonthProvider);
    final leavesAsync = ref.watch(teamCalendarLeavesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Team leave calendar')),
      body: leavesAsync.when(
        data: (leaves) {
          final events = _eventsByDay(leaves);
          final dayEvents = events[_dayKey(_selectedDay)] ?? [];

          return Column(
            children: [
              TableCalendar<LeaveRequestDetail>(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2035, 12, 31),
                focusedDay: focused,
                calendarFormat: CalendarFormat.month,
                selectedDayPredicate: (d) => isSameDay(d, _selectedDay),
                eventLoader: (d) => events[_dayKey(d)] ?? [],
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
                calendarStyle: const CalendarStyle(
                  markersMaxCount: 3,
                  markerDecoration: BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text(
                      AppDateUtils.formatDate(_selectedDay),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (dayEvents.isEmpty)
                      const Text('No leave on this day.')
                    else
                      ...dayEvents.map((d) => _DayEventTile(detail: d)),
                  ],
                ),
              ),
            ],
          );
        },
        loading: () => const AppLoadingIndicator(message: 'Loading calendar…'),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Map<String, List<LeaveRequestDetail>> _eventsByDay(
    List<LeaveRequestDetail> leaves,
  ) {
    final map = <String, List<LeaveRequestDetail>>{};
    for (final d in leaves) {
      var cursor = DateTime(
        d.request.dateStart.year,
        d.request.dateStart.month,
        d.request.dateStart.day,
      );
      final end = DateTime(
        d.request.dateEnd.year,
        d.request.dateEnd.month,
        d.request.dateEnd.day,
      );
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
}

class _DayEventTile extends StatelessWidget {
  const _DayEventTile({required this.detail});

  final LeaveRequestDetail detail;

  @override
  Widget build(BuildContext context) {
    final r = detail.request;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(detail.employeeName),
        subtitle: Text(
          '${r.leaveType.displayLabel} · ${r.status}\n'
          '${detail.companyName}',
        ),
        isThreeLine: true,
      ),
    );
  }
}
