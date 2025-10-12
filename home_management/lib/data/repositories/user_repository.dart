import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../../core/constants/firebase_constants.dart';

class UserRepository {
  final FirebaseFirestore _firestore;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Get user by ID
  Future<UserModel?> getUserById(String userId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .get();

      if (doc.exists) {
        return UserModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting user: $e');
      return null;
    }
  }

  // Stream of user data
  Stream<UserModel?> getUserStream(String userId) {
    return _firestore
        .collection(FirebaseConstants.usersCollection)
        .doc(userId)
        .snapshots()
        .map((doc) => doc.exists ? UserModel.fromFirestore(doc) : null);
  }

  // Create user
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(user.id)
          .set(user.toFirestore());
    } catch (e) {
      print('Error creating user: $e');
      rethrow;
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(FirebaseConstants.usersCollection)
          .doc(userId)
          .update(updates);
    } catch (e) {
      print('Error updating user: $e');
      rethrow;
    }
  }

  // Get household members
  Future<List<UserModel>> getHouseholdMembers(String householdId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.usersCollection)
          .where('householdId', isEqualTo: householdId)
          .get();

      return snapshot.docs
          .map((doc) => UserModel.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error getting household members: $e');
      return [];
    }
  }

  // Update notification token
  Future<void> updateNotificationToken(String userId, String token) async {
    try {
      await updateUser(userId, {'notificationToken': token});
    } catch (e) {
      print('Error updating notification token: $e');
      rethrow;
    }
  }

  // Update Google Calendar ID
  Future<void> updateGoogleCalendarId(
      String userId, String calendarId) async {
    try {
      await updateUser(userId, {'googleCalendarId': calendarId});
    } catch (e) {
      print('Error updating Google Calendar ID: $e');
      rethrow;
    }
  }
}