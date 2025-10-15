class FirebaseConstants {
  // Collection Names
  static const String usersCollection = 'users';
  static const String householdsCollection = 'households';
  static const String tasksCollection = 'tasks';
  static const String calendarEventsCollection = 'calendar_events';
  static const String notificationsCollection = 'notifications';

  // Subcollections
  static const String fcmTokensSubcollection = 'fcmTokens';
  
  // Field Names
  static const String userId = 'userId';
  static const String householdId = 'householdId';
  static const String createdAt = 'createdAt';
  static const String updatedAt = 'updatedAt';
  static const String deadline = 'deadline';
  static const String status = 'status';
}