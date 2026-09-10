import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Riverpod providers exposing the core Firebase SDK singletons.
///
/// Services and repositories should depend on these instead of calling
/// `FirebaseAuth.instance` / `FirebaseFirestore.instance` directly, so
/// they can be overridden with fakes in tests. No Storage provider here -
/// Firebase Storage isn't enabled on this project (see
/// docs/firebase-setup.md); every image field is a plain pasted URL.
final firebaseAuthProvider = Provider<FirebaseAuth>(
  (ref) => FirebaseAuth.instance,
);

final firestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);
