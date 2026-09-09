import 'package:cloud_firestore/cloud_firestore.dart';
import '../datasources/firestore_datasource.dart';

typedef FromFirestore<T> = T Function(String id, Map<String, dynamic> data);
typedef ToFirestore<T> = Map<String, dynamic> Function(T value);

/// Generic Firestore-backed repository.
///
/// Future feature repositories (students, teachers, fees, attendance, ...)
/// compose this instead of re-implementing CRUD/stream boilerplate for
/// every collection — they only supply the collection path and the
/// map <-> model conversion for their own type.
class FirestoreRepository<T> {
  FirestoreRepository({
    required FirebaseFirestore firestore,
    required String collectionPath,
    required FromFirestore<T> fromFirestore,
    required ToFirestore<T> toFirestore,
  }) : _dataSource = FirestoreDataSource(firestore, collectionPath),
       // ignore: prefer_initializing_formals
       _fromFirestore = fromFirestore,
       // ignore: prefer_initializing_formals
       _toFirestore = toFirestore;

  final FirestoreDataSource _dataSource;
  final FromFirestore<T> _fromFirestore;
  final ToFirestore<T> _toFirestore;

  Future<T?> getById(String id) async {
    final snapshot = await _dataSource.fetchById(id);
    final data = snapshot.data();
    if (data == null) return null;
    return _fromFirestore(snapshot.id, data);
  }

  Future<List<T>> getAll() async {
    final snapshot = await _dataSource.fetchAll();
    return snapshot.docs.map((doc) => _fromFirestore(doc.id, doc.data())).toList();
  }

  Stream<List<T>> watchAll() {
    return _dataSource.watchAll().map(
      (snapshot) => snapshot.docs.map((doc) => _fromFirestore(doc.id, doc.data())).toList(),
    );
  }

  Stream<T?> watchById(String id) {
    return _dataSource.watchById(id).map((snapshot) {
      final data = snapshot.data();
      if (data == null) return null;
      return _fromFirestore(snapshot.id, data);
    });
  }

  /// Adds [value] under an auto-generated document id and returns it.
  Future<String> add(T value) async {
    final ref = await _dataSource.add(_toFirestore(value));
    return ref.id;
  }

  /// Writes [value] at a caller-chosen document [id].
  Future<void> set(String id, T value, {bool merge = false}) {
    return _dataSource.set(id, _toFirestore(value), merge: merge);
  }

  Future<void> delete(String id) => _dataSource.delete(id);
}
