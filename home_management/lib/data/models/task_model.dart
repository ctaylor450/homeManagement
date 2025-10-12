import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum TaskStatus { public, assigned, claimed, completed }
enum TaskPriority { high, medium, low }

class TaskModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final TaskStatus status;
  final String? assignedTo;
  final String? claimedBy;
  final String householdId;
  final DateTime deadline;
  final TaskPriority priority;
  final String createdBy;
  final DateTime createdAt;
  final DateTime? completedAt;
  final int estimatedDuration;
  final List<String> tags;

  const TaskModel({
    required this.id,
    required this.title,
    this.description,
    required this.status,
    this.assignedTo,
    this.claimedBy,
    required this.householdId,
    required this.deadline,
    required this.priority,
    required this.createdBy,
    required this.createdAt,
    this.completedAt,
    this.estimatedDuration = 60,
    this.tags = const [],
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        status,
        assignedTo,
        claimedBy,
        householdId,
        deadline,
        priority,
        createdBy,
        createdAt,
        completedAt,
        estimatedDuration,
        tags,
      ];

  TaskModel copyWith({
    String? id,
    String? title,
    String? description,
    TaskStatus? status,
    String? assignedTo,
    String? claimedBy,
    String? householdId,
    DateTime? deadline,
    TaskPriority? priority,
    String? createdBy,
    DateTime? createdAt,
    DateTime? completedAt,
    int? estimatedDuration,
    List<String>? tags,
  }) {
    return TaskModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      status: status ?? this.status,
      assignedTo: assignedTo ?? this.assignedTo,
      claimedBy: claimedBy ?? this.claimedBy,
      householdId: householdId ?? this.householdId,
      deadline: deadline ?? this.deadline,
      priority: priority ?? this.priority,
      createdBy: createdBy ?? this.createdBy,
      createdAt: createdAt ?? this.createdAt,
      completedAt: completedAt ?? this.completedAt,
      estimatedDuration: estimatedDuration ?? this.estimatedDuration,
      tags: tags ?? this.tags,
    );
  }

  factory TaskModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return TaskModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      status: TaskStatus.values.firstWhere(
        (e) => e.name == data['status'],
        orElse: () => TaskStatus.public,
      ),
      assignedTo: data['assignedTo'],
      claimedBy: data['claimedBy'],
      householdId: data['householdId'] ?? '',
      deadline: (data['deadline'] as Timestamp).toDate(),
      priority: TaskPriority.values.firstWhere(
        (e) => e.name == data['priority'],
        orElse: () => TaskPriority.medium,
      ),
      createdBy: data['createdBy'] ?? '',
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      completedAt: data['completedAt'] != null
          ? (data['completedAt'] as Timestamp).toDate()
          : null,
      estimatedDuration: data['estimatedDuration'] ?? 60,
      tags: List<String>.from(data['tags'] ?? []),
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'status': status.name,
      'assignedTo': assignedTo,
      'claimedBy': claimedBy,
      'householdId': householdId,
      'deadline': Timestamp.fromDate(deadline),
      'priority': priority.name,
      'createdBy': createdBy,
      'createdAt': Timestamp.fromDate(createdAt),
      'completedAt': completedAt != null ? Timestamp.fromDate(completedAt!) : null,
      'estimatedDuration': estimatedDuration,
      'tags': tags,
    };
  }
}