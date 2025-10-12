import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/datasources/google_calendar_datasource.dart';
import '../../data/models/calendar_event_model.dart';
import '../../core/services/calendar_sync_service.dart';
import 'auth_provider.dart';

// Calendar repository provider
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

// Google Calendar datasource provider
final googleCalendarDataSourceProvider = Provider<GoogleCalendarDataSource>((ref) {
  return GoogleCalendarDataSource();
});

// Calendar sync service provider
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  final googleCalendarDataSource = ref.watch(googleCalendarDataSourceProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return CalendarSyncService(googleCalendarDataSource, calendarRepository);
});

// Selected date provider (for calendar navigation) - FIXED
final selectedDateProvider = Provider<DateTime>((ref) => DateTime.now());

// Calendar events for selected month
final calendarEventsProvider = StreamProvider.autoDispose<List<CalendarEventModel>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
  final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

  return repository.getEventsInRange(householdId, startOfMonth, endOfMonth);
});

// Personal calendar events
final personalCalendarEventsProvider = StreamProvider.autoDispose<List<CalendarEventModel>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
  final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

  return repository.getPersonalEvents(userId, startOfMonth, endOfMonth);
});

// Shared calendar events
final sharedCalendarEventsProvider = StreamProvider.autoDispose<List<CalendarEventModel>>((ref) {
  final repository = ref.watch(calendarRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);
  final selectedDate = ref.watch(selectedDateProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  final startOfMonth = DateTime(selectedDate.year, selectedDate.month, 1);
  final endOfMonth = DateTime(selectedDate.year, selectedDate.month + 1, 0, 23, 59, 59);

  return repository.getSharedEvents(householdId, startOfMonth, endOfMonth);
});

// Calendar actions provider
final calendarActionsProvider = Provider<CalendarActions>((ref) {
  return CalendarActions(ref);
});

class CalendarActions {
  final Ref ref;

  CalendarActions(this.ref);

  Future<void> createEvent(CalendarEventModel event) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      await repository.createEvent(event);
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  Future<void> updateEvent(String eventId, Map<String, dynamic> updates) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      await repository.updateEvent(eventId, updates);
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  Future<void> deleteEvent(String eventId) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      await repository.deleteEvent(eventId);
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  Future<void> syncGoogleCalendar() async {
    try {
      final syncService = ref.read(calendarSyncServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      final householdId = ref.read(currentHouseholdIdProvider);
      final user = ref.read(currentUserProvider).value;

      if (userId == null || householdId == null || user?.googleCalendarId == null) {
        throw Exception('Missing required data for sync');
      }

      await syncService.syncGoogleCalendar(
        userId,
        householdId,
        user!.googleCalendarId!,
      );
    } catch (e) {
      print('Error syncing Google Calendar: $e');
      rethrow;
    }
  }
}