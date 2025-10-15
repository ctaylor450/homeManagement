// lib/presentation/screens/calendar/shared_calendar_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/calendar_event_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/auto_sync_provider.dart';
import '../../widgets/create_event_dialog.dart';
import '../../widgets/edit_event_dialog.dart';

class SharedCalendarScreen extends ConsumerStatefulWidget {
  const SharedCalendarScreen({super.key});

  @override
  ConsumerState<SharedCalendarScreen> createState() =>
      _SharedCalendarScreenState();
}

class _SharedCalendarScreenState extends ConsumerState<SharedCalendarScreen> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  bool _isSyncing = false;

  Future<void> _handleResync() async {
    setState(() => _isSyncing = true);

    try {
      // Sync personal calendar
      await ref.read(calendarActionsProvider).syncGoogleCalendar();
      
      // Sync shared calendar
      final sharedSync = ref.read(sharedCalendarAutoSyncProvider);
      await sharedSync.manualSync();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Calendars synced successfully!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sync failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _openEdit(CalendarEventModel event) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => EditEventDialog(event: event),
    );

    if (updated == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Event updated')),
      );
    }
  }

  Future<void> _confirmDelete(CalendarEventModel event) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete event?'),
        content: Text('"${event.title}" will be removed. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton.tonal(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await ref.read(calendarActionsProvider).deleteEvent(event.id);

        if (mounted) {
          ref.invalidate(sharedCalendarEventsProvider);
          ref.invalidate(personalCalendarEventsProvider);

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Event deleted')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final sharedEvents = ref.watch(sharedCalendarEventsProvider);
    final personalEvents = ref.watch(personalCalendarEventsProvider);

    final combinedEvents = <CalendarEventModel>[
      ...(sharedEvents.value ?? []),
      ...(personalEvents.value ?? []),
    ];
    combinedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    final isLoading = sharedEvents.isLoading || personalEvents.isLoading;
    final hasError = sharedEvents.hasError || personalEvents.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                    ),
                  )
                : const Icon(Icons.refresh),
            onPressed: _isSyncing ? null : _handleResync,
            tooltip: 'Re-sync calendars',
          ),
        ],
      ),
      body: Column(
        children: [
          if (isLoading)
            const LinearProgressIndicator()
          else if (hasError)
            Container(
              color: Colors.red[100],
              padding: const EdgeInsets.all(8),
              child: const Row(
                children: [
                  Icon(Icons.error, size: 16, color: Colors.red),
                  SizedBox(width: 8),
                  Text('Error loading events'),
                ],
              ),
            ),
          TableCalendar(
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
              return combinedEvents
                  .where((event) => isSameDay(event.startTime, day))
                  .toList();
            },
            calendarBuilders: CalendarBuilders(
              markerBuilder: (context, day, events) {
                if (events.isEmpty) return const SizedBox();

                final dayEvents = events.cast<CalendarEventModel>();
                final hasShared = dayEvents.any((e) => e.isShared);
                final hasPersonal = dayEvents.any((e) => !e.isShared);

                return Positioned(
                  bottom: 1,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      if (hasShared)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: Colors.blue,
                            shape: BoxShape.circle,
                          ),
                        ),
                      if (hasPersonal)
                        Container(
                          width: 6,
                          height: 6,
                          margin: const EdgeInsets.symmetric(horizontal: 1),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          const Divider(),
          Expanded(
            child: _buildEventsList(combinedEvents),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          showDialog(
            context: context,
            builder: (context) => CreateEventDialog(
              selectedDate: _selectedDay ?? _focusedDay,
              isSharedCalendar: true,
            ),
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildEventsList(List<CalendarEventModel> allEvents) {
    final selectedDayEvents = _selectedDay != null
        ? allEvents
            .where((event) => isSameDay(event.startTime, _selectedDay))
            .toList()
        : allEvents;

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
                  : 'No events found',
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
              event.type.name == 'task' ? Icons.task_alt : Icons.event,
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
            onTap: () => _openEdit(event),
            trailing: PopupMenuButton<String>(
              onSelected: (value) {
                if (value == 'edit') {
                  _openEdit(event);
                } else if (value == 'delete') {
                  _confirmDelete(event);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ),
        );
      },
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }
}