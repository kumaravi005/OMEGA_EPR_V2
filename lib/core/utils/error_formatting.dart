/// Rewrites a raw exception's `toString()` (as it commonly gets
/// interpolated into an error message, e.g. `'Could not load X.\n$error'`)
/// into plain language, if it recognizes a Firebase-style
/// `[plugin/code] detail` tag anywhere in the text. Text with no such tag
/// passes through unchanged.
///
/// This exists so the ~40 screens across the app that already do
/// `ErrorView(message: 'Could not load X.\n$error')` don't each need
/// their own translation logic - [ErrorView] itself runs every message
/// through this before displaying it, so a technical exception like
/// `[cloud_firestore/permission-denied] Missing or insufficient
/// permissions.` never reaches a user as-is.
String friendlyErrorText(String rawMessage) {
  final match = _firebaseErrorPattern.firstMatch(rawMessage);
  if (match == null) return rawMessage;

  final code = match.group(2)!;
  final friendly =
      _friendlyByCode[code] ?? 'Something went wrong. Please try again.';
  return rawMessage.replaceRange(match.start, match.end, friendly);
}

final _firebaseErrorPattern = RegExp(
  r'\[([\w.]+)/([\w-]+)\]\s*.*$',
  dotAll: true,
);

const _friendlyByCode = {
  'permission-denied': "You don't have permission to view this.",
  'unauthenticated': 'Please sign in again.',
  'unavailable':
      "Couldn't reach the server - check your connection and try again.",
  'deadline-exceeded':
      'That took too long - check your connection and try again.',
  'network-request-failed':
      'Network error - check your connection and try again.',
  'not-found': 'Not found.',
  'already-exists': 'That already exists.',
  'resource-exhausted':
      'Too many requests right now - please try again shortly.',
  'cancelled': 'That was cancelled.',
  'aborted': 'That could not be completed - please try again.',
};
