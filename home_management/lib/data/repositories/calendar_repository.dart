import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event_model.dart';
import '../../core/constants/firebase_constants.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get events for a date range
  Stream<List<CalendarEventModel>> getEventsInRange(
    String householdId,
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection(FirebaseConstants.calendarEventsCollection)
        .where('householdId', isEqualTo: householdId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEventModel.fromFirestore(doc))
            .toList());
  }

  // Get personal events
  Stream<List<CalendarEventModel>> getPersonalEvents(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection(FirebaseConstants.calendarEventsCollection)
        .where('userId', isEqualTo: userId)
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThanOrEqualTo: Timestamp.fromDate(end))
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEventModel.fromFirestore(doc))
            .toList());
  }

  // Get shared events
  Stream<List<CalendarEventModel>> getSharedEvents(
    String householdId,
    DateTime start,
    DateTime end,
  ) {
    return _firestore
        .collection(FirebaseConstants.calendarEventsCollection)
        .where('householdId', isEqualTo: householdId)
        .where('isShared', isEqualTo: true)
        .orderBy('startTime')
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => CalendarEventModel.fromFirestore(doc))
            .toList());
  }

  // Create event
  Future<String> createEvent(CalendarEventModel event) async {
    try {
      final docRef = await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .add(event.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating event: $e');
      rethrow;
    }
  }

  // Update event
  Future<void> updateEvent(
      String eventId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .doc(eventId)
          .update(updates);
    } catch (e) {
      print('Error updating event: $e');
      rethrow;
    }
  }

  // Delete event
  Future<void> deleteEvent(String eventId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .doc(eventId)
          .delete();
    } catch (e) {
      print('Error deleting event: $e');
      rethrow;
    }
  }

  // Check availability
  Future<bool> checkAvailability(
    String userId,
    DateTime start,
    DateTime end,
  ) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .where('userId', isEqualTo: userId)
          .where('startTime', isLessThan: Timestamp.fromDate(end))
          .where('endTime', isGreaterThan: Timestamp.fromDate(start))
          .get();

      return snapshot.docs.isEmpty;
    } catch (e) {
      print('Error checking availability: $e');
      return false;
    }
  }
}