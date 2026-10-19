import 'package:supabase_flutter/supabase_flutter.dart';

import '../../core/supabase_client.dart';

class GroupAttendanceRow {
  const GroupAttendanceRow({
    required this.sessionId,
    required this.classId,
    required this.seq,
    required this.scheduledAt,
    required this.jenjang,
    required this.mode,
    required this.subjectName,
    required this.studentId,
    required this.studentName,
    this.status,
  });

  final String sessionId;
  final String classId;
  final int seq;
  final DateTime scheduledAt;
  final String jenjang;
  final String mode;
  final String subjectName;
  final String studentId;
  final String studentName;
  final String? status;

  factory GroupAttendanceRow.fromMap(Map<String, dynamic> m) =>
      GroupAttendanceRow(
        sessionId: m['group_session_id'] as String,
        classId: m['group_class_id'] as String,
        seq: (m['seq'] as num).toInt(),
        scheduledAt: DateTime.parse(m['scheduled_at'] as String).toLocal(),
        jenjang: (m['jenjang'] ?? '-') as String,
        mode: (m['mode'] ?? '-') as String,
        subjectName: (m['subject_name'] ?? '-') as String,
        studentId: m['student_id'] as String,
        studentName: (m['student_name'] ?? '-') as String,
        status: m['attendance_status'] as String?,
      );
}

class GroupAttendanceRepository {
  Future<List<GroupAttendanceRow>> fetchRows() async {
    final data = await supabase
        .from('group_attendance_visible')
        .select()
        .order('scheduled_at')
        .order('student_name');
    return [for (final r in data) GroupAttendanceRow.fromMap(r)];
  }

  Future<void> mark(String sessionId, String studentId, String status) async {
    try {
      await supabase.rpc(
        'mark_group_attendance',
        params: {
          'p_session': sessionId,
          'p_student': studentId,
          'p_status': status,
        },
      );
    } on PostgrestException catch (e) {
      throw Exception(e.message);
    }
  }
}
