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
    return snapshot.docs
        .map((doc) => _fromFirestore(doc.id, doc.data()))
        .toList();
  }

  /// Like [getAll], but scoped by [builder] (`.where(...)`) - a one-shot
  /// counterpart to [watchWhere], for the same reason: a query-constrained
  /// read is required whenever the collection's `list` rule depends on a
  /// document field (see [watchWhere]'s doc comment). Used for a single
  /// point-in-time fetch (e.g. computing a total before validating a new
  /// write) rather than an ongoing listener.
  Future<List<T>> getWhere(
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)
    builder,
  ) async {
    final snapshot = await builder(_dataSource.raw).get();
    return snapshot.docs
        .map((doc) => _fromFirestore(doc.id, doc.data()))
        .toList();
  }

  Stream<List<T>> watchAll() {
    return _dataSource.watchAll().map(
      (snapshot) => snapshot.docs
          .map((doc) => _fromFirestore(doc.id, doc.data()))
          .toList(),
    );
  }

  /// Like [watchAll], but scoped by [builder] (`.where(...)`) before
  /// Firestore evaluates the collection's `list` security rule.
  ///
  /// Needed whenever a rule's non-privileged branch depends on document
  /// fields (e.g. "only rows where teacherUid == me", "only rows where
  /// active == true"): Firestore can only verify such a rule against a
  /// query that is itself constrained to match it. An unconstrained scan
  /// filtered client-side afterward is rejected outright with
  /// `permission-denied` for that rule branch - even for a caller who
  /// could legitimately see some of the matching documents - so the
  /// query itself has to carry the same condition the rule checks (see
  /// docs/database-architecture.md).
  Stream<List<T>> watchWhere(
    Query<Map<String, dynamic>> Function(Query<Map<String, dynamic>> query)
    builder,
  ) {
    return builder(_dataSource.raw).snapshots().map(
      (snapshot) => snapshot.docs
          .map((doc) => _fromFirestore(doc.id, doc.data()))
          .toList(),
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

  /// Updates only the given [fields] on document [id], leaving every other
  /// field untouched. Use this instead of [set] when a security rule (or
  /// just good practice) restricts a write to specific fields only.
  Future<void> updateFields(String id, Map<String, dynamic> fields) {
    return _dataSource.update(id, fields);
  }

  Future<void> delete(String id) => _dataSource.delete(id);

  /// The underlying collection reference, for operations that don't fit
  /// the CRUD methods above (e.g. an atomic multi-document `WriteBatch` -
  /// see `AcademicSessionController.setActiveSession`, which flips the
  /// previously-active session off and the new one on in one commit).
  CollectionReference<Map<String, dynamic>> get collection => _dataSource.raw;
}
