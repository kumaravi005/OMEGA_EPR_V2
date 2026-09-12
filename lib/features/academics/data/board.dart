import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// One entry in the education-board master (e.g. "CBSE", "BSEB",
/// "Others"). "Others" is not special-cased in the data model - it's
/// just a board like any other; a future student-admission screen is
/// expected to show a free-text override when the board named "Others"
/// is selected, but that wiring is out of scope for this set (see
/// docs/architecture.md's Set 9 section).
class Board implements FirestoreDocument {
  const Board({
    required this.boardId,
    required this.name,
    required this.active,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Board.fromMap(String id, Map<String, dynamic> map) {
    return Board(
      boardId: id,
      name: map['name'] as String,
      active: map['active'] as bool,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String boardId;
  final String name;
  final bool active;
  final DateTime createdAt;
  final DateTime updatedAt;

  @override
  String get id => boardId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'active': active,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
