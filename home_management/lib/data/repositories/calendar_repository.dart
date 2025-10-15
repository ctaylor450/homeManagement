// lib/data/repositories/calendar_repository.dart
// FINAL FIX - Replace entire file with this

import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/calendar_event_model.dart';
import '../../core/constants/firebase_constants.dart';

class CalendarRepository {
  final FirebaseFirestore _firestore;

  CalendarRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get events for a date range (for main calendar view)
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

  // FIXED: Simplified shared events query
  Stream<List<CalendarEventModel>> getSharedEvents(
    String householdId,
    DateTime start,
    DateTime end,
  ) {
    print('🔍 Repository: Querying shared events');
    print('   householdId: $householdId');
    print('   start: $start');
    print('   end: $end');
    
    return _firestore
        .collection(FirebaseConstants.calendarEventsCollection)
        .where('householdId', isEqualTo: householdId)
        .where('isShared', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
          print('📦 Repository: Raw snapshot has ${snapshot.docs.length} documents');
          
          final allEvents = snapshot.docs.map((doc) {
            try {
              return CalendarEventModel.fromFirestore(doc);
            } catch (e) {
              print('❌ Error parsing document ${doc.id}: $e');
              return null;
            }
          }).whereType<CalendarEventModel>().toList();
          
          print('📄 Repository: Parsed ${allEvents.length} events successfully');
          
          // Sort by startTime
          allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
          
          // Filter by date range - FIXED logic
          final filtered = allEvents.where((event) {
            // Event must be on or after start date AND before or on end date
            final isAfterOrOnStart = event.startTime.isAtSameMomentAs(start) || 
                                      event.startTime.isAfter(start);
            final isBeforeOrOnEnd = event.startTime.isBefore(end) || 
                                     event.startTime.isAtSameMomentAs(end);
            
            final included = isAfterOrOnStart && isBeforeOrOnEnd;
            
            if (!included) {
              print('   ❌ Filtered OUT: ${event.title} (${event.startTime})');
              print('      isAfterOrOnStart: $isAfterOrOnStart, isBeforeOrOnEnd: $isBeforeOrOnEnd');
            } else {
              print('   ✅ Included: ${event.title} (${event.startTime})');
            }
            
            return included;
          }).toList();
          
          print('✅ Repository: Returning ${filtered.length} filtered events');
          return filtered;
        });
  }

  // FIXED: Simplified personal events query
  Stream<List<CalendarEventModel>> getPersonalEvents(
    String userId,
    DateTime start,
    DateTime end,
  ) {
    print('🔍 Repository: Querying personal events for userId: $userId');
    
    return _firestore
        .collection(FirebaseConstants.calendarEventsCollection)
        .where('userId', isEqualTo: userId)
        .where('isShared', isEqualTo: false)
        .snapshots()
        .map((snapshot) {
          print('📦 Repository: Found ${snapshot.docs.length} personal events');
          
          final allEvents = snapshot.docs
              .map((doc) => CalendarEventModel.fromFirestore(doc))
              .toList();
          
          // Sort by startTime
          allEvents.sort((a, b) => a.startTime.compareTo(b.startTime));
          
          // Filter by date range - FIXED logic
          return allEvents.where((event) {
            final isAfterOrOnStart = event.startTime.isAtSameMomentAs(start) || 
                                      event.startTime.isAfter(start);
            final isBeforeOrOnEnd = event.startTime.isBefore(end) || 
                                     event.startTime.isAtSameMomentAs(end);
            return isAfterOrOnStart && isBeforeOrOnEnd;
          }).toList();
        });
  }

  // Create event
  Future<String> createEvent(CalendarEventModel event) async {
    try {
      print('💾 Creating event: ${event.title}');
      print('   - householdId: ${event.householdId}');
      print('   - isShared: ${event.isShared}');
      
      final docRef = await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .add(event.toFirestore());
      
      print('✅ Event created with ID: ${docRef.id}');
      return docRef.id;
    } catch (e) {
      print('❌ Error creating event: $e');
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

  // Get event by ID
  Future<CalendarEventModel?> getEventById(String eventId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConstants.calendarEventsCollection)
          .doc(eventId)
          .get();

      if (doc.exists) {
        return CalendarEventModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting event: $e');
      rethrow;
    }
  }

  // Check availability (no overlapping events)
  Future<bool> checkAvailability(
      String userId, DateTime start, DateTime end) async {
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