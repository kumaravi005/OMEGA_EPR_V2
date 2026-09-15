import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/firestore_collections.dart';
import '../../../core/services/firebase_providers.dart';
import '../../../data/repositories/firestore_repository.dart';
import 'advertisement.dart';
import 'announcement.dart';
import 'banner_item.dart';
import 'gallery_item.dart';
import 'institute_profile.dart';
import 'upcoming_batch.dart';

final galleryRepositoryProvider = Provider<FirestoreRepository<GalleryItem>>((
  ref,
) {
  return FirestoreRepository<GalleryItem>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.gallery,
    fromFirestore: GalleryItem.fromMap,
    toFirestore: (item) => item.toMap(),
  );
});

/// Admin only - every item, active or not (for the management screen's
/// toggle). A public/anonymous caller only ever passes the `list` rule's
/// `active == true` branch, which - unlike an admin's unconditional pass
/// - Firestore can only verify against a matching query (see
/// [activeGalleryItemsProvider] and FirestoreRepository.watchWhere).
final allGalleryItemsProvider = StreamProvider<List<GalleryItem>>((ref) {
  return ref
      .watch(galleryRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

/// Public (and admin) - active items only, for the public site.
final activeGalleryItemsProvider = StreamProvider<List<GalleryItem>>((ref) {
  return ref
      .watch(galleryRepositoryProvider)
      .watchWhere((query) => query.where('active', isEqualTo: true))
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

final bannerRepositoryProvider = Provider<FirestoreRepository<BannerItem>>((
  ref,
) {
  return FirestoreRepository<BannerItem>(
    firestore: ref.watch(firestoreProvider),
    collectionPath: FirestoreCollections.banners,
    fromFirestore: BannerItem.fromMap,
    toFirestore: (item) => item.toMap(),
  );
});

int _bySortOrder(BannerItem a, BannerItem b) {
  final bySortOrder = a.sortOrder.compareTo(b.sortOrder);
  return bySortOrder != 0 ? bySortOrder : a.createdAt.compareTo(b.createdAt);
}

final allBannersProvider = StreamProvider<List<BannerItem>>((ref) {
  return ref
      .watch(bannerRepositoryProvider)
      .watchAll()
      .map((items) => items.toList()..sort(_bySortOrder));
});

/// Public (and admin) - active items only. See [activeGalleryItemsProvider].
final activeBannersProvider = StreamProvider<List<BannerItem>>((ref) {
  return ref
      .watch(bannerRepositoryProvider)
      .watchWhere((query) => query.where('active', isEqualTo: true))
      .map((items) => items.toList()..sort(_bySortOrder));
});

final upcomingBatchRepositoryProvider =
    Provider<FirestoreRepository<UpcomingBatch>>((ref) {
      return FirestoreRepository<UpcomingBatch>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.upcomingBatches,
        fromFirestore: UpcomingBatch.fromMap,
        toFirestore: (item) => item.toMap(),
      );
    });

final allUpcomingBatchesProvider = StreamProvider<List<UpcomingBatch>>((ref) {
  return ref
      .watch(upcomingBatchRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => a.startDate.compareTo(b.startDate)),
      );
});

/// Public (and admin) - active items only. See [activeGalleryItemsProvider].
final activeUpcomingBatchesProvider = StreamProvider<List<UpcomingBatch>>((
  ref,
) {
  return ref
      .watch(upcomingBatchRepositoryProvider)
      .watchWhere((query) => query.where('active', isEqualTo: true))
      .map(
        (items) =>
            items.toList()..sort((a, b) => a.startDate.compareTo(b.startDate)),
      );
});

final advertisementRepositoryProvider =
    Provider<FirestoreRepository<Advertisement>>((ref) {
      return FirestoreRepository<Advertisement>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.advertisements,
        fromFirestore: Advertisement.fromMap,
        toFirestore: (item) => item.toMap(),
      );
    });

final allAdvertisementsProvider = StreamProvider<List<Advertisement>>((ref) {
  return ref
      .watch(advertisementRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

/// Public (and admin) - active items only. See [activeGalleryItemsProvider].
final activeAdvertisementsProvider = StreamProvider<List<Advertisement>>((ref) {
  return ref
      .watch(advertisementRepositoryProvider)
      .watchWhere((query) => query.where('active', isEqualTo: true))
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

final announcementRepositoryProvider =
    Provider<FirestoreRepository<Announcement>>((ref) {
      return FirestoreRepository<Announcement>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.announcements,
        fromFirestore: Announcement.fromMap,
        toFirestore: (item) => item.toMap(),
      );
    });

final allAnnouncementsProvider = StreamProvider<List<Announcement>>((ref) {
  return ref
      .watch(announcementRepositoryProvider)
      .watchAll()
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

/// Public (and admin) - active items only. See [activeGalleryItemsProvider].
final activeAnnouncementsProvider = StreamProvider<List<Announcement>>((ref) {
  return ref
      .watch(announcementRepositoryProvider)
      .watchWhere((query) => query.where('active', isEqualTo: true))
      .map(
        (items) =>
            items.toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      );
});

final instituteProfileRepositoryProvider =
    Provider<FirestoreRepository<InstituteProfile>>((ref) {
      return FirestoreRepository<InstituteProfile>(
        firestore: ref.watch(firestoreProvider),
        collectionPath: FirestoreCollections.institutes,
        fromFirestore: InstituteProfile.fromMap,
        toFirestore: (item) => item.toMap(),
      );
    });

final instituteProfileProvider = StreamProvider<InstituteProfile?>((ref) {
  return ref
      .watch(instituteProfileRepositoryProvider)
      .watchById(InstituteProfile.documentId);
});
