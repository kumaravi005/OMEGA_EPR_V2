import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/notices/application/notice_controller.dart';
import 'package:omega_epr_v2/features/notices/data/notice.dart';

void main() {
  group('NoticeController.create validation', () {
    late ProviderContainer container;

    setUp(() => container = ProviderContainer());
    tearDown(() => container.dispose());

    test('rejects an empty title', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: '   ',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.all,
          scope: NoticeScope.institute,
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('Title')),
        ),
      );
    });

    test('rejects an empty message', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: '  ',
          type: NoticeType.general,
          audience: NoticeAudience.all,
          scope: NoticeScope.institute,
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('Message')),
        ),
      );
    });

    test('rejects creating a notice that is already closed', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.all,
          scope: NoticeScope.institute,
          status: NoticeStatus.closed,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('already closed')),
        ),
      );
    });

    test('rejects type "other" without a label', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.other,
          audience: NoticeAudience.all,
          scope: NoticeScope.institute,
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('Other')),
        ),
      );
    });

    test('rejects a class-scoped notice without a class selected', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.students,
          scope: NoticeScope.byClass,
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('class')),
        ),
      );
    });

    test('rejects a batch-scoped notice without a batch selected', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.parents,
          scope: NoticeScope.byBatch,
          classId: 'class9',
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having((f) => f.message, 'message', contains('batch')),
        ),
      );
    });

    test('rejects a class/batch scope for the "all" audience', () {
      final controller = container.read(noticeControllerProvider);
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.all,
          scope: NoticeScope.byClass,
          classId: 'class9',
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having(
            (f) => f.message,
            'message',
            contains('institute-wide'),
          ),
        ),
      );
    });

    test('a well-formed students/class notice passes validation up to the auth check', () {
      final controller = container.read(noticeControllerProvider);
      // Every validation rule passes here - the only remaining failure (in
      // this bare container, with no signed-in admin) is the "please sign
      // in again" check, proving none of the earlier rules rejected it.
      expect(
        () => controller.create(
          title: 'Title',
          message: 'Body',
          type: NoticeType.general,
          audience: NoticeAudience.students,
          scope: NoticeScope.byClass,
          classId: 'class9',
          status: NoticeStatus.published,
        ),
        throwsA(
          isA<NoticeFailure>().having(
            (f) => f.message,
            'message',
            contains('sign in'),
          ),
        ),
      );
    });
  });
}
