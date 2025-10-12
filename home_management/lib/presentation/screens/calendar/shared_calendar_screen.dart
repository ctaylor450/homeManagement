import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../providers/calendar_provider.dart';
import '../../widgets/loading_widget.dart';
import '../../widgets/create_event_dialog.dart';

class SharedCalendarScreen extends ConsumerStatefulWidget {
  const SharedCalendarScreen({super.key});

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
          // Show create event dialog
          showDialog(
            context: context,
            builder: (context) => CreateEventDialog(
              selectedDate: _selectedDay ?? _focusedDay,
              isSharedCalendar: true, // Default to shared for shared calendar screen
            ),
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
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                    ),
                    if (event.description != null && event.description!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          event.description!,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
                trailing: event.isShared
                    ? const Tooltip(
                        message: 'Shared with household',
                        child: Icon(Icons.group, size: 20),
                      )
                    : null,
                onTap: () {
                  // TODO: Show event details dialog
                  _showEventDetails(event);
                },
              ),
            );
          },
        );
      },
      loading: () => const LoadingWidget(),
      error: (error, _) => Center(child: Text('Error: $error')),
    );
  }

  void _showEventDetails(event) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(event.title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (event.description != null && event.description!.isNotEmpty) ...[
              Text(event.description!),
              const SizedBox(height: 16),
            ],
            Row(
              children: [
                const Icon(Icons.access_time, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${_formatTime(event.startTime)} - ${_formatTime(event.endTime)}',
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(Icons.calendar_today, size: 16),
                const SizedBox(width: 8),
                Text(
                  '${event.startTime.day}/${event.startTime.month}/${event.startTime.year}',
                ),
              ],
            ),
            if (event.isShared) ...[
              const SizedBox(height: 8),
              const Row(
                children: [
                  Icon(Icons.group, size: 16),
                  SizedBox(width: 8),
                  Text('Shared with household'),
                ],
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime dateTime) {
    return '${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}