import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/academics/data/academic_session.dart';
import 'package:omega_epr_v2/features/academics/data/board.dart';
import 'package:omega_epr_v2/features/academics/data/school_class.dart';
import 'package:omega_epr_v2/features/academics/data/subject.dart';
import 'package:omega_epr_v2/features/public/data/institute_profile.dart';

void main() {
  test('AcademicSession round-trips through toMap/fromMap', () {
    final session = AcademicSession(
      sessionId: 's1',
      name: '2026-27',
      startDate: DateTime(2026, 4, 1),
      endDate: DateTime(2027, 3, 31),
      isActive: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = AcademicSession.fromMap(
      session.sessionId,
      session.toMap(),
    );

    expect(restored.name, '2026-27');
    expect(restored.isActive, true);
    expect(restored.startDate, DateTime(2026, 4, 1));
    expect(restored.endDate, DateTime(2027, 3, 31));
  });

  test(
    'SchoolClass round-trips through toMap/fromMap, including subjectIds',
    () {
      final schoolClass = SchoolClass(
        classId: 'class9',
        name: 'Class 9',
        sortOrder: 9,
        active: true,
        subjectIds: const [
          'hindi',
          'english',
          'physics',
          'chemistry',
          'biology',
        ],
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = SchoolClass.fromMap(
        schoolClass.classId,
        schoolClass.toMap(),
      );

      expect(restored.name, 'Class 9');
      expect(restored.sortOrder, 9);
      expect(restored.subjectIds, [
        'hindi',
        'english',
        'physics',
        'chemistry',
        'biology',
      ]);
    },
  );

  test('SchoolClass.fromMap defaults subjectIds to empty when missing', () {
    final restored = SchoolClass.fromMap('class5', {
      'name': 'Class 5',
      'sortOrder': 5,
      'active': true,
      'createdAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
      'updatedAt': Timestamp.fromDate(DateTime(2026, 1, 1)),
    });

    expect(restored.subjectIds, isEmpty);
  });

  test('Board round-trips through toMap/fromMap', () {
    final board = Board(
      boardId: 'cbse',
      name: 'CBSE',
      active: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = Board.fromMap(board.boardId, board.toMap());

    expect(restored.name, 'CBSE');
    expect(restored.active, true);
  });

  test('Subject round-trips through toMap/fromMap', () {
    final subject = Subject(
      subjectId: 'mathematics',
      name: 'Mathematics',
      active: true,
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    );

    final restored = Subject.fromMap(subject.subjectId, subject.toMap());

    expect(restored.name, 'Mathematics');
    expect(restored.active, true);
  });

  test(
    'InstituteProfile round-trips through toMap/fromMap, including the Set 9 fields',
    () {
      final profile = InstituteProfile(
        name: 'Omega Education Centre',
        tagline: 'Excellence in learning',
        about: 'A coaching institute',
        logoUrl: 'https://example.org/logo.png',
        contactPhone: '9876543210',
        secondaryPhone: '9876500000',
        contactEmail: 'contact@omega.edu',
        address: '123 Main Street',
        website: 'https://omega.edu',
        updatedAt: DateTime(2026, 1, 1),
      );

      final restored = InstituteProfile.fromMap(
        InstituteProfile.documentId,
        profile.toMap(),
      );

      expect(restored.logoUrl, 'https://example.org/logo.png');
      expect(restored.secondaryPhone, '9876500000');
      expect(restored.website, 'https://omega.edu');
      expect(restored.contactPhone, '9876543210');
    },
  );
}
