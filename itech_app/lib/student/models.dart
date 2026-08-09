import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show IconData, Color;

enum BorrowingStatus { pending, active, returned, overdue, rejected, approved }

@immutable
class Equipment {
  final String id;

  /// Human-readable inventory code, separate from the database UUID [id].
  final String code;
  final String name;
  final String category;
  final String location;
  final int available;
  final int total;
  final String description;
  final bool isLiked;

  const Equipment({
    required this.id,
    this.code = '',
    required this.name,
    required this.category,
    required this.location,
    required this.available,
    required this.total,
    required this.description,
    this.isLiked = false,
  });

  Equipment copyWith({
    String? id,
    String? code,
    String? name,
    String? category,
    String? location,
    int? available,
    int? total,
    String? description,
    bool? isLiked,
  }) {
    return Equipment(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      location: location ?? this.location,
      available: available ?? this.available,
      total: total ?? this.total,
      description: description ?? this.description,
      isLiked: isLiked ?? this.isLiked,
    );
  }
}

@immutable
class Borrowing {
  final String id;
  final String equipmentId;
  final String equipmentName;
  final String studentId;
  final String studentName;
  final String purpose;
  final DateTime borrowDate;
  final DateTime returnDate;
  final BorrowingStatus status;
  final bool borrowedByYou;
  final String qrCode;

  /// Number of units requested from this equipment stock record.
  final int quantity;

  /// Preserves when the student made the request, even after approval.
  final DateTime requestedAt;

  const Borrowing({
    required this.id,
    required this.equipmentId,
    required this.equipmentName,
    this.studentId = '2024-0xxxx-MN-0',
    this.studentName = 'Juan Dela Cruz',
    this.purpose = '',
    required this.borrowDate,
    required this.returnDate,
    required this.status,
    this.borrowedByYou = true,
    required this.qrCode,
    this.quantity = 1,
    DateTime? requestedAt,
  }) : requestedAt = requestedAt ?? borrowDate;

  Duration remaining() => returnDate.difference(DateTime.now());

  Borrowing copyWith({
    String? id,
    String? equipmentId,
    String? equipmentName,
    String? studentId,
    String? studentName,
    String? purpose,
    DateTime? borrowDate,
    DateTime? returnDate,
    BorrowingStatus? status,
    bool? borrowedByYou,
    String? qrCode,
    int? quantity,
    DateTime? requestedAt,
  }) {
    return Borrowing(
      id: id ?? this.id,
      equipmentId: equipmentId ?? this.equipmentId,
      equipmentName: equipmentName ?? this.equipmentName,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      purpose: purpose ?? this.purpose,
      borrowDate: borrowDate ?? this.borrowDate,
      returnDate: returnDate ?? this.returnDate,
      status: status ?? this.status,
      borrowedByYou: borrowedByYou ?? this.borrowedByYou,
      qrCode: qrCode ?? this.qrCode,
      quantity: quantity ?? this.quantity,
      requestedAt: requestedAt ?? this.requestedAt,
    );
  }
}

enum NotificationType {
  approved,
  rejected,
  reminder,
  overdue,
  newItem,
  returned,
}

/// How active a logged-in session is right now.
enum SessionActivity { active, idle, returning }

/// One currently-logged-in user. Mocked for the prototype; in production
/// this would come from the auth backend.
@immutable
class ActiveSession {
  const ActiveSession({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.program,
    required this.equipmentName,
    required this.equipmentId,
    required this.loginAt,
    required this.lastActivityAt,
    required this.activity,
    this.location,
  });

  final String id;
  final String studentId;
  final String studentName;
  final String program;

  /// Empty when the user is logged in but hasn't borrowed anything yet.
  final String equipmentName;
  final String equipmentId;

  /// Optional physical location (e.g. "Room 301 - Electronics Lab").
  final String? location;

  final DateTime loginAt;
  final DateTime lastActivityAt;
  final SessionActivity activity;

  String get initials {
    final parts = studentName.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts.first.isEmpty
          ? '?'
          : parts.first.substring(0, 1).toUpperCase();
    }
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1))
        .toUpperCase();
  }

  Duration get sinceLastActivity => DateTime.now().difference(lastActivityAt);

  ActiveSession copyWith({
    String? id,
    String? studentId,
    String? studentName,
    String? program,
    String? equipmentName,
    String? equipmentId,
    String? location,
    DateTime? loginAt,
    DateTime? lastActivityAt,
    SessionActivity? activity,
  }) {
    return ActiveSession(
      id: id ?? this.id,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      program: program ?? this.program,
      equipmentName: equipmentName ?? this.equipmentName,
      equipmentId: equipmentId ?? this.equipmentId,
      location: location ?? this.location,
      loginAt: loginAt ?? this.loginAt,
      lastActivityAt: lastActivityAt ?? this.lastActivityAt,
      activity: activity ?? this.activity,
    );
  }
}

@immutable
class AppNotification {
  final String id;
  final String title;
  final String message;
  final NotificationType type;
  final DateTime timestamp;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.title,
    required this.message,
    required this.type,
    required this.timestamp,
    this.isRead = false,
  });

  AppNotification copyWith({
    String? id,
    String? title,
    String? message,
    NotificationType? type,
    DateTime? timestamp,
    bool? isRead,
  }) {
    return AppNotification(
      id: id ?? this.id,
      title: title ?? this.title,
      message: message ?? this.message,
      type: type ?? this.type,
      timestamp: timestamp ?? this.timestamp,
      isRead: isRead ?? this.isRead,
    );
  }
}

/// Which audience a log entry is meant for. The same activity feed is
/// rendered on the student home ("Recently Borrowed") and the admin
/// dashboard ("Recent Activity"), so we tag each entry with the scope it
/// belongs to and filter on the consumer side.
enum ActivityScope { student, admin }

/// A single entry in the local "activity" log. The log itself isn't
/// persisted to Supabase yet — the controller appends one of these
/// every time it performs a CRUD op (return, approve, reject, ...) so
/// the home / dashboard feeds stay in sync with whatever the user just
/// did without an extra round-trip.
@immutable
class ActivityEntry {
  const ActivityEntry({
    required this.icon,
    required this.tone,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    required this.scope,
  });

  final IconData icon;
  final Color tone;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final ActivityScope scope;
}
