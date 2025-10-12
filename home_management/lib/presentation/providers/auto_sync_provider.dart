import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/datasources/google_calendar_datasource.dart';
import '../../core/services/calendar_sync_service.dart';
import 'household_provider.dart';
import 'calendar_provider.dart';

/// Provider that manages automatic syncing of the shared calendar
final sharedCalendarAutoSyncProvider = Provider<SharedCalendarAutoSync>((ref) {
  return SharedCalendarAutoSync(ref);
});

class SharedCalendarAutoSync {
  final Ref ref;
  Timer? _syncTimer;

  SharedCalendarAutoSync(this.ref) {
    _startAutoSync();
  }

  /// Start automatic syncing every 15 minutes
  void _startAutoSync() {
    // Sync immediately on start
    _performSync();

    // Then sync every 15 minutes
    _syncTimer = Timer.periodic(
      const Duration(minutes: 15),
      (_) => _performSync(),
    );
  }

  /// Perform the sync operation
  Future<void> _performSync() async {
    try {
      // Check if auto-sync is enabled
      final prefs = await ref.read(calendarPreferencesProvider.future);
      if (!prefs.autoSyncEnabled) {
        print('Auto-sync is disabled, skipping...');
        return;
      }

      // Get the household
      final household = await ref.read(currentHouseholdProvider.future);
      
      if (household == null || household.sharedGoogleCalendarId == null) {
        print('No shared calendar linked, skipping sync');
        return;
      }

      // Check if Google Calendar is connected
      final calendarDataSource = ref.read(googleCalendarDataSourceProvider);
      final isSignedIn = await calendarDataSource.isSignedIn();
      
      if (!isSignedIn) {
        print('Google Calendar not connected, skipping sync');
        return;
      }

      // Perform the sync
      final syncService = ref.read(calendarSyncServiceProvider);
      await syncService.syncSharedGoogleCalendar(
        household.id,
        household.sharedGoogleCalendarId!,
      );

      print('Auto-sync completed at ${DateTime.now()}');
    } catch (e) {
      print('Error during auto-sync: $e');
    }
  }

  /// Manually trigger a sync
  Future<void> manualSync() async {
    await _performSync();
  }

  /// Stop the auto-sync timer
  void dispose() {
    _syncTimer?.cancel();
  }
}

/// Provider to get the shared calendar sync status
final sharedCalendarSyncStatusProvider = Provider<String>((ref) {
  final household = ref.watch(currentHouseholdProvider);
  
  return household.when(
    data: (householdData) {
      if (householdData?.sharedGoogleCalendarId == null) {
        return 'No shared calendar linked';
      } else {
        return 'Syncing with: ${householdData!.sharedGoogleCalendarId}';
      }
    },
    loading: () => 'Loading...',
    error: (_, __) => 'Error loading sync status',
  );
});