/// Base contract for any object persisted in a Firestore collection.
///
/// Concrete models (`Student`, `Teacher`, `FeePayment`, ...), added in
/// later phases, implement this so they can plug into
/// [FirestoreRepository] without the repository needing to know their
/// shape.
abstract class FirestoreDocument {
  String get id;

  Map<String, dynamic> toMap();
}
