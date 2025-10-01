import 'package:cloud_firestore/cloud_firestore.dart';

enum HolidayType {
  government,
  optional,
  uncertain,
}

extension HolidayTypeExtension on HolidayType {
  String get displayName {
    switch (this) {
      case HolidayType.government:
        return 'Government Holiday';
      case HolidayType.optional:
        return 'Optional Holiday';
      case HolidayType.uncertain:
        return 'Uncertain Holiday';
    }
  }

  String get value {
    switch (this) {
      case HolidayType.government:
        return 'government';
      case HolidayType.optional:
        return 'optional';
      case HolidayType.uncertain:
        return 'uncertain';
    }
  }

  static HolidayType fromString(String value) {
    switch (value) {
      case 'government':
        return HolidayType.government;
      case 'optional':
        return HolidayType.optional;
      case 'uncertain':
        return HolidayType.uncertain;
      default:
        return HolidayType.government;
    }
  }
}

class Holiday {
  final String id;
  final String name;
  final DateTime date;
  final HolidayType type;
  final String? description;
  final DateTime createdAt;
  final DateTime updatedAt;

  Holiday({
    required this.id,
    required this.name,
    required this.date,
    required this.type,
    this.description,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'date': Timestamp.fromDate(date),
      'type': type.value,
      'description': description,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }

  factory Holiday.fromJson(Map<String, dynamic> json) {
    return Holiday(
      id: json['id'],
      name: json['name'],
      date: (json['date'] as Timestamp).toDate(),
      type: HolidayTypeExtension.fromString(json['type']),
      description: json['description'],
      createdAt: json['createdAt'] != null 
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null 
          ? (json['updatedAt'] as Timestamp).toDate()
          : DateTime.now(),
    );
  }

  Holiday copyWith({
    String? id,
    String? name,
    DateTime? date,
    HolidayType? type,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Holiday(
      id: id ?? this.id,
      name: name ?? this.name,
      date: date ?? this.date,
      type: type ?? this.type,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}
