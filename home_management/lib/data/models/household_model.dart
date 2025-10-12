import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class HouseholdModel extends Equatable {
  final String id;
  final String name;
  final List<String> memberIds;
  final String inviteCode;
  final DateTime createdAt;

  const HouseholdModel({
    required this.id,
    required this.name,
    required this.memberIds,
    required this.inviteCode,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        memberIds,
        inviteCode,
        createdAt,
      ];

  HouseholdModel copyWith({
    String? id,
    String? name,
    List<String>? memberIds,
    String? inviteCode,
    DateTime? createdAt,
  }) {
    return HouseholdModel(
      id: id ?? this.id,
      name: name ?? this.name,
      memberIds: memberIds ?? this.memberIds,
      inviteCode: inviteCode ?? this.inviteCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory HouseholdModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return HouseholdModel(
      id: doc.id,
      name: data['name'] ?? '',
      memberIds: List<String>.from(data['memberIds'] ?? []),
      inviteCode: data['inviteCode'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'memberIds': memberIds,
      'inviteCode': inviteCode,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}