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

  /// Create event (optionally sync to Google Calendar)
  Future<void> createEvent(
    CalendarEventModel event, {
    bool syncToGoogle = false,
  }) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);

      if (syncToGoogle) {
        final user = ref.read(currentUserProvider).value;
        final googleCalendarId = user?.googleCalendarId;

        if (googleCalendarId != null) {
          await syncService.createEventInBoth(
            event: event,
            googleCalendarId: googleCalendarId,
          );
          return;
        }
      }

      // If not syncing to Google or no calendar ID, just create in Firestore
      await repository.createEvent(event);
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  /// Update event (optionally sync to Google Calendar)
  Future<void> updateEvent(
    String eventId,
    Map<String, dynamic> updates, {
    bool syncToGoogle = false,
  }) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);

      if (syncToGoogle) {
        final user = ref.read(currentUserProvider).value;
        final googleCalendarId = user?.googleCalendarId;

        // Get the event to find its Google event ID
        final events = await repository
            .getEventsInRange(
              user!.householdId!,
              DateTime.now().subtract(const Duration(days: 365)),
              DateTime.now().add(const Duration(days: 365)),
            )
            .first;

        final event = events.firstWhere((e) => e.id == eventId);

        if (googleCalendarId != null && event.googleEventId != null) {
          await syncService.updateEventInBoth(
            eventId: eventId,
            googleCalendarId: googleCalendarId,
            googleEventId: event.googleEventId!,
            updates: updates,
          );
          return;
        }
      }

      await repository.updateEvent(eventId, updates);
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete event (optionally sync to Google Calendar)
  Future<void> deleteEvent(
    String eventId, {
    bool syncToGoogle = false,
  }) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);

      if (syncToGoogle) {
        final user = ref.read(currentUserProvider).value;
        final googleCalendarId = user?.googleCalendarId;

        // Get the event to find its Google event ID
        final events = await repository
            .getEventsInRange(
              user!.householdId!,
              DateTime.now().subtract(const Duration(days: 365)),
              DateTime.now().add(const Duration(days: 365)),
            )
            .first;

        final event = events.firstWhere((e) => e.id == eventId);

        if (googleCalendarId != null) {
          await syncService.deleteEventFromBoth(
            eventId: eventId,
            googleCalendarId: googleCalendarId,
            googleEventId: event.googleEventId,
          );
          return;
        }
      }

      await repository.deleteEvent(eventId);
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  /// Sync all Google Calendar events to Firestore
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

      print('Google Calendar synced successfully');
    } catch (e) {
      print('Error syncing Google Calendar: $e');
      rethrow;
    }
  }

  /// Check availability across both Firestore and Google Calendar
  Future<bool> checkAvailability({
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final syncService = ref.read(calendarSyncServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      final user = ref.read(currentUserProvider).value;

      if (userId == null) {
        throw Exception('No user logged in');
      }

      final googleCalendarId = user?.googleCalendarId;

      if (googleCalendarId != null) {
        return await syncService.checkAvailability(
          userId: userId,
          googleCalendarId: googleCalendarId,
          start: start,
          end: end,
        );
      } else {
        // Just check Firestore if no Google Calendar
        final repository = ref.read(calendarRepositoryProvider);
        return await repository.checkAvailability(userId, start, end);
      }
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }

  /// Force refresh Google Calendar access token
  Future<void> refreshGoogleCalendarToken() async {
    try {
      final authActions = ref.read(authActionsProvider);
      final accessToken = await authActions.refreshGoogleAccessToken();

      if (accessToken != null) {
        print('Google Calendar token refreshed');
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      print('Error refreshing token: $e');
      rethrow;
    }
  }
}
