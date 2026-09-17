import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/notification_hook.dart';
import '../data/advertisement.dart';
import '../data/announcement.dart';
import '../data/banner_item.dart';
import '../data/course.dart';
import '../data/gallery_item.dart';
import '../data/institute_profile.dart';
import '../data/public_content_repositories.dart';
import '../data/upcoming_batch.dart';

/// A clean, user-facing reason a public-content admin action failed.
class PublicContentFailure implements Exception {
  const PublicContentFailure(this.message);

  final String message;

  @override
  String toString() => message;
}

final publicContentControllerProvider = Provider<PublicContentController>(
  (ref) => PublicContentController(ref),
);

/// Admin CRUD for every simple public-content type (gallery, banners,
/// upcoming batches, advertisements, announcements, institute profile).
/// They share no business logic beyond "write it, stamp the timestamps,
/// translate failures" - see docs/architecture.md for why this is one
/// controller instead of six near-identical ones.
class PublicContentController {
  PublicContentController(this._ref);

  final Ref _ref;

  Future<void> saveGalleryItem({
    GalleryItem? existing,
    required String imageUrl,
    required String title,
    required String? description,
    required String? category,
    required bool active,
  }) async {
    final now = DateTime.now();
    final id = existing?.itemId ?? '';
    final item = GalleryItem(
      itemId: id,
      imageUrl: imageUrl.trim(),
      title: title.trim(),
      description: _blankToNull(description),
      category: _blankToNull(category),
      active: active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        await _ref.read(galleryRepositoryProvider).add(item);
      } else {
        await _ref.read(galleryRepositoryProvider).set(existing.itemId, item);
      }
    });
  }

  Future<void> setGalleryActive(GalleryItem item, bool active) => _run(
    () => _ref.read(galleryRepositoryProvider).updateFields(item.itemId, {
      'active': active,
      'updatedAt': Timestamp.now(),
    }),
  );

  Future<void> saveBanner({
    BannerItem? existing,
    required String imageUrl,
    required String title,
    required String? description,
    required String? ctaText,
    required String? ctaUrl,
    required bool active,
    required DateTime? displayFrom,
    required DateTime? displayUntil,
    required int sortOrder,
  }) async {
    final now = DateTime.now();
    final banner = BannerItem(
      bannerId: existing?.bannerId ?? '',
      imageUrl: imageUrl.trim(),
      title: title.trim(),
      description: _blankToNull(description),
      ctaText: _blankToNull(ctaText),
      ctaUrl: _blankToNull(ctaUrl),
      active: active,
      displayFrom: displayFrom,
      displayUntil: displayUntil,
      sortOrder: existing?.sortOrder ?? sortOrder,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        await _ref.read(bannerRepositoryProvider).add(banner);
      } else {
        await _ref
            .read(bannerRepositoryProvider)
            .set(existing.bannerId, banner);
      }
    });
  }

  Future<void> setBannerActive(BannerItem item, bool active) => _run(
    () => _ref.read(bannerRepositoryProvider).updateFields(item.bannerId, {
      'active': active,
      'updatedAt': Timestamp.now(),
    }),
  );

  /// Persists a new display order for every banner in [orderedBanners] (its
  /// index becomes the new `sortOrder`) in one atomic batch, so the public
  /// carousel never briefly shows a partially-reordered list.
  Future<void> reorderBanners(List<BannerItem> orderedBanners) => _run(() async {
    final collection = _ref.read(bannerRepositoryProvider).collection;
    final batch = collection.firestore.batch();
    final now = Timestamp.now();
    for (var i = 0; i < orderedBanners.length; i++) {
      batch.update(collection.doc(orderedBanners[i].bannerId), {
        'sortOrder': i,
        'updatedAt': now,
      });
    }
    await batch.commit();
  });

  Future<void> saveCourse({
    Course? existing,
    required String title,
    required String? description,
    required String? imageUrl,
    required String? trackTag,
    required List<String> subjectChips,
    required String? syllabusUrl,
    required bool active,
    required int sortOrder,
  }) async {
    final now = DateTime.now();
    final course = Course(
      courseId: existing?.courseId ?? '',
      title: title.trim(),
      description: _blankToNull(description),
      imageUrl: _blankToNull(imageUrl),
      trackTag: _blankToNull(trackTag),
      subjectChips: subjectChips
          .map((s) => s.trim())
          .where((s) => s.isNotEmpty)
          .toList(),
      syllabusUrl: _blankToNull(syllabusUrl),
      active: active,
      sortOrder: existing?.sortOrder ?? sortOrder,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        await _ref.read(courseRepositoryProvider).add(course);
      } else {
        await _ref
            .read(courseRepositoryProvider)
            .set(existing.courseId, course);
      }
    });
  }

  Future<void> setCourseActive(Course item, bool active) => _run(
    () => _ref.read(courseRepositoryProvider).updateFields(item.courseId, {
      'active': active,
      'updatedAt': Timestamp.now(),
    }),
  );

  /// See [reorderBanners] - same atomic-batch reorder pattern.
  Future<void> reorderCourses(List<Course> orderedCourses) => _run(() async {
    final collection = _ref.read(courseRepositoryProvider).collection;
    final batch = collection.firestore.batch();
    final now = Timestamp.now();
    for (var i = 0; i < orderedCourses.length; i++) {
      batch.update(collection.doc(orderedCourses[i].courseId), {
        'sortOrder': i,
        'updatedAt': now,
      });
    }
    await batch.commit();
  });

  Future<void> saveUpcomingBatch({
    UpcomingBatch? existing,
    required String? posterUrl,
    required String title,
    required String className,
    required String board,
    required String academicSession,
    required DateTime startDate,
    required String timing,
    required String? description,
    required String admissionStatus,
    required bool active,
  }) async {
    final now = DateTime.now();
    final batch = UpcomingBatch(
      upcomingBatchId: existing?.upcomingBatchId ?? '',
      posterUrl: _blankToNull(posterUrl),
      title: title.trim(),
      className: className.trim(),
      board: board.trim(),
      academicSession: academicSession.trim(),
      startDate: startDate,
      timing: timing.trim(),
      description: _blankToNull(description),
      admissionStatus: admissionStatus.trim(),
      active: active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        await _ref.read(upcomingBatchRepositoryProvider).add(batch);
      } else {
        await _ref
            .read(upcomingBatchRepositoryProvider)
            .set(existing.upcomingBatchId, batch);
      }
    });
  }

  Future<void> setUpcomingBatchActive(UpcomingBatch item, bool active) => _run(
    () => _ref.read(upcomingBatchRepositoryProvider).updateFields(
      item.upcomingBatchId,
      {'active': active, 'updatedAt': Timestamp.now()},
    ),
  );

  Future<void> saveAdvertisement({
    Advertisement? existing,
    required String posterUrl,
    required String title,
    required String? description,
    required String? buttonText,
    required String? buttonUrl,
    required bool active,
    required DateTime? startDate,
    required DateTime? endDate,
  }) async {
    final now = DateTime.now();
    final ad = Advertisement(
      advertisementId: existing?.advertisementId ?? '',
      posterUrl: posterUrl.trim(),
      title: title.trim(),
      description: _blankToNull(description),
      buttonText: _blankToNull(buttonText),
      buttonUrl: _blankToNull(buttonUrl),
      active: active,
      startDate: startDate,
      endDate: endDate,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        await _ref.read(advertisementRepositoryProvider).add(ad);
      } else {
        await _ref
            .read(advertisementRepositoryProvider)
            .set(existing.advertisementId, ad);
      }
    });
  }

  Future<void> setAdvertisementActive(Advertisement item, bool active) => _run(
    () => _ref.read(advertisementRepositoryProvider).updateFields(
      item.advertisementId,
      {'active': active, 'updatedAt': Timestamp.now()},
    ),
  );

  Future<void> saveAnnouncement({
    Announcement? existing,
    required String title,
    required String body,
    required bool active,
  }) async {
    final now = DateTime.now();
    final announcement = Announcement(
      announcementId: existing?.announcementId ?? '',
      title: title.trim(),
      body: body.trim(),
      active: active,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    await _run(() async {
      if (existing == null) {
        final id = await _ref
            .read(announcementRepositoryProvider)
            .add(announcement);
        await recordAnnouncementNotification(
          _ref,
          title: announcement.title,
          body: announcement.body,
          relatedId: id,
        );
      } else {
        await _ref
            .read(announcementRepositoryProvider)
            .set(existing.announcementId, announcement);
      }
    });
  }

  Future<void> setAnnouncementActive(Announcement item, bool active) => _run(
    () => _ref.read(announcementRepositoryProvider).updateFields(
      item.announcementId,
      {'active': active, 'updatedAt': Timestamp.now()},
    ),
  );

  Future<void> saveInstituteProfile({
    required String name,
    required String? tagline,
    required String? about,
    required String? logoUrl,
    required String? contactPhone,
    required String? secondaryPhone,
    required String? contactEmail,
    required String? address,
    required String? website,
  }) => _run(
    () => _ref
        .read(instituteProfileRepositoryProvider)
        .set(
          InstituteProfile.documentId,
          InstituteProfile(
            name: name.trim(),
            tagline: _blankToNull(tagline),
            about: _blankToNull(about),
            logoUrl: _blankToNull(logoUrl),
            contactPhone: _blankToNull(contactPhone),
            secondaryPhone: _blankToNull(secondaryPhone),
            contactEmail: _blankToNull(contactEmail),
            address: _blankToNull(address),
            website: _blankToNull(website),
            updatedAt: DateTime.now(),
          ),
        ),
  );

  String? _blankToNull(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();

  Future<void> _run(Future<void> Function() action) async {
    try {
      await action();
    } catch (_) {
      throw const PublicContentFailure('Could not save. Please try again.');
    }
  }
}
