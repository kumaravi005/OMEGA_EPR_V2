import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

enum CallbackStatus {
  newRequest,
  contacted;

  static CallbackStatus fromValue(String value) {
    return CallbackStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => throw ArgumentError('Unknown callback status: $value'),
    );
  }

  String get label => this == CallbackStatus.newRequest ? 'New' : 'Contacted';
}

/// A public "call me back" request - same public-create/admin-manage
/// shape as [Enquiry], just a lighter-weight form.
class CallbackRequest implements FirestoreDocument {
  const CallbackRequest({
    required this.requestId,
    required this.name,
    required this.phone,
    required this.message,
    required this.status,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CallbackRequest.fromMap(String id, Map<String, dynamic> map) {
    return CallbackRequest(
      requestId: id,
      name: map['name'] as String,
      phone: map['phone'] as String,
      message: map['message'] as String?,
      status: CallbackStatus.fromValue(map['status'] as String),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String requestId;
  final String name;
  final String phone;
  final String? message;
  final CallbackStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => requestId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'phone': phone,
      'message': message,
      'status': status.name,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
