import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/task_model.dart';
import '../../core/constants/firebase_constants.dart';

class TaskRepository {
  final FirebaseFirestore _firestore;

  TaskRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  // Stream of all household tasks
  Stream<List<TaskModel>> getHouseholdTasks(String householdId) {
    return _firestore
        .collection(FirebaseConstants.tasksCollection)
        .where('householdId', isEqualTo: householdId)
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }

  // Get public tasks
  Stream<List<TaskModel>> getPublicTasks(String householdId) {
    return _firestore
        .collection(FirebaseConstants.tasksCollection)
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'public')
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }

  // Get personal tasks
  Stream<List<TaskModel>> getPersonalTasks(String userId) {
    return _firestore
        .collection(FirebaseConstants.tasksCollection)
        .where('claimedBy', isEqualTo: userId)
        .where('status', whereIn: ['claimed', 'assigned'])
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }

  // Get task by ID
  Future<TaskModel?> getTaskById(String taskId) async {
    try {
      final doc = await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .doc(taskId)
          .get();

      if (doc.exists) {
        return TaskModel.fromFirestore(doc);
      }
      return null;
    } catch (e) {
print('Error getting task: $e');
      return null;
    }
  }

  // Create task
  Future<String> createTask(TaskModel task) async {
    try {
      final docRef = await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .add(task.toFirestore());
      return docRef.id;
    } catch (e) {
      print('Error creating task: $e');
      rethrow;
    }
  }

  // Claim a public task
  Future<void> claimTask(String taskId, String userId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .doc(taskId)
          .update({
        'claimedBy': userId,
        'status': TaskStatus.claimed.name,
      });
    } catch (e) {
      print('Error claiming task: $e');
      rethrow;
    }
  }

  // Complete task
  Future<void> completeTask(String taskId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .doc(taskId)
          .update({
        'status': TaskStatus.completed.name,
        'completedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  // Update task
  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .doc(taskId)
          .update(updates);
    } catch (e) {
      print('Error updating task: $e');
      rethrow;
    }
  }

  // Delete task
  Future<void> deleteTask(String taskId) async {
    try {
      await _firestore
          .collection(FirebaseConstants.tasksCollection)
          .doc(taskId)
          .delete();
    } catch (e) {
      print('Error deleting task: $e');
      rethrow;
    }
  }

  // Get completed tasks
  Stream<List<TaskModel>> getCompletedTasks(String householdId) {
    return _firestore
        .collection(FirebaseConstants.tasksCollection)
        .where('householdId', isEqualTo: householdId)
        .where('status', isEqualTo: 'completed')
        .orderBy('completedAt', descending: true)
        .limit(20)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }

  // Get overdue tasks
  Stream<List<TaskModel>> getOverdueTasks(String householdId) {
    return _firestore
        .collection(FirebaseConstants.tasksCollection)
        .where('householdId', isEqualTo: householdId)
        .where('status', whereIn: ['public', 'assigned', 'claimed'])
        .where('deadline', isLessThan: Timestamp.now())
        .orderBy('deadline')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => TaskModel.fromFirestore(doc)).toList());
  }
}