import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/repositories/household_repository.dart';
import '../../data/models/household_model.dart';
import '../../data/models/user_model.dart';
import 'auth_provider.dart';

// Household repository provider
final householdRepositoryProvider = Provider<HouseholdRepository>((ref) {
  return HouseholdRepository();
});

// Current household stream
final currentHouseholdProvider = StreamProvider.autoDispose<HouseholdModel?>((ref) {
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return Stream.value(null);
  }

  final repository = ref.watch(householdRepositoryProvider);
  return repository.getHouseholdStream(householdId);
});

// Household members provider
final householdMembersProvider = FutureProvider.autoDispose<List<UserModel>>((ref) async {
  final householdId = ref.watch(currentHouseholdIdProvider);

  if (householdId == null) {
    return [];
  }

  final userRepository = ref.watch(userRepositoryProvider);
  return await userRepository.getHouseholdMembers(householdId);
});

// Household actions provider
final householdActionsProvider = Provider<HouseholdActions>((ref) {
  return HouseholdActions(ref);
});

class HouseholdActions {
  final Ref ref;

  HouseholdActions(this.ref);

  Future<String> createHousehold(String name) async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Create household
      final householdId = await repository.createHousehold(name, userId);

      // Update user with household ID
      await userRepository.updateUser(userId, {'householdId': householdId});

      return householdId;
    } catch (e) {
      print('Error creating household: $e');
      rethrow;
    }
  }

  Future<void> joinHousehold(String inviteCode) async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);

      if (userId == null) {
        throw Exception('User not authenticated');
      }

      // Join household
      final householdId = await repository.joinHouseholdByInviteCode(
        inviteCode,
        userId,
      );

      if (householdId == null) {
        throw Exception('Invalid invite code');
      }

      // Update user with household ID
      await userRepository.updateUser(userId, {'householdId': householdId});
    } catch (e) {
      print('Error joining household: $e');
      rethrow;
    }
  }

  Future<void> leaveHousehold() async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final userRepository = ref.read(userRepositoryProvider);
      final userId = ref.read(currentUserIdProvider);
      final householdId = ref.read(currentHouseholdIdProvider);

      if (userId == null || householdId == null) {
        throw Exception('User or household not found');
      }

      // Remove from household
      await repository.removeMemberFromHousehold(householdId, userId);

      // Update user to remove household ID
      await userRepository.updateUser(userId, {'householdId': null});
    } catch (e) {
      print('Error leaving household: $e');
      rethrow;
    }
  }

  Future<String> regenerateInviteCode() async {
    try {
      final repository = ref.read(householdRepositoryProvider);
      final householdId = ref.read(currentHouseholdIdProvider);

      if (householdId == null) {
        throw Exception('Household not found');
      }

      return await repository.regenerateInviteCode(householdId);
    } catch (e) {
      print('Error regenerating invite code: $e');
      rethrow;
    }
  }
}