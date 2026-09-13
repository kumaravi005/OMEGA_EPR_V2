import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/notices/data/notice.dart';

Notice _notice({
  NoticeType type = NoticeType.general,
  NoticeStatus status = NoticeStatus.published,
  NoticeAudience audience = NoticeAudience.all,
  NoticeScope scope = NoticeScope.institute,
  String? classId,
  String? batchId,
  DateTime? expiresAt,
  bool isPublic = false,
}) {
  final now = DateTime(2026, 4, 1);
  return Notice(
    noticeId: 'notice1',
    title: 'Holiday notice',
    message: 'School will remain closed on Friday.',
    type: type,
    audience: audience,
    scope: scope,
    classId: classId,
    batchId: batchId,
    targetKey: Notice.computeTargetKey(
      audience: audience,
      scope: scope,
      classId: classId,
      batchId: batchId,
    ),
    status: status,
    createdBy: 'admin1',
    createdAt: now,
    updatedAt: now,
    publishedAt: status == NoticeStatus.draft ? null : now,
    expiresAt: expiresAt,
    isPublic: isPublic,
  );
}

void main() {
  test('round-trips through toMap/fromMap, including type/audience/scope', () {
    final notice = _notice(
      type: NoticeType.fee,
      audience: NoticeAudience.students,
      scope: NoticeScope.byBatch,
      classId: 'class9',
      batchId: 'batch1',
    );
    final restored = Notice.fromMap(notice.noticeId, notice.toMap());

    expect(restored.type, NoticeType.fee);
    expect(restored.audience, NoticeAudience.students);
    expect(restored.scope, NoticeScope.byBatch);
    expect(restored.classId, 'class9');
    expect(restored.batchId, 'batch1');
    expect(restored.targetKey, 'students:batch:batch1');
    expect(restored.status, NoticeStatus.published);
  });

  test('otherTypeLabel and optional fields survive as null when absent', () {
    final notice = _notice();
    final restored = Notice.fromMap(notice.noticeId, notice.toMap());
    expect(restored.otherTypeLabel, isNull);
    expect(restored.academicSessionId, isNull);
    expect(restored.classId, isNull);
    expect(restored.batchId, isNull);
    expect(restored.expiresAt, isNull);
  });

  group('computeTargetKey', () {
    test('all audience always resolves to "all", regardless of scope', () {
      expect(
        Notice.computeTargetKey(audience: NoticeAudience.all, scope: NoticeScope.institute),
        'all',
      );
    });

    test('teachers audience always resolves to "teachers"', () {
      expect(
        Notice.computeTargetKey(audience: NoticeAudience.teachers, scope: NoticeScope.institute),
        'teachers',
      );
    });

    test('students and parents produce the identical key at institute scope', () {
      final studentsKey = Notice.computeTargetKey(
        audience: NoticeAudience.students,
        scope: NoticeScope.institute,
      );
      final parentsKey = Notice.computeTargetKey(
        audience: NoticeAudience.parents,
        scope: NoticeScope.institute,
      );
      expect(studentsKey, 'students');
      expect(parentsKey, 'students');
    });

    test('students and parents produce the identical key at class scope', () {
      final studentsKey = Notice.computeTargetKey(
        audience: NoticeAudience.students,
        scope: NoticeScope.byClass,
        classId: 'class9',
      );
      final parentsKey = Notice.computeTargetKey(
        audience: NoticeAudience.parents,
        scope: NoticeScope.byClass,
        classId: 'class9',
      );
      expect(studentsKey, 'students:class:class9');
      expect(parentsKey, 'students:class:class9');
    });

    test('batch scope encodes the batch id, not the class id', () {
      expect(
        Notice.computeTargetKey(
          audience: NoticeAudience.students,
          scope: NoticeScope.byBatch,
          classId: 'class9',
          batchId: 'batchA',
        ),
        'students:batch:batchA',
      );
    });

    test('different classes produce different keys', () {
      final class9 = Notice.computeTargetKey(
        audience: NoticeAudience.students,
        scope: NoticeScope.byClass,
        classId: 'class9',
      );
      final class10 = Notice.computeTargetKey(
        audience: NoticeAudience.students,
        scope: NoticeScope.byClass,
        classId: 'class10',
      );
      expect(class9, isNot(class10));
    });
  });

  group('isExpired', () {
    test('no expiry never expires', () {
      final notice = _notice();
      expect(notice.isExpired(DateTime(2099, 1, 1)), isFalse);
    });

    test('is expired once the current time is after expiresAt', () {
      final notice = _notice(expiresAt: DateTime(2026, 1, 10));
      expect(notice.isExpired(DateTime(2026, 1, 11)), isTrue);
      expect(notice.isExpired(DateTime(2026, 1, 5)), isFalse);
    });

    test('expiry is never persisted as a boolean', () {
      final notice = _notice(expiresAt: DateTime(2026, 1, 10));
      expect(notice.toMap().containsKey('isExpired'), isFalse);
      expect(notice.toMap().containsKey('expired'), isFalse);
    });
  });

  group('isPublic (Set 18)', () {
    test('defaults to false', () {
      final notice = _notice();
      expect(notice.isPublic, isFalse);
    });

    test('round-trips through toMap/fromMap when true', () {
      final notice = _notice(isPublic: true);
      final restored = Notice.fromMap(notice.noticeId, notice.toMap());
      expect(restored.isPublic, isTrue);
    });

    test('defaults to false on a pre-Set-18 document that predates the field', () {
      final notice = _notice();
      final map = notice.toMap()..remove('isPublic');
      final restored = Notice.fromMap(notice.noticeId, map);
      expect(restored.isPublic, isFalse);
    });

    test('is independent of audience/scope/targetKey - a class-scoped notice can still be public', () {
      final notice = _notice(
        audience: NoticeAudience.students,
        scope: NoticeScope.byClass,
        classId: 'class9',
        isPublic: true,
      );
      expect(notice.isPublic, isTrue);
      expect(notice.targetKey, 'students:class:class9');
    });
  });
}
