import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../data/datasources/google_calendar_datasource.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/repositories/calendar_repository.dart';

class CalendarSyncService {
  final GoogleCalendarDataSource _googleCalendarDataSource;
  final CalendarRepository _calendarRepository;

  CalendarSyncService(
    this._googleCalendarDataSource,
    this._calendarRepository,
  );

  // Sync Google Calendar events to Firestore
  Future<void> syncGoogleCalendar(
    String userId,
    String householdId,
    String googleCalendarId,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 90));

      final googleEvents = await _googleCalendarDataSource.fetchEvents(
        googleCalendarId,
        start,
        end,
      );

      for (final event in googleEvents) {
        if (event.start?.dateTime == null || event.end?.dateTime == null) {
          continue;
        }

        final calendarEvent = CalendarEventModel(
          id: '',
          title: event.summary ?? 'Untitled Event',
          description: event.description,
          startTime: event.start!.dateTime!,
          endTime: event.end!.dateTime!,
          userId: userId,
          householdId: householdId,
          isShared: false,
          googleEventId: event.id,
          type: EventType.event,
        );

        await _calendarRepository.createEvent(calendarEvent);
      }
    } catch (e) {
      print('Error syncing Google Calendar: $e');
    }
  }

  // Create event in both Google Calendar and Firestore
  Future<void> createEventInBoth({
    required CalendarEventModel event,
    required String googleCalendarId,
  }) async {
    try {
      // Create in Firestore first
      final eventId = await _calendarRepository.createEvent(event);

      // Create in Google Calendar
      final googleEvent = google_calendar.Event(
        summary: event.title,
        description: event.description,
        start: google_calendar.EventDateTime(
          dateTime: event.startTime,
          timeZone: 'UTC',
        ),
        end: google_calendar.EventDateTime(
          dateTime: event.endTime,
          timeZone: 'UTC',
        ),
      );

      final createdEvent = await _googleCalendarDataSource.createEvent(
        googleCalendarId,
        googleEvent,
      );

      // Update Firestore event with Google event ID
      if (createdEvent != null) {
        await _calendarRepository.updateEvent(
          eventId,
          {'googleEventId': createdEvent.id},
        );
      }
    } catch (e) {
      print('Error creating event in both calendars: $e');
      rethrow;
    }
  }

  // Update event in both calendars
  Future<void> updateEventInBoth({
    required String eventId,
    required String googleCalendarId,
    required String googleEventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // Update in Firestore
      await _calendarRepository.updateEvent(eventId, updates);

      // If there are changes that need to be synced to Google Calendar
      if (updates.containsKey('title') ||
          updates.containsKey('startTime') ||
          updates.containsKey('endTime')) {
        final googleEvent = google_calendar.Event(
          summary: updates['title'],
          start: updates['startTime'] != null
              ? google_calendar.EventDateTime(
                  dateTime: updates['startTime'],
                  timeZone: 'UTC',
                )
              : null,
          end: updates['endTime'] != null
              ? google_calendar.EventDateTime(
                  dateTime: updates['endTime'],
                  timeZone: 'UTC',
                )
              : null,
        );

        await _googleCalendarDataSource.updateEvent(
          googleCalendarId,
          googleEventId,
          googleEvent,
        );
      }
    } catch (e) {
      print('Error updating event in both calendars: $e');
      rethrow;
    }
  }

  // Delete event from both calendars
  Future<void> deleteEventFromBoth({
    required String eventId,
    required String googleCalendarId,
    required String? googleEventId,
  }) async {
    try {
      // Delete from Firestore
await _calendarRepository.deleteEvent(eventId);

      // Delete from Google Calendar if it exists there
      if (googleEventId != null) {
        await _googleCalendarDataSource.deleteEvent(
          googleCalendarId,
          googleEventId,
        );
      }
    } catch (e) {
      print('Error deleting event from both calendars: $e');
      rethrow;
    }
  }

  // Check if user is available at a specific time
  Future<bool> checkAvailability({
    required String userId,
    required String googleCalendarId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      // Check Firestore events
      final firestoreAvailable = await _calendarRepository.checkAvailability(
        userId,
        start,
        end,
      );

      if (!firestoreAvailable) {
        return false;
      }

      // Check Google Calendar events
      final googleAvailable = await _googleCalendarDataSource.isAvailable(
        googleCalendarId,
        start,
        end,
      );

      return googleAvailable;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }
}