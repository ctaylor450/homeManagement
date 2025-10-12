// Create this file: lib/data/models/calendar_preferences.dart

import 'package:equatable/equatable.dart';

class CalendarPreferences extends Equatable {
  final bool autoSyncEnabled;
  final bool twoWaySyncEnabled;
  final int autoSyncIntervalMinutes;
  final DateTime? lastSyncTime;

  const CalendarPreferences({
    this.autoSyncEnabled = false,
    this.twoWaySyncEnabled = false,
    this.autoSyncIntervalMinutes = 30,
    this.lastSyncTime,
  });

  @override
  List<Object?> get props => [
        autoSyncEnabled,
        twoWaySyncEnabled,
        autoSyncIntervalMinutes,
        lastSyncTime,
      ];

  CalendarPreferences copyWith({
    bool? autoSyncEnabled,
    bool? twoWaySyncEnabled,
    int? autoSyncIntervalMinutes,
    DateTime? lastSyncTime,
  }) {
    return CalendarPreferences(
      autoSyncEnabled: autoSyncEnabled ?? this.autoSyncEnabled,
      twoWaySyncEnabled: twoWaySyncEnabled ?? this.twoWaySyncEnabled,
      autoSyncIntervalMinutes:
          autoSyncIntervalMinutes ?? this.autoSyncIntervalMinutes,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'autoSyncEnabled': autoSyncEnabled,
      'twoWaySyncEnabled': twoWaySyncEnabled,
      'autoSyncIntervalMinutes': autoSyncIntervalMinutes,
      'lastSyncTime': lastSyncTime?.toIso8601String(),
    };
  }

  factory CalendarPreferences.fromJson(Map<String, dynamic> json) {
    return CalendarPreferences(
      autoSyncEnabled: json['autoSyncEnabled'] ?? false,
      twoWaySyncEnabled: json['twoWaySyncEnabled'] ?? false,
      autoSyncIntervalMinutes: json['autoSyncIntervalMinutes'] ?? 30,
      lastSyncTime: json['lastSyncTime'] != null
          ? DateTime.parse(json['lastSyncTime'])
          : null,
    );
  }
}