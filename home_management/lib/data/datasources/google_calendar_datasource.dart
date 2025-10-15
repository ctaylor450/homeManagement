import 'package:googleapis/calendar/v3.dart';
import 'package:googleapis_auth/auth_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

class GoogleCalendarDataSource {
  // Singleton pattern
  static final GoogleCalendarDataSource _instance = GoogleCalendarDataSource._internal();
  
  factory GoogleCalendarDataSource() {
    return _instance;
  }
  
  GoogleCalendarDataSource._internal();
  
  // Instance variables
  CalendarApi? _calendarApi;
  AuthClient? _authClient;

  // Initialize with authenticated client
  Future<void> initialize(String accessToken) async {
    try {
      final credentials = AccessCredentials(
        AccessToken('Bearer', accessToken, DateTime.now().toUtc().add(Duration(hours: 1))),
        null,
        ['https://www.googleapis.com/auth/calendar'],
      );
      
      _authClient = authenticatedClient(http.Client(), credentials);
      _calendarApi = CalendarApi(_authClient!);
      debugPrint('Google Calendar API initialized successfully');
    } catch (e) {
      debugPrint('Error initializing Google Calendar API: $e');
      rethrow;
    }
  }

  Future<CalendarApi?> getCalendarApi() async {
    return _calendarApi;
  }

  Future<bool> isSignedIn() async {
    return _calendarApi != null && _authClient != null;
  }

  Future<void> signOut() async {
    _authClient?.close();
    _authClient = null;
    _calendarApi = null;
    debugPrint('Signed out from Google Calendar');
  }

  // Fetch events from Google Calendar
  Future<List<Event>> fetchEvents(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return [];
      }

      final events = await _calendarApi!.events.list(
        calendarId,
        timeMin: start.toUtc(),
        timeMax: end.toUtc(),
        singleEvents: true,
        orderBy: 'startTime',
      );

      return events.items ?? [];
    } catch (e) {
      debugPrint('Error fetching events from Google Calendar: $e');
      return [];
    }
  }

  // Create event in Google Calendar
  Future<Event?> createEvent(String calendarId, Event event) async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return null;
      }

      final createdEvent = await _calendarApi!.events.insert(event, calendarId);
      debugPrint('Event created in Google Calendar: ${createdEvent.id}');
      return createdEvent;
    } catch (e) {
      debugPrint('Error creating event in Google Calendar: $e');
      return null;
    }
  }

  // Update event in Google Calendar
  Future<Event?> updateEvent(
    String calendarId,
    String eventId,
    Event event,
  ) async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return null;
      }

      final updatedEvent = await _calendarApi!.events.update(
        event,
        calendarId,
        eventId,
      );
      debugPrint('Event updated in Google Calendar: ${updatedEvent.id}');
      return updatedEvent;
    } catch (e) {
      debugPrint('Error updating event in Google Calendar: $e');
      return null;
    }
  }

  // Add this helper inside GoogleCalendarDataSource
  Future<Event?> upsertEventWithDerivedEnd({
    required String calendarId,
    required String? googleEventId,
    required DateTime startTime,
    DateTime? endTime,
    required String title,
    String? description,
    bool isAllDay = false,
  }) async {
    if (_calendarApi == null) {
      debugPrint('Calendar API not initialized');
      return null;
    }

    // Decide all-day if you pass isAllDay or both times are midnight
    final _isAllDay = isAllDay ||
        (startTime.hour == 0 && startTime.minute == 0 &&
        (endTime?.hour ?? 0) == 0 && (endTime?.minute ?? 0) == 0);

    // Derive end if missing
    DateTime derivedEnd;
    if (_isAllDay) {
      final startDate = DateTime(startTime.year, startTime.month, startTime.day);
      final endBase = endTime ?? startDate.add(const Duration(days: 1)); // end.date is exclusive
      derivedEnd = DateTime(endBase.year, endBase.month, endBase.day);
    } else {
      derivedEnd = endTime ?? startTime.add(const Duration(hours: 1));
    }

    final ev = Event()
      ..summary = title
      ..description = description
      ..start = _isAllDay
          ? EventDateTime(date: DateTime(startTime.year, startTime.month, startTime.day))
          : EventDateTime(dateTime: startTime.toUtc(), timeZone: 'Europe/London')
      ..end = _isAllDay
          ? EventDateTime(date: DateTime(derivedEnd.year, derivedEnd.month, derivedEnd.day))
          : EventDateTime(dateTime: derivedEnd.toUtc(), timeZone: 'Europe/London');

    try {
      if (googleEventId != null && googleEventId.isNotEmpty) {
        // Fetch and merge to avoid dropping fields
        final existing = await _calendarApi!.events.get(calendarId, googleEventId);
        existing
          ..summary = ev.summary
          ..description = ev.description
          ..start = ev.start
          ..end = ev.end;
        final updated = await _calendarApi!.events.update(existing, calendarId, googleEventId);
        debugPrint('✅ Google event updated: ${updated.id}');
        return updated;
      } else {
        final created = await _calendarApi!.events.insert(ev, calendarId);
        debugPrint('✅ Google event created: ${created.id}');
        return created;
      }
    } on DetailedApiRequestError catch (e) {
      debugPrint('❌ Google error ${e.status}: ${e.message}');
      rethrow; // important so callers don’t log false success
    } catch (e) {
      debugPrint('❌ Unexpected Google error: $e');
      rethrow;
    }
  }


  // Delete event from Google Calendar
  Future<bool> deleteEvent(String calendarId, String eventId) async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return false;
      }

      await _calendarApi!.events.delete(calendarId, eventId);
      debugPrint('Event deleted from Google Calendar: $eventId');
      return true;
    } catch (e) {
      debugPrint('Error deleting event from Google Calendar: $e');
      return false;
    }
  }

  // Check if user is available during a time slot
  Future<bool> isAvailable(
    String calendarId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final events = await fetchEvents(calendarId, start, end);
      
      // Check if any events overlap with the given time range
      for (final event in events) {
        if (event.start?.dateTime == null || event.end?.dateTime == null) {
          continue;
        }
        
        final eventStart = event.start!.dateTime!;
        final eventEnd = event.end!.dateTime!;
        
        // Check for overlap
        if (eventStart.isBefore(end) && eventEnd.isAfter(start)) {
          return false;
        }
      }
      
      return true;
    } catch (e) {
      debugPrint('Error checking availability: $e');
      return false;
    }
  }

  // Get primary calendar ID
  Future<String?> getPrimaryCalendarId() async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return null;
      }

      final calendarList = await _calendarApi!.calendarList.list();
      final primaryCalendar = calendarList.items?.firstWhere(
        (cal) => cal.primary == true,
        orElse: () => calendarList.items!.first,
      );

      return primaryCalendar?.id;
    } catch (e) {
      debugPrint('Error getting primary calendar ID: $e');
      return null;
    }
  }

  // List all user calendars
  Future<List<CalendarListEntry>> listCalendars() async {
    try {
      if (_calendarApi == null) {
        debugPrint('Calendar API not initialized');
        return [];
      }

      final calendarList = await _calendarApi!.calendarList.list();
      return calendarList.items ?? [];
    } catch (e) {
      debugPrint('Error listing calendars: $e');
      return [];
    }
  }
}