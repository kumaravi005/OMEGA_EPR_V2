import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../data/models/firestore_document.dart';

/// A public homepage banner/hero slide. `displayFrom`/`displayUntil` are
/// optional - when set, the banner is only considered "live" (see
/// [isLive]) within that window, on top of [active].
class BannerItem implements FirestoreDocument {
  const BannerItem({
    required this.bannerId,
    required this.imageUrl,
    required this.title,
    required this.description,
    required this.ctaText,
    required this.ctaUrl,
    required this.active,
    required this.displayFrom,
    required this.displayUntil,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BannerItem.fromMap(String id, Map<String, dynamic> map) {
    return BannerItem(
      bannerId: id,
      imageUrl: map['imageUrl'] as String,
      title: map['title'] as String,
      description: map['description'] as String?,
      ctaText: map['ctaText'] as String?,
      ctaUrl: map['ctaUrl'] as String?,
      active: map['active'] as bool,
      displayFrom: (map['displayFrom'] as Timestamp?)?.toDate(),
      displayUntil: (map['displayUntil'] as Timestamp?)?.toDate(),
      // Defaults to 0 for banners created before Set 30 added ordering,
      // so they sort first rather than failing to parse.
      sortOrder: (map['sortOrder'] as int?) ?? 0,
      createdAt: (map['createdAt'] as Timestamp).toDate(),
      updatedAt: (map['updatedAt'] as Timestamp).toDate(),
    );
  }

  final String bannerId;
  final String imageUrl;
  final String title;
  final String? description;
  final String? ctaText;
  final String? ctaUrl;
  final bool active;
  final DateTime? displayFrom;
  final DateTime? displayUntil;

  /// Admin-controlled display order on the public hero carousel (ascending
  /// - lower first). Ties (e.g. several pre-Set-30 banners defaulting to 0)
  /// fall back to [createdAt] - see `allBannersProvider`/`activeBannersProvider`.
  final int sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isLive(DateTime now) {
    if (!active) return false;
    if (displayFrom != null && now.isBefore(displayFrom!)) return false;
    if (displayUntil != null && now.isAfter(displayUntil!)) return false;
    return true;
  }

  @override
  String get id => bannerId;

  @override
  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'title': title,
      'description': description,
      'ctaText': ctaText,
      'ctaUrl': ctaUrl,
      'active': active,
      'displayFrom': displayFrom == null
          ? null
          : Timestamp.fromDate(displayFrom!),
      'displayUntil': displayUntil == null
          ? null
          : Timestamp.fromDate(displayUntil!),
      'sortOrder': sortOrder,
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': Timestamp.fromDate(updatedAt),
    };
  }
}
