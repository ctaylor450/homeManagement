import 'package:equatable/equatable.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

enum EventType { task, event }

class CalendarEventModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final DateTime startTime;
  final DateTime endTime;
  final String userId;
  final String householdId;
  final bool isShared;
  final String? googleEventId;
  final EventType type;
  final String? relatedTaskId;

  const CalendarEventModel({
    required this.id,
    required this.title,
    this.description,
    required this.startTime,
    required this.endTime,
    required this.userId,
    required this.householdId,
    this.isShared = false,
    this.googleEventId,
    this.type = EventType.event,
    this.relatedTaskId,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        description,
        startTime,
        endTime,
        userId,
        householdId,
        isShared,
        googleEventId,
        type,
        relatedTaskId,
      ];

  CalendarEventModel copyWith({
    String? id,
    String? title,
    String? description,
    DateTime? startTime,
    DateTime? endTime,
    String? userId,
    String? householdId,
    bool? isShared,
    String? googleEventId,
    EventType? type,
    String? relatedTaskId,
  }) {
    return CalendarEventModel(
      id: id ?? this.id,
      title: title ?? this.title,
      description: description ?? this.description,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      userId: userId ?? this.userId,
      householdId: householdId ?? this.householdId,
      isShared: isShared ?? this.isShared,
      googleEventId: googleEventId ?? this.googleEventId,
      type: type ?? this.type,
      relatedTaskId: relatedTaskId ?? this.relatedTaskId,
    );
  }

  factory CalendarEventModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return CalendarEventModel(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'],
      startTime: (data['startTime'] as Timestamp).toDate(),
      endTime: (data['endTime'] as Timestamp).toDate(),
      userId: data['userId'] ?? '',
      householdId: data['householdId'] ?? '',
      isShared: data['isShared'] ?? false,
      googleEventId: data['googleEventId'],
      type: EventType.values.firstWhere(
        (e) => e.name == data['type'],
        orElse: () => EventType.event,
      ),
      relatedTaskId: data['relatedTaskId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'title': title,
      'description': description,
      'startTime': Timestamp.fromDate(startTime),
      'endTime': Timestamp.fromDate(endTime),
      'userId': userId,
      'householdId': householdId,
      'isShared': isShared,
      'googleEventId': googleEventId,
      'type': type.name,
      'relatedTaskId': relatedTaskId,
    };
  }
}