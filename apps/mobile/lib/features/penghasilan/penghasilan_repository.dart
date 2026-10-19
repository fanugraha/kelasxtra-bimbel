import '../../core/supabase_client.dart';

class PayoutItem {
  const PayoutItem({
    required this.id,
    required this.amount,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    this.bankName,
    this.transferRef,
  });

  final String id;
  final int amount;
  final String status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String? bankName;
  final String? transferRef;

  String get statusLabel => switch (status) {
    'draft' => 'Disiapkan',
    'approved' => 'Disetujui',
    'paid' => 'Sudah ditransfer',
    _ => status,
  };
}

class PenghasilanRepository {
  Future<List<PayoutItem>> fetchMyPayouts() async {
    final rows = await supabase
        .from('payouts')
        .select(
          'id, amount, status, bank_name, transfer_ref, '
          'payroll_periods(period_start, period_end)',
        )
        .order('created_at', ascending: false);
    return [
      for (final r in rows)
        PayoutItem(
          id: r['id'] as String,
          amount: (r['amount'] as num).toInt(),
          status: (r['status'] ?? '-') as String,
          bankName: r['bank_name'] as String?,
          transferRef: r['transfer_ref'] as String?,
          periodStart: DateTime.parse(
            (r['payroll_periods'] as Map)['period_start'] as String,
          ),
          periodEnd: DateTime.parse(
            (r['payroll_periods'] as Map)['period_end'] as String,
          ),
        ),
    ];
  }
}
