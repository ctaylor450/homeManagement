import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/task_repository.dart';
import '../../data/models/task_model.dart';
import 'auth_provider.dart';

// Task repository provider
final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository();
});

// Public tasks stream
final publicTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  return repository.getPublicTasks(householdId);
});

// Personal tasks stream
final personalTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final userId = ref.watch(currentUserIdProvider);

  if (userId == null) {
    return Stream.value([]);
  }

  return repository.getPersonalTasks(userId);
});

// All household tasks stream
final householdTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  return repository.getHouseholdTasks(householdId);
});

// Completed tasks stream
final completedTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  return repository.getCompletedTasks(householdId);
});

// Overdue tasks stream
final overdueTasksProvider = StreamProvider.autoDispose<List<TaskModel>>((ref) {
  final repository = ref.watch(taskRepositoryProvider);
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value([]);
  }

  return repository.getOverdueTasks(householdId);
});

// Task actions provider
final taskActionsProvider = Provider<TaskActions>((ref) {
  return TaskActions(ref);
});

class TaskActions {
  final Ref ref;

  TaskActions(this.ref);

  Future<void> createTask(TaskModel task) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.createTask(task);
    } catch (e) {
      print('Error creating task: $e');
      rethrow;
    }
  }

  Future<void> claimTask(String taskId) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (userId != null) {
        await repository.claimTask(taskId, userId);
      }
    } catch (e) {
      print('Error claiming task: $e');
      rethrow;
    }
  }

  Future<void> completeTask(String taskId) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.completeTask(taskId);
    } catch (e) {
      print('Error completing task: $e');
      rethrow;
    }
  }

  Future<void> updateTask(String taskId, Map<String, dynamic> updates) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.updateTask(taskId, updates);
    } catch (e) {
      print('Error updating task: $e');
      rethrow;
    }
  }

  Future<void> deleteTask(String taskId) async {
    try {
      final repository = ref.read(taskRepositoryProvider);
      await repository.deleteTask(taskId);
    } catch (e) {
      print('Error deleting task: $e');
      rethrow;
    }
  }
}