import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/loading_widget.dart';

class SharedCalendarScreen extends ConsumerStatefulWidget {
  const SharedCalendarScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SharedCalendarScreen> createState() =>
      _SharedCalendarScreenState();
}

class _SharedCalendarScreenState extends ConsumerState<SharedCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    final calendarEvents = ref.watch(calendarEventsProvider);

    return Scaffold(
      body: Column(
        children: [
          calendarEvents.when(
            data: (events) {
              return TableCalendar(
                firstDay: DateTime.utc(2020, 1, 1),
                lastDay: DateTime.utc(2030, 12, 31),
                focusedDay: _focusedDay,
                selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                calendarFormat: CalendarFormat.month,
                startingDayOfWeek: StartingDayOfWeek.monday,
                calendarStyle: CalendarStyle(
                  selectedDecoration: const BoxDecoration(
                    color: AppTheme.primaryColor,
                    shape: BoxShape.circle,
                  ),
                  todayDecoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                  markerDecoration: const BoxDecoration(
                    color: AppTheme.accentColor,
                    shape: BoxShape.circle,
                  ),
                ),
                onDaySelected: (selectedDay, focusedDay) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                },
                onPageChanged: (focusedDay) {
                  _focusedDay = focusedDay;
                },
                eventLoader: (day) {
                  return events
                      .where((event) => isSameDay(event.startTime, day))
                      .toList();
                },
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LoadingWidget(),
            ),
            error: (error, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Error: $error'),
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildEventsList(),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // TODO: Implement create event
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Create event coming soon!')),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsList() {
    final calendarEvents = ref.watch(calendarEventsProvider);

    return calendarEvents.when(
      data: (events) {
        final selectedDayEvents = _selectedDay != null
            ? events
                .where((event) => isSameDay(event.startTime, _selectedDay))
                .toList()
            : events;

        if (selectedDayEvents.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.event_busy,
                  size: 64,
                  color: Colors.grey[400],
                ),
                const SizedBox(height: 16),
                Text(
                  _selectedDay != null
                      ? 'No events for this day'
                      : 'No events this month',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: selectedDayEvents.length,
          itemBuilder: (context, index) {
            final event = selectedDayEvents[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: Icon(
                  event.type.name == 'task'
                      ? Icons.task_alt
                      : Icons.event,
                  color: AppTheme.primaryColor,
                ),
                title: Text(event.title),
                subtitle: Text(
                  '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                ),
                trailing: event.isShared
                    ? const Icon(Icons.group, size: 20)
                    : null,
              ),
            );
          },
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}