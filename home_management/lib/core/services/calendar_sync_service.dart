// lib/core/services/calendar_sync_service.dart
// UPDATED VERSION WITH BI-DIRECTIONAL SYNC

import 'package:flutter/foundation.dart';
import 'package:googleapis/calendar/v3.dart' as google_calendar;
import '../../data/datasources/google_calendar_datasource.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/models/calendar_event_model.dart';

class CalendarSyncService {
  final GoogleCalendarDataSource _googleCalendarDataSource;
  final CalendarRepository _calendarRepository;

  CalendarSyncService(
    this._googleCalendarDataSource,
    this._calendarRepository,
  );

  // ============ NEW: Create shared event in BOTH places ============
  /// Create event in both the shared Google Calendar AND Firestore
  Future<void> createSharedEventInBoth({
    required CalendarEventModel event,
    required String sharedGoogleCalendarId,
  }) async {
    try {
      // First, create in Google Calendar
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
        sharedGoogleCalendarId,
        googleEvent,
      );

      // Then create in Firestore with the Google event ID
      final eventWithGoogleId = event.copyWith(
        googleEventId: createdEvent?.id,
        isShared: true,
      );
      
      await _calendarRepository.createEvent(eventWithGoogleId);
      
      debugPrint('Created shared event in both Google Calendar and Firestore: ${event.title}');
    } catch (e) {
      debugPrint('Error creating shared event in both calendars: $e');
      rethrow;
    }
  }

  // ============ NEW: Update shared event in BOTH places ============
  /// Update event in both the shared Google Calendar AND Firestore
  Future<void> updateSharedEventInBoth({
    required String eventId,
    required String sharedGoogleCalendarId,
    required String googleEventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // Update in Firestore first
      await _calendarRepository.updateEvent(eventId, updates);

      // Then update in Google Calendar if relevant fields changed
      if (updates.containsKey('title') ||
          updates.containsKey('startTime') ||
          updates.containsKey('endTime') ||
          updates.containsKey('description')) {
        
        final googleEvent = google_calendar.Event(
          summary: updates['title'],
          description: updates['description'],
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
          sharedGoogleCalendarId,
          googleEventId,
          googleEvent,
        );
        
        debugPrint('Updated shared event in both calendars');
      }
    } catch (e) {
      debugPrint('Error updating shared event in both calendars: $e');
      rethrow;
    }
  }

  // ============ NEW: Delete shared event from BOTH places ============
  /// Delete event from both the shared Google Calendar AND Firestore
  Future<void> deleteSharedEventFromBoth({
    required String eventId,
    required String sharedGoogleCalendarId,
    String? googleEventId,
  }) async {
    try {
      // Delete from Firestore
      await _calendarRepository.deleteEvent(eventId);

      // Delete from Google Calendar if it exists there
      if (googleEventId != null) {
        await _googleCalendarDataSource.deleteEvent(
          sharedGoogleCalendarId,
          googleEventId,
        );
        debugPrint('Deleted shared event from both calendars');
      }
    } catch (e) {
      debugPrint('Error deleting shared event from both calendars: $e');
      rethrow;
    }
  }

  // ============ EXISTING: Sync Google Calendar (personal) ============
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

  // ============ UPDATED: Sync shared Google Calendar (BOTH DIRECTIONS) ============
  /// Sync shared Google Calendar with bi-directional support
  /// - Pulls events FROM Google TO app
  /// - Pushes NEW events FROM app TO Google (if they don't have googleEventId)
  Future<void> syncSharedGoogleCalendar(
    String householdId,
    String sharedGoogleCalendarId,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 90));

      // STEP 1: Pull events FROM Google Calendar TO app
      final googleEvents = await _googleCalendarDataSource.fetchEvents(
        sharedGoogleCalendarId,
        start,
        end,
      );

      debugPrint('Found ${googleEvents.length} events in shared Google Calendar');

      // Get existing events from Firestore
      final existingEvents = await _calendarRepository
          .getEventsInRange(householdId, start, end)
          .first;

      // Process Google Calendar events
      for (final event in googleEvents) {
        if (event.start?.dateTime == null || event.end?.dateTime == null) {
          continue;
        }

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
            userId: '',
            householdId: householdId,
            isShared: true,
            googleEventId: event.id,
            type: EventType.event,
          );

          await _calendarRepository.createEvent(calendarEvent);
          debugPrint('Created synced event: ${event.summary}');
        }
      }

      // STEP 2: Push NEW shared events FROM app TO Google Calendar
      // Find events that are shared but don't have a googleEventId yet
      final sharedEventsWithoutGoogleId = existingEvents.where(
        (e) => e.isShared && e.googleEventId == null,
      ).toList();

      for (final event in sharedEventsWithoutGoogleId) {
        try {
          debugPrint('Pushing local event to Google Calendar: ${event.title}');
          
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
            sharedGoogleCalendarId,
            googleEvent,
          );

          // Update Firestore event with Google event ID
          if (createdEvent != null && createdEvent.id != null) {
            await _calendarRepository.updateEvent(
              event.id,
              {'googleEventId': createdEvent.id},
            );
            debugPrint('Successfully pushed event to Google: ${event.title}');
          }
        } catch (e) {
          debugPrint('Error pushing event ${event.title} to Google: $e');
          // Continue with other events even if one fails
        }
      }

      // STEP 3: Clean up deleted events
      final googleEventIds = googleEvents
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();

      for (final existingEvent in existingEvents) {
        if (existingEvent.googleEventId != null &&
            existingEvent.isShared &&
            !googleEventIds.contains(existingEvent.googleEventId)) {
          await _calendarRepository.deleteEvent(existingEvent.id);
          debugPrint('Deleted event no longer in Google Calendar: ${existingEvent.title}');
        }
      }

      debugPrint('Bi-directional shared calendar sync completed');
    } catch (e) {
      debugPrint('Error syncing shared Google Calendar: $e');
      rethrow;
    }
  }

  // ============ EXISTING: Create personal event in both places ============
  Future<void> createEventInBoth({
    required CalendarEventModel event,
    required String googleCalendarId,
  }) async {
    try {
      final eventId = await _calendarRepository.createEvent(event);

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

  // ============ EXISTING: Update personal event in both places ============
  Future<void> updateEventInBoth({
    required String eventId,
    required String googleCalendarId,
    required String googleEventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      await _calendarRepository.updateEvent(eventId, updates);

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

  // ============ EXISTING: Delete personal event from both places ============
  Future<void> deleteEventFromBoth({
    required String eventId,
    required String googleCalendarId,
    String? googleEventId,
  }) async {
    try {
      await _calendarRepository.deleteEvent(eventId);

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
}