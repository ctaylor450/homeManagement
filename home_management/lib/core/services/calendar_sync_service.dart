import 'package:flutter/foundation.dart';
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

  // Sync Google Calendar events to Firestore (existing method)
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
      debugPrint('Error syncing Google Calendar: $e');
    }
  }

  // ============ NEW METHOD: Sync shared Google Calendar events ============
  /// Sync shared Google Calendar events to household calendar
  /// This makes all events from the family calendar visible to everyone
  Future<void> syncSharedGoogleCalendar(
    String householdId,
    String sharedGoogleCalendarId,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 90));

      // Fetch events from the shared Google Calendar
      final googleEvents = await _googleCalendarDataSource.fetchEvents(
        sharedGoogleCalendarId,
        start,
        end,
      );

      debugPrint('Found ${googleEvents.length} events in shared calendar');

      for (final event in googleEvents) {
        if (event.start?.dateTime == null || event.end?.dateTime == null) {
          continue;
        }

        // Check if this event already exists in Firestore
        final existingEvents = await _calendarRepository
            .getEventsInRange(householdId, start, end)
            .first;
        
        final existingEvent = existingEvents.where(
          (e) => e.googleEventId == event.id,
        ).firstOrNull;

        if (existingEvent != null) {
          // Update existing event if it changed
          final updates = <String, dynamic>{};
          
          if (existingEvent.title != (event.summary ?? 'Untitled Event')) {
            updates['title'] = event.summary ?? 'Untitled Event';
          }
          
          if (existingEvent.description != event.description) {
            updates['description'] = event.description;
          }
          
          if (existingEvent.startTime != event.start!.dateTime) {
            updates['startTime'] = event.start!.dateTime;
          }
          
          if (existingEvent.endTime != event.end!.dateTime) {
            updates['endTime'] = event.end!.dateTime;
          }

          if (updates.isNotEmpty) {
            await _calendarRepository.updateEvent(existingEvent.id, updates);
            debugPrint('Updated synced event: ${event.summary}');
          }
        } else {
          // Create new event in Firestore
          final calendarEvent = CalendarEventModel(
            id: '',
            title: event.summary ?? 'Untitled Event',
            description: event.description,
            startTime: event.start!.dateTime!,
            endTime: event.end!.dateTime!,
            userId: '', // No specific user - it's a household event
            householdId: householdId,
            isShared: true, // Mark as shared so everyone can see it
            googleEventId: event.id,
            type: EventType.event,
            //location: event.location,
          );

          await _calendarRepository.createEvent(calendarEvent);
          debugPrint('Created synced event: ${event.summary}');
        }
      }

      // Optional: Delete events that no longer exist in Google Calendar
      final existingEvents = await _calendarRepository
          .getEventsInRange(householdId, start, end)
          .first;
      
      final googleEventIds = googleEvents
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();

      for (final existingEvent in existingEvents) {
        // Only delete events that came from this shared calendar
        if (existingEvent.googleEventId != null &&
            existingEvent.isShared &&
            !googleEventIds.contains(existingEvent.googleEventId)) {
          await _calendarRepository.deleteEvent(existingEvent.id);
          debugPrint('Deleted event no longer in Google Calendar: ${existingEvent.title}');
        }
      }

      debugPrint('Shared calendar sync completed');
    } catch (e) {
      debugPrint('Error syncing shared Google Calendar: $e');
      rethrow;
    }
  }

  // ============ NEW METHOD: Sync all calendars ============
  /// Sync all calendars (personal + shared household calendar)
  Future<void> syncAllCalendars({
    required String userId,
    required String householdId,
    String? personalCalendarId,
    String? sharedCalendarId,
  }) async {
    try {
      // Sync personal calendar if available
      if (personalCalendarId != null) {
        await syncGoogleCalendar(userId, householdId, personalCalendarId);
      }

      // Sync shared household calendar if available
      if (sharedCalendarId != null) {
        await syncSharedGoogleCalendar(householdId, sharedCalendarId);
      }
    } catch (e) {
      debugPrint('Error syncing all calendars: $e');
      rethrow;
    }
  }

  // Create event in both Google Calendar and Firestore (existing method)
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
      debugPrint('Error creating event in both calendars: $e');
      rethrow;
    }
  }

  // Update event in both calendars (existing method)
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
      debugPrint('Error updating event in both calendars: $e');
      rethrow;
    }
  }

  // Delete event from both calendars (existing method)
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
      debugPrint('Error deleting event from both calendars: $e');
      rethrow;
    }
  }

  // Check if user is available at a specific time (existing method)
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
      debugPrint('Error checking availability: $e');
      return false;
    }
  }
}