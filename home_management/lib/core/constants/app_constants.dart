class AppConstants {
  // App Info
  static const String appName = 'Home Organizer';
  static const String appVersion = '1.0.0';
  
  // Notification Settings
  static const int defaultReminderMinutes = 30;
  static const String notificationChannelId = 'task_reminders';
  static const String notificationChannelName = 'Task Reminders';
  static const String notificationChannelDescription = 'Notifications for task deadlines';
  
  // Task Defaults
  static const int defaultTaskDuration = 60; // minutes
  
  // Date Formats
  static const String dateFormat = 'MMM dd, yyyy';
  static const String timeFormat = 'hh:mm a';
  static const String dateTimeFormat = 'MMM dd, yyyy • hh:mm a';
  
  // Pagination
  static const int tasksPerPage = 20;
  
  // Calendar
  static const int calendarSyncIntervalMinutes = 15;
  
  // Error Messages
  static const String genericError = 'Something went wrong. Please try again.';
  static const String networkError = 'Please check your internet connection.';
  static const String authError = 'Authentication failed. Please sign in again.';
}