// lib/presentation/screens/calendar/shared_calendar_screen.dart
// COMPLETE FIXED VERSION - Shows both Personal and Shared events

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/calendar_event_model.dart';
import '../../providers/calendar_provider.dart';
import '../../providers/household_provider.dart';
import '../../providers/auth_provider.dart';
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
  void initState() {
    super.initState();
    _debugCheckFirestoreData();
  }

  Future<void> _debugCheckFirestoreData() async {
    print('\n═══════════════════════════════════════');
    print('🔍 DEBUG: Checking Firestore Data');
    print('═══════════════════════════════════════');
    
    try {
      final allEventsSnapshot = await FirebaseFirestore.instance
          .collection('calendar_events')
          .get();
      print('📊 Total events in Firestore: ${allEventsSnapshot.docs.length}');
      
      final sharedEventsSnapshot = await FirebaseFirestore.instance
          .collection('calendar_events')
          .where('isShared', isEqualTo: true)
          .get();
      print('📊 Total SHARED events: ${sharedEventsSnapshot.docs.length}');
      
      for (var doc in sharedEventsSnapshot.docs) {
        final data = doc.data();
        print('  📄 ${doc.id}:');
        print('     - title: ${data['title']}');
        print('     - householdId: ${data['householdId']}');
        print('     - isShared: ${data['isShared']}');
        print('     - startTime: ${data['startTime']}');
      }
      
      final household = await ref.read(currentHouseholdProvider.future);
      print('🏠 Current household ID: ${household?.id}');
      print('🏠 Household name: ${household?.name}');
      
      if (household != null) {
        final householdEventsSnapshot = await FirebaseFirestore.instance
            .collection('calendar_events')
            .where('householdId', isEqualTo: household.id)
            .where('isShared', isEqualTo: true)
            .get();
        print('📊 Shared events for THIS household: ${householdEventsSnapshot.docs.length}');
      }
      
      print('\n📱 CHECKING PERSONAL EVENTS:');
      final currentUserId = ref.read(currentUserIdProvider);
      print('👤 Current user ID: $currentUserId');

      final personalEventsSnapshot = await FirebaseFirestore.instance
          .collection('calendar_events')
          .where('isShared', isEqualTo: false)
          .get();

      print('📊 Total PERSONAL events (any user): ${personalEventsSnapshot.docs.length}');

      for (var doc in personalEventsSnapshot.docs) {
        final data = doc.data();
        final timestamp = data['startTime'] as Timestamp;
        final startTime = timestamp.toDate();
        print('  📄 ${doc.id}:');
        print('     - title: ${data['title']}');
        print('     - userId: ${data['userId']}');
        print('     - isShared: ${data['isShared']}');
        print('     - startTime: $startTime');
        print('     - Matches current user? ${data['userId'] == currentUserId}');
      }

      if (currentUserId != null) {
        final myPersonalEventsSnapshot = await FirebaseFirestore.instance
            .collection('calendar_events')
            .where('userId', isEqualTo: currentUserId)
            .where('isShared', isEqualTo: false)
            .get();

        print('📊 Personal events for THIS user: ${myPersonalEventsSnapshot.docs.length}');
      }
      
      print('═══════════════════════════════════════\n');
    } catch (e) {
      print('❌ Debug error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    // Watch BOTH providers
    final sharedEvents = ref.watch(sharedCalendarEventsProvider);
    final personalEvents = ref.watch(personalCalendarEventsProvider);
    final household = ref.watch(currentHouseholdProvider);

    // Combine the events
    final combinedEvents = <CalendarEventModel>[
      ...(sharedEvents.value ?? []),
      ...(personalEvents.value ?? []),
    ];
    combinedEvents.sort((a, b) => a.startTime.compareTo(b.startTime));

    print('\n🔄 Calendar Screen build()');
    print('   Shared: ${sharedEvents.value?.length ?? 0} events');
    print('   Personal: ${personalEvents.value?.length ?? 0} events');
    print('   Combined: ${combinedEvents.length} events');

    // Determine loading state
    final isLoading = sharedEvents.isLoading || personalEvents.isLoading;
    final hasError = sharedEvents.hasError || personalEvents.hasError;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Calendar'),
        actions: [
          IconButton(
            icon: const Icon(Icons.bug_report),
            onPressed: _debugCheckFirestoreData,
            tooltip: 'Debug Info',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              print('🔄 Manual refresh triggered');
              ref.invalidate(sharedCalendarEventsProvider);
              ref.invalidate(personalCalendarEventsProvider);
            },
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          household.when(
            data: (h) => Container(
              color: Colors.blue[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  const Icon(Icons.info, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Household: ${h?.name ?? "None"} (${h?.id ?? "No ID"})',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ],
              ),
            ),
            loading: () => const SizedBox(),
            error: (_, __) => const SizedBox(),
          ),

          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                children: [
                  LoadingWidget(),
                  SizedBox(height: 8),
                  Text('Loading events...'),
                ],
              ),
            )
          else if (hasError)
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const Icon(Icons.error, color: Colors.red, size: 48),
                  const SizedBox(height: 8),
                  const Text('Error loading events'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () {
                      ref.invalidate(sharedCalendarEventsProvider);
                      ref.invalidate(personalCalendarEventsProvider);
                    },
                    child: const Text('Retry'),
                  ),
                ],
              ),
            )
          else ...[
            Container(
              color: combinedEvents.isEmpty ? Colors.orange[100] : Colors.green[100],
              padding: const EdgeInsets.all(8),
              child: Row(
                children: [
                  Icon(
                    combinedEvents.isEmpty ? Icons.warning : Icons.check_circle,
                    size: 16,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${combinedEvents.length} events (${sharedEvents.value?.length ?? 0} shared + ${personalEvents.value?.length ?? 0} personal)',
                    style: const TextStyle(fontSize: 12),
                  ),
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
                print('📅 Day selected: $selectedDay');
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
                print('📅 Page changed: $focusedDay');
              },
              eventLoader: (day) {
                final dayEvents = combinedEvents
                    .where((event) => isSameDay(event.startTime, day))
                    .toList();
                if (dayEvents.isNotEmpty) {
                  print('📌 Events for $day: ${dayEvents.length}');
                }
                return dayEvents;
              },
            ),
          ],

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

    print('📋 Building events list: ${selectedDayEvents.length} events');

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
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: _debugCheckFirestoreData,
              icon: const Icon(Icons.bug_report),
              label: const Text('Debug Check'),
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
                Text(
                  'ID: ${event.id.substring(0, 8)}... | ${event.isShared ? "Shared" : "Personal"}',
                  style: const TextStyle(fontSize: 10, color: Colors.grey),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (event.isShared)
                  const Icon(
                    Icons.people,
                    size: 16,
                    color: Colors.green,
                  ),
                if (!event.isShared)
                  const Icon(
                    Icons.person,
                    size: 16,
                    color: Colors.blue,
                  ),
                if (event.googleEventId != null)
                  const Padding(
                    padding: EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.sync,
                      size: 16,
                      color: Colors.blue,
                    ),
                  ),
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