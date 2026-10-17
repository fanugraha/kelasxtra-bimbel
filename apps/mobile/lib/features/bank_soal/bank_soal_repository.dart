import '../../core/snap_result.dart';
import '../../core/supabase_client.dart';

/// Paket langganan bank soal.
class PlanItem {
  const PlanItem({
    required this.code,
    required this.name,
    required this.price,
    required this.periodDays,
    required this.graceDays,
  });

  final String code;
  final String name;
  final int price;
  final int periodDays;
  final int graceDays;

  factory PlanItem.fromMap(Map<String, dynamic> m) => PlanItem(
        code: m['code'] as String,
        name: (m['name'] ?? '') as String,
        price: (m['price'] as num).toInt(),
        periodDays: (m['period_days'] as num).toInt(),
        graceDays: (m['grace_days'] as num).toInt(),
      );
}

/// Langganan siswa.
class SubscriptionInfo {
  const SubscriptionInfo({
    required this.status,
    this.currentPeriodEnd,
    this.graceUntil,
  });

  final String status;
  final DateTime? currentPeriodEnd;
  final DateTime? graceUntil;

  bool get aktif => status == 'active';
  bool get tenggang => status == 'grace';
  bool get bisaLatihan => status == 'active' || status == 'grace';

  String get label => switch (status) {
        'active' => 'Aktif',
        'grace' => 'Tenggang',
        'pending' => 'Belum aktif',
        'expired' => 'Kedaluwarsa',
        'cancelled' => 'Dibatalkan',
        _ => status,
      };

  factory SubscriptionInfo.fromMap(Map<String, dynamic> m) => SubscriptionInfo(
        status: (m['status'] ?? '-') as String,
        currentPeriodEnd: m['current_period_end'] == null
            ? null
            : DateTime.parse(m['current_period_end'] as String).toLocal(),
        graceUntil: m['grace_until'] == null
            ? null
            : DateTime.parse(m['grace_until'] as String).toLocal(),
      );
}

class QuestionOption {
  const QuestionOption({required this.key, required this.text});
  final String key;
  final String text;

  factory QuestionOption.fromMap(Map<String, dynamic> m) => QuestionOption(
        key: (m['key'] ?? '') as String,
        text: (m['text'] ?? '') as String,
      );
}

/// Soal saat latihan (TANPA kunci jawaban).
class PracticeQuestion {
  const PracticeQuestion({
    required this.id,
    required this.type,
    required this.version,
    required this.body,
    this.options = const [],
    this.imagePath,
  });

  final String id;
  final String type;
  final int version;
  final String body;
  final List<QuestionOption> options;
  final String? imagePath;

  factory PracticeQuestion.fromMap(Map<String, dynamic> m) => PracticeQuestion(
        id: m['id'] as String,
        type: (m['type'] ?? 'pg') as String,
        version: (m['version'] as num?)?.toInt() ?? 1,
        body: (m['body'] ?? '') as String,
        options: ((m['options'] as List?) ?? const [])
            .map((o) => QuestionOption.fromMap(o as Map<String, dynamic>))
            .toList(),
        imagePath: m['image_url'] as String?,
      );
}

class QuestionResult {
  const QuestionResult({
    required this.questionId,
    required this.isCorrect,
    required this.correctAnswer,
    this.explanation,
  });

  final String questionId;
  final bool isCorrect;
  final String correctAnswer;
  final String? explanation;

  factory QuestionResult.fromMap(Map<String, dynamic> m) => QuestionResult(
        questionId: m['question_id'] as String,
        isCorrect: (m['is_correct'] ?? false) as bool,
        correctAnswer: (m['correct_answer'] ?? '') as String,
        explanation: m['explanation'] as String?,
      );
}

class AttemptResult {
  const AttemptResult({
    required this.attemptId,
    required this.total,
    required this.correct,
    required this.results,
  });

  final String attemptId;
  final int total;
  final int correct;
  final List<QuestionResult> results;

  factory AttemptResult.fromMap(Map<String, dynamic> m) => AttemptResult(
        attemptId: m['attempt_id'] as String,
        total: (m['total'] as num?)?.toInt() ?? 0,
        correct: (m['correct'] as num?)?.toInt() ?? 0,
        results: ((m['results'] as List?) ?? const [])
            .map((r) => QuestionResult.fromMap(r as Map<String, dynamic>))
            .toList(),
      );
}

/// Statistik akurasi per topik.
class TopicStat {
  const TopicStat({
    required this.topicName,
    required this.attemptsCount,
    required this.accuracy,
    required this.last20Correct,
    required this.last20Total,
    this.trend,
  });

  final String topicName;
  final int attemptsCount;
  final double accuracy;
  final int last20Correct;
  final int last20Total;
  final String? trend;

  String get kategori {
    if (accuracy >= 75) return 'KUAT';
    if (accuracy >= 50) return 'CUKUP';
    return 'LEMAH';
  }

  factory TopicStat.fromMap(
    Map<String, dynamic> m, {
    String? topicName,
  }) =>
      TopicStat(
        topicName: topicName ?? '-',
        attemptsCount: (m['attempts_count'] as num).toInt(),
        accuracy: (m['accuracy'] as num?)?.toDouble() ?? 0,
        last20Correct: (m['last20_correct'] as num?)?.toInt() ?? 0,
        last20Total: (m['last20_total'] as num?)?.toInt() ?? 0,
        trend: m['trend'] as String?,
      );
}

class BankSoalRepository {
  Future<PlanItem?> fetchPlan([String code = 'bank_soal']) async {
    final row = await supabase
        .from('subscription_plans')
        .select('code, name, price, period_days, grace_days')
        .eq('code', code)
        .maybeSingle();
    return row == null ? null : PlanItem.fromMap(row);
  }

  Future<SubscriptionInfo?> fetchMySubscription([String code = 'bank_soal']) async {
    final row = await supabase
        .from('subscriptions')
        .select('status, current_period_end, grace_until')
        .eq('plan_code', code)
        .maybeSingle();
    return row == null ? null : SubscriptionInfo.fromMap(row);
  }

  Future<SnapResult> createSubscriptionSnap([String code = 'bank_soal']) async {
    final res = await supabase.functions.invoke(
      'create-subscription-snap',
      body: {'plan_code': code},
    );
    final data = res.data;
    if (res.status != 200) {
      final msg = (data is Map && data['error'] != null)
          ? data['error'] as String
          : 'Gagal memulai pembayaran (${res.status})';
      throw Exception(msg);
    }
    final map = data as Map<String, dynamic>;
    return SnapResult(
      orderId: map['order_id'] as String,
      redirectUrl: map['redirect_url'] as String,
      amount: (map['amount'] as num).toInt(),
      reused: (map['reused'] ?? false) as bool,
    );
  }

  Future<List<Map<String, dynamic>>> fetchTopics() async {
    return supabase
        .from('topics')
        .select('id, name, jenjang, subjects(name)')
        .eq('active', true)
        .order('name');
  }

  /// Mulai latihan/tryout. Kunci jawaban tidak dikirim ke client.
  Future<({String attemptId, List<PracticeQuestion> questions})> startAttempt({
    required String mode,
    String? topicId,
    String? jenjang,
    int count = 10,
  }) async {
    final data = await supabase.rpc('start_attempt', params: {
      'p_mode': mode,
      'p_topic': topicId,
      'p_count': count,
      'p_jenjang': jenjang,
    });
    final map = data as Map<String, dynamic>;
    final questions = ((map['questions'] as List?) ?? const [])
        .map((q) => PracticeQuestion.fromMap(q as Map<String, dynamic>))
        .toList();
    return (attemptId: map['attempt_id'] as String, questions: questions);
  }

  Future<AttemptResult> submitAttempt({
    required String attemptId,
    required Map<String, String?> answers,
  }) async {
    final payload = answers.entries
        .map((e) => {'question_id': e.key, 'answer': e.value})
        .toList();
    final data = await supabase.rpc('submit_attempt', params: {
      'p_attempt_id': attemptId,
      'p_answers': payload,
    });
    return AttemptResult.fromMap(data as Map<String, dynamic>);
  }

  Future<List<TopicStat>> fetchMyStats() async {
    final rows = await supabase
        .from('student_topic_stats')
        .select('attempts_count, accuracy, last20_correct, last20_total, trend, '
            'topics(name)')
        .order('accuracy');
    return [
      for (final r in rows)
        TopicStat.fromMap(
          r,
          topicName: ((r['topics'] as Map?)?['name'] ?? '-') as String,
        ),
    ];
  }

  /// URL sementara untuk gambar soal (bucket privat).
  Future<String?> signedImageUrl(String path) async {
    final data = await supabase.storage.from('question-assets').createSignedUrl(path, 3600);
    return data;
  }
}
