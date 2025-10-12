// Create this file: lib/core/services/calendar_preferences_service.dart

import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../../data/models/calendar_preferences.dart';

class CalendarPreferencesService {
  final FlutterSecureStorage _storage;
  static const String _prefsKey = 'calendar_preferences';

  CalendarPreferencesService(this._storage);

  /// Get calendar preferences
  Future<CalendarPreferences> getPreferences() async {
    try {
      final jsonStr = await _storage.read(key: _prefsKey);
      
      if (jsonStr == null) {
        return const CalendarPreferences();
      }

      final json = jsonDecode(jsonStr) as Map<String, dynamic>;
      return CalendarPreferences.fromJson(json);
    } catch (e) {
      print('Error reading calendar preferences: $e');
      return const CalendarPreferences();
    }
  }

  /// Save calendar preferences
  Future<void> savePreferences(CalendarPreferences prefs) async {
    try {
      final jsonStr = jsonEncode(prefs.toJson());
      await _storage.write(key: _prefsKey, value: jsonStr);
    } catch (e) {
      print('Error saving calendar preferences: $e');
      rethrow;
    }
  }

  /// Update auto-sync setting
  Future<void> setAutoSync(bool enabled) async {
    final prefs = await getPreferences();
    await savePreferences(prefs.copyWith(autoSyncEnabled: enabled));
  }

  /// Update two-way sync setting
  Future<void> setTwoWaySync(bool enabled) async {
    final prefs = await getPreferences();
    await savePreferences(prefs.copyWith(twoWaySyncEnabled: enabled));
  }

  /// Update last sync time
  Future<void> updateLastSyncTime() async {
    final prefs = await getPreferences();
    await savePreferences(prefs.copyWith(lastSyncTime: DateTime.now()));
  }

  /// Check if sync is due (based on interval)
  Future<bool> isSyncDue() async {
    final prefs = await getPreferences();
    
    if (!prefs.autoSyncEnabled) {
      return false;
    }

    if (prefs.lastSyncTime == null) {
      return true;
    }

    final now = DateTime.now();
    final minutesSinceLastSync = now.difference(prefs.lastSyncTime!).inMinutes;
    
    return minutesSinceLastSync >= prefs.autoSyncIntervalMinutes;
  }
}