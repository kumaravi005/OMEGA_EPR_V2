import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum UserRole {
  admin,
  teacher,
  student;

  static UserRole fromValue(String value) {
    return UserRole.values.firstWhere(
      (role) => role.name == value,
      orElse: () => throw ArgumentError('Unknown role: $value'),
    );
  }
}

/// A device/session claim on an account. Only one may be active per
/// account at a time - this is the single-device login enforcement,
/// backed by `firestore.rules` (see docs/database-architecture.md).
class DeviceSession {
  const DeviceSession({required this.deviceId, required this.loginAt, required this.lastSeenAt});

  factory DeviceSession.fromMap(Map<String, dynamic> map) {
    return DeviceSession(
      deviceId: map['deviceId'] as String,
      loginAt: (map['loginAt'] as Timestamp).toDate(),
      lastSeenAt: (map['lastSeenAt'] as Timestamp).toDate(),
    );
  }

  final String deviceId;
  final DateTime loginAt;
  final DateTime lastSeenAt;

  Map<String, dynamic> toMap() {
    return {
      'deviceId': deviceId,
      'loginAt': Timestamp.fromDate(loginAt),
      'lastSeenAt': Timestamp.fromDate(lastSeenAt),
    };
  }
}

/// An admin/teacher/student account record.
///
/// Mirrors the `users/{uid}` Firestore document created by the
/// `createAccount` / `bootstrapFirstAdmin` Cloud Functions. `role` here is
/// for display/app-logic only - the security-authoritative copy lives in
/// the caller's ID token custom claim (see firestore.rules).
class UserAccount implements FirestoreDocument {
  const UserAccount({
    required this.uid,
    required this.accountId,
    required this.role,
    required this.displayName,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
    required this.lastLoginAt,
    required this.session,
  });

  factory UserAccount.fromMap(String id, Map<String, dynamic> map) {
    final sessionMap = map['session'] as Map<String, dynamic>?;
    final lastLoginAtTimestamp = map['lastLoginAt'] as Timestamp?;
    return UserAccount(
      uid: id,
      accountId: map['accountId'] as String,
      role: UserRole.fromValue(map['role'] as String),
      displayName: map['displayName'] as String,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
      lastLoginAt: lastLoginAtTimestamp?.toDate(),
      session: sessionMap == null ? null : DeviceSession.fromMap(sessionMap),
    );
  }

  final String uid;
  final String accountId;
  final UserRole role;
  final String displayName;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? lastLoginAt;
  final DeviceSession? session;

  @override
  String get id => uid;

  @override
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'accountId': accountId,
      'role': role.name,
      'displayName': displayName,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
      'lastLoginAt': lastLoginAt == null ? null : Timestamp.fromDate(lastLoginAt!),
      'session': session?.toMap(),
    };
  }
}
