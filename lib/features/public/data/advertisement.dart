import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// What tapping an advertisement's button does. `enquiry` opens the
/// Admission enquiry form and `callback` the Request-a-callback form (both
/// already exist for the header buttons); `link` opens [Advertisement.buttonUrl].
enum AdButtonAction {
  enquiry,
  callback,
  link;

  static AdButtonAction? fromValue(String? value) {
    for (final action in values) {
      if (action.name == value) return action;
    }
    return null;
  }

  String get label => switch (this) {
    AdButtonAction.enquiry => 'Admission enquiry',
    AdButtonAction.callback => 'Request a callback',
    AdButtonAction.link => 'Open a link',
  };
}

/// A public popup advertisement. Only ever shown once per app session
/// (see AdPopup / adPopupShownProvider) - `isLive` decides whether it's
/// currently eligible to be shown at all.
class Advertisement implements FirestoreDocument {
  const Advertisement({
    required this.advertisementId,
    required this.posterUrl,
    required this.title,
    required this.description,
    required this.buttonText,
    required this.buttonUrl,
    required this.buttonAction,
    required this.active,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Advertisement.fromMap(String id, Map<String, dynamic> map) {
    return Advertisement(
      advertisementId: id,
      posterUrl: map['posterUrl'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      buttonText: map['buttonText'] as String?,
      buttonUrl: map['buttonUrl'] as String?,
      buttonAction: AdButtonAction.fromValue(map['buttonAction'] as String?),
      active: map['active'] as bool,
      startDate: (map['startDate'] as Timestamp?)?.toDate(),
      endDate: (map['endDate'] as Timestamp?)?.toDate(),
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String advertisementId;
  final String posterUrl;
  final String title;
  final String? description;
  final String? buttonText;
  final String? buttonUrl;

  /// `null` on an ad saved before this field existed - see
  /// [resolvedButtonAction].
  final AdButtonAction? buttonAction;
  final bool active;
  final DateTime? startDate;
  final DateTime? endDate;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// The action the popup button actually performs. An ad saved before
  /// [buttonAction] existed keeps its old behaviour (it opened its link if it
  /// had one) and otherwise opens the Admission enquiry form. A `link` action
  /// with no URL can't do anything, so it falls back to the enquiry form too.
  AdButtonAction get resolvedButtonAction {
    final hasUrl = buttonUrl != null && buttonUrl!.trim().isNotEmpty;
    final chosen =
        buttonAction ?? (hasUrl ? AdButtonAction.link : AdButtonAction.enquiry);
    if (chosen == AdButtonAction.link && !hasUrl) return AdButtonAction.enquiry;
    return chosen;
  }

  bool isLive(DateTime now) {
    if (!active) return false;
    if (startDate != null && now.isBefore(startDate!)) return false;
    if (endDate != null && now.isAfter(endDate!)) return false;
    return true;
  }

  @override
  String get id => advertisementId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'posterUrl': posterUrl,
      'title': title,
      'description': description,
      'buttonText': buttonText,
      'buttonUrl': buttonUrl,
      'buttonAction': buttonAction?.name,
      'active': active,
      'startDate': startDate == null ? null : Timestamp.fromDate(startDate!),
      'endDate': endDate == null ? null : Timestamp.fromDate(endDate!),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
