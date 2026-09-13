import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:omega_epr_v2/features/tests/data/test_definition.dart';

void main() {
  test(
    'round-trips through toMap/fromMap, including Set 14 fields',
    () {
      final now = DateTime(2026, 4, 1);
      final test = TestDefinition(
        testId: 'test1',
        batchId: 'batch1',
        academicSessionId: 'session2026',
        classId: 'class9',
        subjectId: 'mathematics',
        subject: 'Mathematics',
        title: 'Unit Test 1',
        chapterTopic: 'Algebra',
        date: now,
        totalMarks: 50,
        testType: TestType.unitTest,
        description: 'Chapters 1-3',
        active: true,
        resultPublished: false,
        createdBy: 'admin1',
        createdAt: now,
        updatedAt: now,
      );

      final restored = TestDefinition.fromMap(test.testId, test.toMap());

      expect(restored.academicSessionId, 'session2026');
      expect(restored.classId, 'class9');
      expect(restored.subjectId, 'mathematics');
      expect(restored.subject, 'Mathematics');
      expect(restored.testType, TestType.unitTest);
      expect(restored.active, isTrue);
      expect(restored.isLinkedToMasterData, isTrue);
    },
  );

  test('"Other" test type stores and restores its custom label', () {
    final now = DateTime(2026, 4, 1);
    final test = TestDefinition(
      testId: 'test2',
      batchId: 'batch1',
      academicSessionId: 'session2026',
      classId: 'class9',
      subjectId: 'mathematics',
      subject: 'Mathematics',
      title: 'Surprise Test',
      chapterTopic: 'Algebra',
      date: now,
      totalMarks: 20,
      testType: TestType.other,
      otherTestTypeLabel: 'Surprise Test',
      description: null,
      active: true,
      resultPublished: false,
      createdBy: 'admin1',
      createdAt: now,
      updatedAt: now,
    );

    final restored = TestDefinition.fromMap(test.testId, test.toMap());

    expect(restored.testType, TestType.other);
    expect(restored.otherTestTypeLabel, 'Surprise Test');
  });

  test(
    'fromMap migrates a pre-Set-14 objective/subjective/mixed testType to '
    'Other with the original value preserved as a label, and defaults '
    'session/class/subject to empty and active to true',
    () {
      final now = Timestamp.fromDate(DateTime(2025, 1, 1));
      final restored = TestDefinition.fromMap('oldTest', {
        'batchId': 'batch1',
        'subject': 'Science',
        'title': 'Old Test',
        'chapterTopic': 'Light',
        'date': now,
        'totalMarks': 50,
        'testType': 'objective',
        'resultPublished': false,
        'createdBy': 'admin1',
        'createdAt': now,
        'updatedAt': now,
      });

      expect(restored.testType, TestType.other);
      expect(restored.otherTestTypeLabel, 'Objective');
      expect(restored.academicSessionId, '');
      expect(restored.classId, '');
      expect(restored.subjectId, '');
      expect(restored.active, isTrue);
      expect(restored.isLinkedToMasterData, isFalse);
    },
  );
}
