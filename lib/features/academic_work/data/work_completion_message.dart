import '../../../core/utils/date_key.dart';
import 'academic_work.dart';
import 'work_completion.dart';

/// The standard message a student sees for a completion status, in both
/// English and Hindi (one fixed wording per status, so every student gets
/// the same clear message - a teacher's own words go in the optional
/// remark, appended at the end).
class WorkCompletionMessage {
  const WorkCompletionMessage({required this.english, required this.hindi});

  final String english;
  final String hindi;
}

const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _readableDate(DateTime date) =>
    '${date.day} ${_months[date.month - 1]} ${date.year}';

String _typeHindi(AcademicWorkType type) =>
    type == AcademicWorkType.homework ? 'होमवर्क' : 'असाइनमेंट';

WorkCompletionMessage buildWorkCompletionMessage({
  required WorkCompletionStatus status,
  required AcademicWorkType type,
  required String title,
  required String subject,
  required DateTime dueDate,
  required DateTime now,
  String? remark,
}) {
  final typeEn = type.label;
  final typeHi = _typeHindi(type);
  final due = _readableDate(dueDate);
  final pastDue = dateOnly(now).isAfter(dateOnly(dueDate));

  var english = switch (status) {
    WorkCompletionStatus.completed =>
      'Well done! Your $typeEn "$title" ($subject) has been marked as '
          'completed.',
    WorkCompletionStatus.incomplete =>
      pastDue
          ? 'Your $typeEn "$title" ($subject) is incomplete. The due date '
                '($due) has passed - please complete it and show it to your '
                'teacher as soon as possible.'
          : 'Your $typeEn "$title" ($subject) is incomplete. Please '
                'complete it by $due.',
    WorkCompletionStatus.notCompleted =>
      'Your $typeEn "$title" ($subject) was not completed. Please complete '
          'it and submit it to your teacher.',
  };

  var hindi = switch (status) {
    WorkCompletionStatus.completed =>
      'शाबाश! आपका $typeHi "$title" ($subject) पूरा हो गया है।',
    WorkCompletionStatus.incomplete =>
      pastDue
          ? 'आपका $typeHi "$title" ($subject) अधूरा है। जमा करने की तारीख '
                '($due) निकल चुकी है - कृपया इसे जल्द से जल्द पूरा करके अपने '
                'शिक्षक को दिखाएँ।'
          : 'आपका $typeHi "$title" ($subject) अधूरा है। कृपया इसे $due तक '
                'पूरा करें।',
    WorkCompletionStatus.notCompleted =>
      'आपका $typeHi "$title" ($subject) पूरा नहीं हुआ है। कृपया इसे पूरा '
          'करके अपने शिक्षक को जमा करें।',
  };

  final trimmedRemark = remark?.trim();
  if (trimmedRemark != null && trimmedRemark.isNotEmpty) {
    english = "$english\nTeacher's remark: $trimmedRemark";
    hindi = '$hindi\nशिक्षक की टिप्पणी: $trimmedRemark';
  }

  return WorkCompletionMessage(english: english, hindi: hindi);
}
