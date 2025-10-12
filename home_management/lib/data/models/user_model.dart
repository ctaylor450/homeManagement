import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel extends Equatable {
  final String id;
  final String name;
  final String email;
  final String? householdId;
  final String? googleCalendarId;
  final String? notificationToken;
  final bool notificationEnabled;
  final int reminderMinutes;
  final DateTime createdAt;

  const UserModel({
    required this.id,
    required this.name,
    required this.email,
    this.householdId,
    this.googleCalendarId,
    this.notificationToken,
    this.notificationEnabled = true,
    this.reminderMinutes = 30,
    required this.createdAt,
  });

  @override
  List<Object?> get props => [
        id,
        name,
        email,
        householdId,
        googleCalendarId,
        notificationToken,
        notificationEnabled,
        reminderMinutes,
        createdAt,
      ];

  UserModel copyWith({
    String? id,
    String? name,
    String? email,
    String? householdId,
    String? googleCalendarId,
    String? notificationToken,
    bool? notificationEnabled,
    int? reminderMinutes,
    DateTime? createdAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      householdId: householdId ?? this.householdId,
      googleCalendarId: googleCalendarId ?? this.googleCalendarId,
      notificationToken: notificationToken ?? this.notificationToken,
      notificationEnabled: notificationEnabled ?? this.notificationEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserModel(
      id: doc.id,
      name: data['name'] ?? '',
      email: data['email'] ?? '',
      householdId: data['householdId'],
      googleCalendarId: data['googleCalendarId'],
      notificationToken: data['notificationToken'],
      notificationEnabled: data['notificationEnabled'] ?? true,
      reminderMinutes: data['reminderMinutes'] ?? 30,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'email': email,
      'householdId': householdId,
      'googleCalendarId': googleCalendarId,
      'notificationToken': notificationToken,
      'notificationEnabled': notificationEnabled,
      'reminderMinutes': reminderMinutes,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}