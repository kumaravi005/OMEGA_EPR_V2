import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod providers exposing the core Firebase SDK singletons.
///
/// Services and repositories should depend on these instead of calling
/// `FirebaseAuth.instance` / `FirebaseFirestore.instance` /
/// `FirebaseStorage.instance` directly, so they can be overridden with
/// fakes in tests.
final firebaseAuthProvider = Provider<FirebaseAuth>((ref) => FirebaseAuth.instance);

final firestoreProvider = Provider<FirebaseFirestore>((ref) => FirebaseFirestore.instance);

final firebaseStorageProvider = Provider<FirebaseStorage>((ref) => FirebaseStorage.instance);
