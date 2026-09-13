import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/enquiries/data/enquiry.dart';

Enquiry _enquiry({
  EnquiryType enquiryType = EnquiryType.admission,
  String? classId = 'class9',
  String? className = 'Class 9',
  String? boardId = 'cbse',
  String? board = 'CBSE',
  String? boardCustomText,
  EnquiryStatus status = EnquiryStatus.newEnquiry,
}) {
  final now = DateTime(2026, 4, 1);
  return Enquiry(
    enquiryId: 'enquiry1',
    name: 'Test Student',
    guardianName: 'Test Guardian',
    enquiryType: enquiryType,
    classId: classId,
    className: className,
    boardId: boardId,
    board: board,
    boardCustomText: boardCustomText,
    primaryPhone: '9876543210',
    secondaryPhone: null,
    message: 'Please call back',
    status: status,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  test('round-trips through toMap/fromMap, including enquiryType and master-data ids', () {
    final enquiry = _enquiry();
    final restored = Enquiry.fromMap(enquiry.enquiryId, enquiry.toMap());

    expect(restored.enquiryType, EnquiryType.admission);
    expect(restored.classId, 'class9');
    expect(restored.className, 'Class 9');
    expect(restored.boardId, 'cbse');
    expect(restored.board, 'CBSE');
    expect(restored.primaryPhone, '9876543210');
    expect(restored.status, EnquiryStatus.newEnquiry);
  });

  test('a callback-type enquiry carries no class/board references', () {
    final enquiry = _enquiry(
      enquiryType: EnquiryType.callback,
      classId: null,
      className: null,
      boardId: null,
      board: null,
    );
    final restored = Enquiry.fromMap(enquiry.enquiryId, enquiry.toMap());

    expect(restored.enquiryType, EnquiryType.callback);
    expect(restored.classId, isNull);
    expect(restored.boardId, isNull);
  });

  test('enquiryType defaults to admission on a pre-Set-18 document that predates the field', () {
    final enquiry = _enquiry();
    final map = enquiry.toMap()..remove('enquiryType');
    final restored = Enquiry.fromMap(enquiry.enquiryId, map);
    expect(restored.enquiryType, EnquiryType.admission);
  });

  group('boardDisplay', () {
    test('shows the resolved board name when no custom text is set', () {
      final enquiry = _enquiry(boardId: 'cbse', board: 'CBSE');
      expect(enquiry.boardDisplay, 'CBSE');
    });

    test('shows the custom text when "Others" was selected', () {
      final enquiry = _enquiry(
        boardId: 'others',
        board: 'Others',
        boardCustomText: 'ICSE',
      );
      expect(enquiry.boardDisplay, 'ICSE');
    });

    test('is null when neither board nor custom text is set (a callback request)', () {
      final enquiry = _enquiry(boardId: null, board: null);
      expect(enquiry.boardDisplay, isNull);
    });
  });
}
