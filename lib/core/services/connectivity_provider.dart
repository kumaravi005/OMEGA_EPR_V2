import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether this device currently has no network connection at all - a
/// direct signal ("show connection state", Set 8), not a proxy like
/// Firestore's `snapshot.metadata.isFromCache` (which is briefly true on
/// every fresh load even while online, so it isn't a reliable "offline"
/// check on its own).
///
/// This only reports "no network interface" - it can't detect a captive
/// portal or Firestore being unreachable despite a live connection.
/// That's a deliberate scope limit: a simple, honest "you have no
/// network" banner, not a full reachability/health-check system.
final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = Connectivity();
  yield _isOffline(await connectivity.checkConnectivity());
  yield* connectivity.onConnectivityChanged.map(_isOffline);
});

bool _isOffline(List<ConnectivityResult> results) {
  return results.isEmpty ||
      results.every((result) => result == ConnectivityResult.none);
}
