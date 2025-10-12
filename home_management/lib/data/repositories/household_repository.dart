import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:uuid/uuid.dart';
import '../models/household_model.dart';
import '../../core/constants/firebase_constants.dart';

class HouseholdRepository {
  final FirebaseFirestore _firestore;
  final Uuid _uuid;

  HouseholdRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance,
        _uuid = const Uuid();

  // Get household by ID
  Future<HouseholdModel?> getHouseholdById(String householdId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .doc(householdId)
          .get();

      if (doc.exists) {
        return HouseholdModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting household: $e');
      return null;
    }
  }

  // Stream of household data
  Stream<HouseholdModel?> getHouseholdStream(String householdId) {
    return _firestore
        .collection(FirebaseConstants.householdsCollection)
        .doc(householdId)
        .snapshots()
        .map((doc) => doc.exists ? HouseholdModel.fromFirestore(doc) : null);
  }

  // Create household
  Future<String> createHousehold(String name, String creatorId) async {
    try {
      final inviteCode = _generateInviteCode();
      final household = HouseholdModel(
        id: '',
        name: name,
        memberIds: [creatorId],
        inviteCode: inviteCode,
        createdAt: DateTime.now(),
      );

      final docRef = await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .add(household.toFirestore());

      return docRef.id;
    } catch (e) {
      print('Error creating household: $e');
      rethrow;
    }
  }

  // Join household by invite code
  Future<String?> joinHouseholdByInviteCode(
      String inviteCode, String userId) async {
    try {
      final snapshot = await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .where('inviteCode', isEqualTo: inviteCode)
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null;
      }

      final householdDoc = snapshot.docs.first;
      final household = HouseholdModel.fromFirestore(householdDoc);

      if (!household.memberIds.contains(userId)) {
        await householdDoc.reference.update({
          'memberIds': FieldValue.arrayUnion([userId])
        });
      }

      return householdDoc.id;
    } catch (e) {
      print('Error joining household: $e');
      return null;
    }
  }

  // Remove member from household
  Future<void> removeMemberFromHousehold(
      String householdId, String userId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .doc(householdId)
          .update({
        'memberIds': FieldValue.arrayRemove([userId])
      });
    } catch (e) {
      print('Error removing member: $e');
      rethrow;
    }
  }

  // Update household name
  Future<void> updateHouseholdName(String householdId, String name) async {
    try {
      await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .doc(householdId)
          .update({'name': name});
    } catch (e) {
      print('Error updating household name: $e');
      rethrow;
    }
  }

  // Generate a random 6-character invite code
  String _generateInviteCode() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    return List.generate(6, (index) => chars[DateTime.now().millisecond % chars.length]).join();
  }

  // Regenerate invite code
  Future<String> regenerateInviteCode(String householdId) async {
    try {
      final newCode = _generateInviteCode();
      await _firestore
          .collection(FirebaseConstants.householdsCollection)
          .doc(householdId)
          .update({'inviteCode': newCode});
      return newCode;
    } catch (e) {
      print('Error regenerating invite code: $e');
      rethrow;
    }
  }
}