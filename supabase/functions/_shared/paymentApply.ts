// Logika penerapan status pembayaran Midtrans — satu sumber untuk
// `midtrans-webhook` (jalur cepat), `reconcile-payments` (sapuan berkala), dan
// `resolve-payment-review` (tindak lanjut manual oleh admin).
//
// Aturan utama: pelepasan tahanan slot/kursi HANYA terjadi kalau Midtrans sudah
// memutuskan transaksi mati (expire/deny/cancel). Selama belum ada keputusan,
// slot tetap ditahan sehingga pembayaran tidak mungkin masuk setelah slot lepas.

import type { createClient } from 'npm:@supabase/supabase-js@2'

type Admin = ReturnType<typeof createClient>

export type PaymentRow = {
  id: string
  order_id: string
  status: string
  booking_id: string | null
  package_purchase_id: string | null
  group_seat_id: string | null
  subscription_id: string | null
  /** Poin (Rp) yang dipakai memotong pembayaran ini; dipotong saat lunas. */
  credit_amount?: number
}

export type Outcome = {
  paid: boolean
  newStatus: string
  bookingStatus: string | null
}

export type ApplyOptions = {
  /// Jalankan langkah lanjutan walau status payment tidak berubah. Dipakai saat
  /// admin meminta proses ulang setelah aktivasi sebelumnya gagal (payment sudah
  /// `settlement`, tapi paket/kursi/langganan belum aktif).
  force?: boolean
}

/// Terjemahkan status transaksi Midtrans menjadi status payment + booking.
export function outcomeFromMidtrans(
  transactionStatus: string,
  fraudStatus?: string | null,
): Outcome {
  const paid =
    transactionStatus === 'settlement' ||
    (transactionStatus === 'capture' && fraudStatus === 'accept')

  if (paid) return { paid, newStatus: 'settlement', bookingStatus: 'confirmed' }
  if (transactionStatus === 'deny' || transactionStatus === 'cancel') {
    return { paid, newStatus: transactionStatus, bookingStatus: 'cancelled' }
  }
  if (transactionStatus === 'expire') {
    return { paid, newStatus: 'expire', bookingStatus: 'expired' }
  }
  if (transactionStatus === 'refund' || transactionStatus === 'partial_refund') {
    return { paid, newStatus: transactionStatus, bookingStatus: 'refunded' }
  }
  // pending / challenge / capture non-accept → tetap menunggu.
  return { paid, newStatus: 'pending', bookingStatus: null }
}

/// Outcome dari status payment yang sudah kita simpan. Dipakai untuk menjalankan
/// ulang langkah aktivasi tanpa menanyakan Midtrans lagi (dan tanpa risiko
/// menurunkan status pembayaran yang sudah lunas).
export function outcomeFromPaymentStatus(status: string): Outcome {
  if (status === 'settlement') return { paid: true, newStatus: 'settlement', bookingStatus: 'confirmed' }
  if (status === 'expire') return { paid: false, newStatus: 'expire', bookingStatus: 'expired' }
  if (status === 'deny' || status === 'cancel') {
    return { paid: false, newStatus: status, bookingStatus: 'cancelled' }
  }
  if (status === 'refund' || status === 'partial_refund') {
    return { paid: false, newStatus: status, bookingStatus: 'refunded' }
  }
  return { paid: false, newStatus: 'pending', bookingStatus: null }
}

/// Pembayaran yang tidak bisa diselesaikan otomatis (mis. constraint menolak
/// konfirmasi) ditandai supaya admin menindaklanjuti — bukan ditelan diam-diam.
export async function flagReview(admin: Admin, paymentId: string, note: string) {
  await admin
    .from('payments')
    .update({ review_required: true, review_note: note })
    .eq('id', paymentId)
  await admin.from('audit_logs').insert({
    actor_id: null,
    action: 'payments.review_required',
    entity: 'payments',
    entity_id: paymentId,
    after_data: { note },
  })
}

/// Terapkan hasil pembayaran. Idempoten: status payment yang sama tidak diulang,
/// kecuali `force` diminta (untuk menjalankan ulang langkah aktivasi).
export async function applyPaymentOutcome(
  admin: Admin,
  payment: PaymentRow,
  outcome: Outcome,
  raw: unknown,
  opts: ApplyOptions = {},
): Promise<{ ok: true; unchanged?: true; status: string }> {
  const { paid, newStatus } = outcome

  if (payment.status !== newStatus) {
    await admin
      .from('payments')
      .update({
        status: newStatus,
        paid_at: paid ? new Date().toISOString() : null,
        raw,
      })
      .eq('id', payment.id)
  } else if (!opts.force) {
    return { ok: true, unchanged: true, status: newStatus }
  }

  await runSideEffects(admin, payment, outcome)
  return { ok: true, status: newStatus }
}

/// Langkah lanjutan setelah status payment diketahui. Semua RPC di bawah ini
/// dijaga statusnya sendiri-sendiri sehingga aman dijalankan berulang.
async function runSideEffects(admin: Admin, payment: PaymentRow, outcome: Outcome) {
  const { paid, newStatus, bookingStatus } = outcome

  if (payment.booking_id && bookingStatus) {
    // Booking yang dipegang paket diubah lewat RPC paket, bukan di sini.
    const fromStatuses =
      newStatus === 'refund' || newStatus === 'partial_refund'
        ? ['confirmed', 'in_progress', 'completed']
        : ['pending_payment']
    const { error } = await admin
      .from('bookings')
      .update({ status: bookingStatus, lock_expires_at: null })
      .eq('id', payment.booking_id)
      .in('status', fromStatuses)
    if (error) {
      await flagReview(
        admin,
        payment.id,
        `Konfirmasi booking ${payment.booking_id} gagal: ${error.message}`,
      )
    }
  }

  // Voucher: tandai terpakai saat berhasil, lepas kuota saat gagal/kedaluwarsa/refund.
  if (payment.booking_id) {
    if (paid) {
      await admin.rpc('consume_voucher_for_booking', { p_booking_id: payment.booking_id })
    } else if (
      newStatus === 'deny' || newStatus === 'cancel' || newStatus === 'expire' ||
      newStatus === 'refund' || newStatus === 'partial_refund'
    ) {
      await admin.rpc('release_voucher_for_booking', { p_booking_id: payment.booking_id })
    }
  }

  // Paket pertemuan: kunci semua pertemuan mingguan yang sudah ditahan lalu
  // aktifkan paket (masa berlaku 1/2/3 bulan sesuai jumlah pertemuan), atau
  // lepaskan tahanannya bila pembayaran gagal.
  if (payment.package_purchase_id) {
    if (paid) {
      await admin.rpc('consume_voucher_for_package', { p_package_id: payment.package_purchase_id })
      const { error: actErr } = await admin.rpc('activate_package', {
        p_package_id: payment.package_purchase_id,
      })
      if (actErr) {
        await flagReview(
          admin,
          payment.id,
          `activate_package ${payment.package_purchase_id} gagal: ${actErr.message}`,
        )
      }
    } else if (newStatus === 'deny' || newStatus === 'cancel' || newStatus === 'expire') {
      await admin.rpc('release_voucher_for_package', { p_package_id: payment.package_purchase_id })
      const { error: cancelErr } = await admin.rpc('cancel_package_reservation', {
        p_package_id: payment.package_purchase_id,
        p_status: newStatus === 'expire' ? 'expired' : 'cancelled',
      })
      if (cancelErr) {
        await flagReview(
          admin,
          payment.id,
          `cancel_package_reservation ${payment.package_purchase_id} gagal: ${cancelErr.message}`,
        )
      }
    } else if (newStatus === 'refund' || newStatus === 'partial_refund') {
      // Paket direfund: kuota voucher kembali ke siswa.
      await admin.rpc('release_voucher_for_package', { p_package_id: payment.package_purchase_id })
      await admin
        .from('package_purchases')
        .update({ status: 'refunded' })
        .eq('id', payment.package_purchase_id)
        .eq('status', 'active')
    }
  }

  // Kursi kelas grup: aktifkan saat berhasil, lepas saat gagal/kedaluwarsa.
  if (payment.group_seat_id) {
    if (paid) {
      const { error } = await admin.rpc('activate_group_seat', { p_seat_id: payment.group_seat_id })
      if (error) {
        await flagReview(
          admin,
          payment.id,
          `activate_group_seat ${payment.group_seat_id} gagal: ${error.message}`,
        )
      }
    } else if (
      newStatus === 'deny' || newStatus === 'cancel' || newStatus === 'expire' ||
      newStatus === 'refund' || newStatus === 'partial_refund'
    ) {
      await admin.rpc('release_group_seat', { p_seat_id: payment.group_seat_id })
    }
  }

  // Langganan bank soal: aktifkan/perpanjang saat berhasil.
  // Gagal bayar tidak mengubah status (perpanjangan gagal -> langganan lama tetap berlaku).
  if (payment.subscription_id && paid) {
    const { error } = await admin.rpc('activate_subscription', {
      p_subscription_id: payment.subscription_id,
    })
    if (error) {
      await flagReview(
        admin,
        payment.id,
        `activate_subscription ${payment.subscription_id} gagal: ${error.message}`,
      )
    }
  }

  // Poin: baru dipotong saat pembayaran benar-benar lunas. `spend_credits`
  // mengunci per siswa (advisory lock) dan menolak bila saldo sudah tidak cukup.
  const credit = Math.floor(payment.credit_amount ?? 0)
  if (paid && credit > 0) {
    const studentId = await resolveStudentId(admin, payment)
    if (!studentId) {
      await flagReview(
        admin,
        payment.id,
        `Poin tidak bisa dipotong: siswa ${payment.order_id} tidak ditemukan`,
      )
    } else {
      const { error } = await admin.rpc('spend_credits', {
        p_student: studentId,
        p_amount: credit,
        p_note: `Checkout ${payment.order_id}`,
        p_package_purchase_id: payment.package_purchase_id,
        p_group_seat_id: payment.group_seat_id,
      })
      if (error) {
        await flagReview(
          admin,
          payment.id,
          `spend_credits ${payment.order_id} gagal: ${error.message}`,
        )
      }
    }
  }
}

/// Pemilik poin pada sebuah pembayaran (booking/paket/kursi).
async function resolveStudentId(
  admin: Admin,
  payment: PaymentRow,
): Promise<string | null> {
  if (payment.booking_id) {
    const { data } = await admin
      .from('bookings')
      .select('student_id')
      .eq('id', payment.booking_id)
      .maybeSingle()
    return (data?.student_id as string | undefined) ?? null
  }
  if (payment.package_purchase_id) {
    const { data } = await admin
      .from('package_purchases')
      .select('student_id')
      .eq('id', payment.package_purchase_id)
      .maybeSingle()
    return (data?.student_id as string | undefined) ?? null
  }
  if (payment.group_seat_id) {
    const { data } = await admin
      .from('group_seats')
      .select('student_id')
      .eq('id', payment.group_seat_id)
      .maybeSingle()
    return (data?.student_id as string | undefined) ?? null
  }
  return null
}
