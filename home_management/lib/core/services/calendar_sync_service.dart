// lib/core/services/calendar_sync_service.dart
// FIXED VERSION - Handles all-day events and uses correct queries to avoid index issues
// + Uses Google upsert helper to guarantee end time (avoids 400 "Missing end time")
// + Fixes nullable String (googleapis Event.id) non-promotion by assigning to a local non-null variable

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

  // Helper to normalize Google event start/end into DateTime (supports all-day)
  DateTime? _normalizeStart(google_calendar.Event e) {
    final dt = e.start?.dateTime;
    if (dt != null) return dt;
    final d = e.start?.date; // all-day (YYYY-MM-DD), end.date is exclusive
    if (d == null) return null;
    // Treat all-day start as local midnight of that date
    return d.toLocal();
  }

  DateTime? _normalizeEnd(google_calendar.Event e) {
    final dt = e.end?.dateTime;
    if (dt != null) return dt;
    final d = e.end?.date; // exclusive for all-day; local midnight of next day
    if (d == null) return null;
    return d.toLocal();
  }

  bool _isAllDayFromTimes(DateTime start, DateTime? end) {
    final e = end ?? start;
    return start.hour == 0 &&
        start.minute == 0 &&
        start.second == 0 &&
        e.hour == 0 &&
        e.minute == 0 &&
        e.second == 0;
  }

  // ============ PERSONAL CALENDAR SYNC (FIXED - No Index Issues) ============
  Future<void> syncGoogleCalendar(
    String userId,
    String householdId,
    String googleCalendarId,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 30));
      final end = now.add(const Duration(days: 365));

      debugPrint('📅 Syncing personal calendar...');
      debugPrint('   Date range: $start to $end');

      final googleEvents = await _googleCalendarDataSource.fetchEvents(
        googleCalendarId,
        start,
        end,
      );

      debugPrint('📥 Found ${googleEvents.length} events in Google Calendar');

      // ✅ FIXED: Use getPersonalEvents instead of getEventsInRange to avoid index issues
      final existingPersonalEvents = await _calendarRepository
          .getPersonalEvents(userId, start, end)
          .first;

      debugPrint('📱 Found ${existingPersonalEvents.length} personal events in Firestore');

      // Create lookup map
      final existingEventsByGoogleId = <String, CalendarEventModel>{};
      for (final event in existingPersonalEvents) {
        if (event.googleEventId != null) {
          existingEventsByGoogleId[event.googleEventId!] = event;
        }
      }

      int created = 0;
      int updated = 0;

      for (final googleEvent in googleEvents) {
        final startDT = _normalizeStart(googleEvent);
        final endDT = _normalizeEnd(googleEvent);
        final id = googleEvent.id;

        if (startDT == null || endDT == null || id == null) {
          // Skip events we can't normalize (rare, malformed events)
          continue;
        }

        final existingEvent = existingEventsByGoogleId[id];

        if (existingEvent != null) {
          // Update if needed
          final updates = <String, dynamic>{};

          final newTitle = googleEvent.summary ?? 'Untitled Event';
          final newDesc = googleEvent.description;

          if (existingEvent.title != newTitle) {
            updates['title'] = newTitle;
          }

          if (existingEvent.description != newDesc) {
            updates['description'] = newDesc;
          }

          if (existingEvent.startTime != startDT) {
            updates['startTime'] = startDT;
          }

          if (existingEvent.endTime != endDT) {
            updates['endTime'] = endDT;
          }

          if (updates.isNotEmpty) {
            await _calendarRepository.updateEvent(existingEvent.id, updates);
            updated++;
            debugPrint('✏️  Updated: ${googleEvent.summary}');
          }
        } else {
          // Create new personal event with proper userId
          final calendarEvent = CalendarEventModel(
            id: '',
            title: googleEvent.summary ?? 'Untitled Event',
            description: googleEvent.description,
            startTime: startDT,
            endTime: endDT,
            userId: userId,
            householdId: householdId,
            isShared: false,
            googleEventId: id,
            type: EventType.event,
          );

          await _calendarRepository.createEvent(calendarEvent);
          created++;
          debugPrint('➕ Created: ${googleEvent.summary}');
        }
      }

      // Delete events no longer in Google
      final googleEventIds = googleEvents
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();

      int deleted = 0;
      for (final existingEvent in existingPersonalEvents) {
        if (existingEvent.googleEventId != null &&
            !googleEventIds.contains(existingEvent.googleEventId)) {
          await _calendarRepository.deleteEvent(existingEvent.id);
          deleted++;
          debugPrint('🗑️  Deleted: ${existingEvent.title}');
        }
      }

      debugPrint('');
      debugPrint('✨ Personal Calendar Sync Summary:');
      debugPrint('   ➕ Created: $created');
      debugPrint('   ✏️  Updated: $updated');
      debugPrint('   🗑️  Deleted: $deleted');
      debugPrint('✅ Personal calendar sync completed');
    } catch (e) {
      debugPrint('❌ Error syncing personal calendar: $e');
      rethrow;
    }
  }

  // ============ SHARED CALENDAR SYNC (FIXED - No Index Issues) ============
  Future<void> syncSharedGoogleCalendar(
    String householdId,
    String sharedGoogleCalendarId,
  ) async {
    try {
      final now = DateTime.now();
      final start = now.subtract(const Duration(days: 90));
      final end = now.add(const Duration(days: 365));

      debugPrint('📅 Syncing shared calendar...');
      debugPrint('   Date range: $start to $end');

      // STEP 1: Pull events FROM Google Calendar
      final googleEvents = await _googleCalendarDataSource.fetchEvents(
        sharedGoogleCalendarId,
        start,
        end,
      );

      debugPrint('📥 Found ${googleEvents.length} events in shared Google Calendar');

      // ✅ FIXED: Use getSharedEvents instead of getEventsInRange to avoid index issues
      final existingSharedEvents = await _calendarRepository
          .getSharedEvents(householdId, start, end)
          .first;

      debugPrint('📱 Found ${existingSharedEvents.length} shared events in Firestore');

      final existingEventsByGoogleId = <String, CalendarEventModel>{};
      for (final event in existingSharedEvents) {
        if (event.googleEventId != null) {
          existingEventsByGoogleId[event.googleEventId!] = event;
        }
      }

      int created = 0;
      int updated = 0;

      for (final googleEvent in googleEvents) {
        final startDT = _normalizeStart(googleEvent);
        final endDT = _normalizeEnd(googleEvent);
        final id = googleEvent.id;

        if (startDT == null || endDT == null || id == null) {
          continue;
        }

        final existingEvent = existingEventsByGoogleId[id];

        if (existingEvent != null) {
          final updates = <String, dynamic>{};

          final newTitle = googleEvent.summary ?? 'Untitled Event';
          final newDesc = googleEvent.description;

          if (existingEvent.title != newTitle) {
            updates['title'] = newTitle;
          }

          if (existingEvent.description != newDesc) {
            updates['description'] = newDesc;
          }

          if (existingEvent.startTime != startDT) {
            updates['startTime'] = startDT;
          }

          if (existingEvent.endTime != endDT) {
            updates['endTime'] = endDT;
          }

          if (updates.isNotEmpty) {
            await _calendarRepository.updateEvent(existingEvent.id, updates);
            updated++;
            debugPrint('✏️  Updated event: ${googleEvent.summary}');
          }
        } else {
          // Create new shared event
          final calendarEvent = CalendarEventModel(
            id: '',
            title: googleEvent.summary ?? 'Untitled Event',
            description: googleEvent.description,
            startTime: startDT,
            endTime: endDT,
            userId: '',
            householdId: householdId,
            isShared: true,
            googleEventId: id,
            type: EventType.event,
          );

          await _calendarRepository.createEvent(calendarEvent);
          created++;
          debugPrint('✅ Created new event from Google: ${googleEvent.summary}');
        }
      }

      // STEP 2: Push NEW shared events FROM app TO Google Calendar
      final eventsToSync = existingSharedEvents.where(
        (e) => e.googleEventId == null,
      ).toList();

      int pushed = 0;

      for (final event in eventsToSync) {
        try {
          debugPrint('📤 Pushing local event to Google Calendar: ${event.title}');

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

          if (createdEvent != null && (createdEvent.id ?? '').isNotEmpty) {
            // 👇 Assign to a local non-nullable variable to satisfy Dart's non-promotion for public fields.
            final String googleId = createdEvent.id!;
            await _calendar_repository_update_event_id(event.id, googleId);
            pushed++;
            debugPrint('✅ Successfully pushed event to Google: ${event.title}');
          }
        } catch (e) {
          debugPrint('❌ Error pushing event ${event.title} to Google: $e');
        }
      }

      // STEP 3: Clean up deleted events
      final googleEventIds = googleEvents
          .where((e) => e.id != null)
          .map((e) => e.id!)
          .toSet();

      int deleted = 0;

      for (final existingEvent in existingSharedEvents) {
        if (existingEvent.googleEventId != null &&
            !googleEventIds.contains(existingEvent.googleEventId)) {
          await _calendarRepository.deleteEvent(existingEvent.id);
          deleted++;
          debugPrint('🗑️  Deleted event no longer in Google Calendar: ${existingEvent.title}');
        }
      }

      debugPrint('');
      debugPrint('✨ Sync Summary:');
      debugPrint('   📥 Created from Google: $created');
      debugPrint('   ✏️  Updated from Google: $updated');
      debugPrint('   📤 Pushed to Google: $pushed');
      debugPrint('   🗑️  Deleted: $deleted');
      debugPrint('✅ Bi-directional shared calendar sync completed');
      debugPrint('');
    } catch (e) {
      debugPrint('❌ Error syncing shared Google Calendar: $e');
      rethrow;
    }
  }

  // ============ CREATE/UPDATE/DELETE METHODS ============

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

      if (createdEvent != null && (createdEvent.id ?? '').isNotEmpty) {
        final String googleId = createdEvent.id!;
        await _calendarRepository.updateEvent(
          eventId,
          {'googleEventId': googleId},
        );
      }
    } catch (e) {
      debugPrint('Error creating event in both calendars: $e');
      rethrow;
    }
  }

  Future<void> createSharedEventInBoth({
    required CalendarEventModel event,
    required String sharedGoogleCalendarId,
  }) async {
    try {
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

      final eventWithGoogleId = event.copyWith(
        googleEventId: createdEvent?.id, // your model likely allows null here
        isShared: true,
      );

      await _calendarRepository.createEvent(eventWithGoogleId);

      debugPrint('Created shared event in both Google Calendar and Firestore: ${event.title}');
    } catch (e) {
      debugPrint('Error creating shared event in both calendars: $e');
      rethrow;
    }
  }

  Future<void> updateEventInBoth({
    required String eventId,
    required String googleCalendarId,
    required String googleEventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // 1) Update Firestore first
      await _calendarRepository.updateEvent(eventId, updates);

      // 2) Fetch authoritative event (may contain fields not present in updates)
      final ev = await _calendarRepository.getEventById(eventId);
      if (ev == null) return;

      // 3) Use upsert helper to guarantee end time and handle all-day correctness
      await _googleCalendarDataSource.upsertEventWithDerivedEnd(
        calendarId: googleCalendarId,
        googleEventId: googleEventId,
        startTime: ev.startTime,
        endTime: ev.endTime,
        title: ev.title,
        description: ev.description,
        isAllDay: _isAllDayFromTimes(ev.startTime, ev.endTime),
      );

      debugPrint('✅ Updated event in Google Calendar');
    } catch (e) {
      debugPrint('Error updating event in both calendars: $e');
      rethrow;
    }
  }

  Future<void> updateSharedEventInBoth({
    required String eventId,
    required String sharedGoogleCalendarId,
    required String googleEventId,
    required Map<String, dynamic> updates,
  }) async {
    try {
      // 1) Update Firestore first
      await _calendarRepository.updateEvent(eventId, updates);

      // 2) Fetch authoritative event after write
      final ev = await _calendarRepository.getEventById(eventId);
      if (ev == null) return;

      // 3) Upsert on Google (derive end when missing; handle all-day)
      await _googleCalendarDataSource.upsertEventWithDerivedEnd(
        calendarId: sharedGoogleCalendarId,
        googleEventId: googleEventId,
        startTime: ev.startTime,
        endTime: ev.endTime,
        title: ev.title,
        description: ev.description,
        isAllDay: _isAllDayFromTimes(ev.startTime, ev.endTime),
      );

      debugPrint('✅ Updated shared event in both calendars');
    } catch (e) {
      debugPrint('Error updating shared event in both calendars: $e');
      rethrow;
    }
  }

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
          googleEventId, // force non-null after explicit check
        );
      }
    } catch (e) {
      debugPrint('Error deleting event from both calendars: $e');
      rethrow;
    }
  }

  Future<void> deleteSharedEventFromBoth({
    required String eventId,
    required String sharedGoogleCalendarId,
    String? googleEventId,
  }) async {
    try {
      await _calendarRepository.deleteEvent(eventId);

      if (googleEventId != null) {
        await _googleCalendarDataSource.deleteEvent(
          sharedGoogleCalendarId,
          googleEventId, // force non-null after explicit check
        );
        debugPrint('Deleted shared event from both calendars');
      }
    } catch (e) {
      debugPrint('Error deleting shared event from both calendars: $e');
      rethrow;
    }
  }

  Future<bool> checkAvailability({
    required String userId,
    required String googleCalendarId,
    required DateTime start,
    required DateTime end,
  }) async {
    try {
      final events = await _googleCalendarDataSource.fetchEvents(
        googleCalendarId,
        start,
        end,
      );

      return events.isEmpty;
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return true;
    }
  }

  // Small helper to keep repository update for pushed shared events tidy
  // ignore: non_constant_identifier_names
  Future<void> _calendar_repository_update_event_id(
    String eventId,
    String googleId,
  ) async {
    await _calendarRepository.updateEvent(eventId, {'googleEventId': googleId});
  }
}
