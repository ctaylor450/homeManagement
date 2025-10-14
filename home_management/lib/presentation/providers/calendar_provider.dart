// lib/presentation/providers/calendar_provider.dart
// COMPLETE FILE WITH BI-DIRECTIONAL SYNC FIXES

import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/calendar_repository.dart';
import '../../data/datasources/google_calendar_datasource.dart';
import '../../data/models/calendar_event_model.dart';
import '../../data/models/calendar_preferences.dart';
import '../../core/services/calendar_sync_service.dart';
import '../../core/services/calendar_preferences_service.dart';
import 'auth_provider.dart';
import 'household_provider.dart';

// ============================================================================
// PROVIDERS
// ============================================================================

// Calendar repository provider
final calendarRepositoryProvider = Provider<CalendarRepository>((ref) {
  return CalendarRepository();
});

// Google Calendar datasource provider - returns singleton instance
final googleCalendarDataSourceProvider = Provider<GoogleCalendarDataSource>((ref) {
  return GoogleCalendarDataSource(); // Singleton instance
});

// Calendar sync service provider
final calendarSyncServiceProvider = Provider<CalendarSyncService>((ref) {
  final googleCalendarDataSource = ref.watch(googleCalendarDataSourceProvider);
  final calendarRepository = ref.watch(calendarRepositoryProvider);
  return CalendarSyncService(googleCalendarDataSource, calendarRepository);
});

// Calendar preferences service provider
final calendarPreferencesServiceProvider = Provider<CalendarPreferencesService>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return CalendarPreferencesService(storage);
});

// Calendar preferences provider
final calendarPreferencesProvider = FutureProvider<CalendarPreferences>((ref) async {
  final service = ref.watch(calendarPreferencesServiceProvider);
  return await service.getPreferences();
});

// Auto-sync enabled state provider
final autoSyncEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(calendarPreferencesProvider.future);
  return prefs.autoSyncEnabled;
});

// Two-way sync enabled state provider
final twoWaySyncEnabledProvider = FutureProvider<bool>((ref) async {
  final prefs = await ref.watch(calendarPreferencesProvider.future);
  return prefs.twoWaySyncEnabled;
});

// Selected date provider (for calendar navigation)
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

// ============================================================================
// CALENDAR ACTIONS CLASS (FIXED)
// ============================================================================

class CalendarActions {
  final Ref ref;

  CalendarActions(this.ref);

  /// Create event (with proper shared calendar support) - FIXED
  Future<void> createEvent(CalendarEventModel event, {bool? syncToGoogle}) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);
      
      // Determine if we should sync to Google
      bool shouldSync = syncToGoogle ?? false;
      
      if (syncToGoogle == null) {
        final prefs = await ref.read(calendarPreferencesProvider.future);
        shouldSync = prefs.twoWaySyncEnabled;
      }
      
      if (shouldSync) {
        // FIXED: Check if this is a SHARED event
        if (event.isShared) {
          // Use household's shared calendar
          final household = ref.read(currentHouseholdProvider).value;
          final sharedCalendarId = household?.sharedGoogleCalendarId;
          
          if (sharedCalendarId != null) {
            // FIXED: Use new method for shared events
            await syncService.createSharedEventInBoth(
              event: event,
              sharedGoogleCalendarId: sharedCalendarId,
            );
            return;
          }
        } else {
          // Use user's personal calendar
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
      }
      
      // If not syncing to Google, just create in Firestore
      await repository.createEvent(event);
    } catch (e) {
      // ignore: avoid_print
      print('Error creating event: $e');
      rethrow;
    }
  }

  /// Update event (with proper shared calendar support) - FIXED
  Future<void> updateEvent(
    String eventId, 
    Map<String, dynamic> updates,
    {bool? syncToGoogle}
  ) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);
      
      // Determine if we should sync to Google
      bool shouldSync = syncToGoogle ?? false;
      
      if (syncToGoogle == null) {
        final prefs = await ref.read(calendarPreferencesProvider.future);
        shouldSync = prefs.twoWaySyncEnabled;
      }
      
      if (shouldSync) {
        // Get the event to check if it's shared and has a Google event ID
        final householdId = ref.read(currentHouseholdIdProvider);
        final events = await repository.getEventsInRange(
          householdId!,
          DateTime.now().subtract(const Duration(days: 365)),
          DateTime.now().add(const Duration(days: 365)),
        ).first;
        
        final event = events.firstWhere((e) => e.id == eventId);
        
        if (event.googleEventId != null) {
          // FIXED: Check if event is shared and use correct calendar
          if (event.isShared) {
            // Update in shared calendar
            final household = ref.read(currentHouseholdProvider).value;
            final sharedCalendarId = household?.sharedGoogleCalendarId;
            
            if (sharedCalendarId != null) {
              await syncService.updateSharedEventInBoth(
                eventId: eventId,
                sharedGoogleCalendarId: sharedCalendarId,
                googleEventId: event.googleEventId!,
                updates: updates,
              );
              return;
            }
          } else {
            // Update in personal calendar
            final user = ref.read(currentUserProvider).value;
            final googleCalendarId = user?.googleCalendarId;
            
            if (googleCalendarId != null) {
              await syncService.updateEventInBoth(
                eventId: eventId,
                googleCalendarId: googleCalendarId,
                googleEventId: event.googleEventId!,
                updates: updates,
              );
              return;
            }
          }
        }
      }
      
      await repository.updateEvent(eventId, updates);
    } catch (e) {
      // ignore: avoid_print
      print('Error updating event: $e');
      rethrow;
    }
  }

  /// Delete event (with proper shared calendar support) - FIXED
  Future<void> deleteEvent(
    String eventId,
    {bool? syncToGoogle}
  ) async {
    try {
      final repository = ref.read(calendarRepositoryProvider);
      final syncService = ref.read(calendarSyncServiceProvider);
      
      // Determine if we should sync to Google
      bool shouldSync = syncToGoogle ?? false;
      
      if (syncToGoogle == null) {
        final prefs = await ref.read(calendarPreferencesProvider.future);
        shouldSync = prefs.twoWaySyncEnabled;
      }
      
      if (shouldSync) {
        // Get the event to check if it's shared
        final householdId = ref.read(currentHouseholdIdProvider);
        final events = await repository.getEventsInRange(
          householdId!,
          DateTime.now().subtract(const Duration(days: 365)),
          DateTime.now().add(const Duration(days: 365)),
        ).first;
        
        final event = events.firstWhere((e) => e.id == eventId);
        
        // FIXED: Check if event is shared and use correct calendar
        if (event.isShared) {
          // Delete from shared calendar
          final household = ref.read(currentHouseholdProvider).value;
          final sharedCalendarId = household?.sharedGoogleCalendarId;
          
          if (sharedCalendarId != null) {
            await syncService.deleteSharedEventFromBoth(
              eventId: eventId,
              sharedGoogleCalendarId: sharedCalendarId,
              googleEventId: event.googleEventId,
            );
            return;
          }
        } else {
          // Delete from personal calendar
          final user = ref.read(currentUserProvider).value;
          final googleCalendarId = user?.googleCalendarId;
          
          if (googleCalendarId != null) {
            await syncService.deleteEventFromBoth(
              eventId: eventId,
              googleCalendarId: googleCalendarId,
              googleEventId: event.googleEventId,
            );
            return;
          }
        }
      }
      
      await repository.deleteEvent(eventId);
    } catch (e) {
      // ignore: avoid_print
      print('Error deleting event: $e');
      rethrow;
    }
  }

  /// Sync all Google Calendar events to Firestore - ENHANCED
  Future<void> syncGoogleCalendar() async {
    try {
      final syncService = ref.read(calendarSyncServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      final householdId = ref.read(currentHouseholdIdProvider);
      final user = ref.read(currentUserProvider).value;
      final household = ref.read(currentHouseholdProvider).value;

      if (userId == null || householdId == null) {
        throw Exception('User or household not found');
      }

      // Sync personal calendar
      if (user?.googleCalendarId != null) {
        await syncService.syncGoogleCalendar(
          userId,
          householdId,
          user!.googleCalendarId!,
        );
      }

      // ADDED: Sync shared calendar (bi-directional)
      if (household?.sharedGoogleCalendarId != null) {
        await syncService.syncSharedGoogleCalendar(
          householdId,
          household!.sharedGoogleCalendarId!,
        );
      }

      // Update last sync time
      final prefsService = ref.read(calendarPreferencesServiceProvider);
      await prefsService.updateLastSyncTime();
      
      // Invalidate preferences to refresh UI
      ref.invalidate(calendarPreferencesProvider);
      
      // ignore: avoid_print
      print('Google Calendar synced successfully');
    } catch (e) {
      // ignore: avoid_print
      print('Error syncing Google Calendar: $e');
      rethrow;
    }
  }

  /// Check availability across both Firestore and Google Calendar
  // Future<bool> checkAvailability({
  //   required DateTime start,
  //   required DateTime end,
  // }) async {
  //   try {
  //     final syncService = ref.read(calendarSyncServiceProvider);
  //     final userId = ref.read(currentUserIdProvider);
  //     final user = ref.read(currentUserProvider).value;

  //     if (userId == null) {
  //       throw Exception('No user logged in');
  //     }

  //     final googleCalendarId = user?.googleCalendarId;
      
  //     if (googleCalendarId != null) {
  //       return await syncService.checkAvailability(
  //         userId: userId,
  //         googleCalendarId: googleCalendarId,
  //         start: start,
  //         end: end,
  //       );
  //     } else {
  //       // Just check Firestore if no Google Calendar
  //       final repository = ref.read(calendarRepositoryProvider);
  //       return await repository.checkAvailability(userId, start, end);
  //     }
  //   } catch (e) {
  //     // ignore: avoid_print
  //     print('Error checking availability: $e');
  //     return false;
  //   }
  // }

  /// Force refresh Google Calendar access token
  Future<void> refreshGoogleCalendarToken() async {
    try {
      final authActions = ref.read(authActionsProvider);
      final accessToken = await authActions.refreshGoogleAccessToken();
      
      if (accessToken != null) {
        // ignore: avoid_print
        print('Google Calendar token refreshed');
      } else {
        throw Exception('Failed to refresh token');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error refreshing token: $e');
      rethrow;
    }
  }

  /// Toggle auto-sync
  Future<void> setAutoSync(bool enabled) async {
    try {
      final service = ref.read(calendarPreferencesServiceProvider);
      await service.setAutoSync(enabled);
      
      // Invalidate the preferences provider to refresh UI
      ref.invalidate(calendarPreferencesProvider);
      
      // If enabling auto-sync, do an immediate sync
      if (enabled) {
        await syncGoogleCalendar();
      }
      
      // ignore: avoid_print
      print('Auto-sync ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      // ignore: avoid_print
      print('Error setting auto-sync: $e');
      rethrow;
    }
  }

  /// Toggle two-way sync
  Future<void> setTwoWaySync(bool enabled) async {
    try {
      final service = ref.read(calendarPreferencesServiceProvider);
      await service.setTwoWaySync(enabled);
      
      // Invalidate the preferences provider to refresh UI
      ref.invalidate(calendarPreferencesProvider);
      
      // ignore: avoid_print
      print('Two-way sync ${enabled ? 'enabled' : 'disabled'}');
    } catch (e) {
      // ignore: avoid_print
      print('Error setting two-way sync: $e');
      rethrow;
    }
  }

  /// Perform auto-sync if enabled and due
  Future<void> autoSyncIfDue() async {
    try {
      final service = ref.read(calendarPreferencesServiceProvider);
      final isDue = await service.isSyncDue();
      
      if (isDue) {
        await syncGoogleCalendar();
        // ignore: avoid_print
        print('Auto-sync completed');
      }
    } catch (e) {
      // ignore: avoid_print
      print('Error in auto-sync: $e');
      // Don't rethrow - auto-sync should fail silently
    }
  }
}