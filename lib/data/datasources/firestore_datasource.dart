import 'package:cloud_firestore/cloud_firestore.dart';

/// Thin wrapper around a single Firestore collection.
///
/// Isolates raw Firestore calls (collection paths, snapshots) from the
/// repository layer above it, which is responsible for converting maps
/// to/from domain models.
class FirestoreDataSource {
  FirestoreDataSource(FirebaseFirestore firestore, String collectionPath)
    : _collection = firestore.collection(collectionPath);

  final CollectionReference<Map<String, dynamic>> _collection;

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchById(String id) {
    return _collection.doc(id).get();
  }

  Future<QuerySnapshot<Map<String, dynamic>>> fetchAll() {
    return _collection.get();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchAll() {
    return _collection.snapshots();
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchById(String id) {
    return _collection.doc(id).snapshots();
  }

  Future<DocumentReference<Map<String, dynamic>>> add(Map<String, dynamic> data) {
    return _collection.add(data);
  }

  Future<void> set(String id, Map<String, dynamic> data, {bool merge = false}) {
    return _collection.doc(id).set(data, SetOptions(merge: merge));
  }

  Future<void> update(String id, Map<String, dynamic> data) {
    return _collection.doc(id).update(data);
  }

  Future<void> delete(String id) {
    return _collection.doc(id).delete();
  }

  /// Escape hatch for queries a generic data source can't express
  /// (`where`, `orderBy`, pagination, ...).
  CollectionReference<Map<String, dynamic>> get raw => _collection;
}
