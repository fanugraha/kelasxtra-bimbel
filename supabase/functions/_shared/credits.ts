// Bantuan pemakaian poin (student_credits) di Edge Function checkout.
//
// Poin dipotong setelah pembayaran lunas (lihat paymentApply.ts), jadi di sini
// hanya: baca saldo, hitung berapa poin yang bisa dipakai, dan (untuk pembelian
// yang tertutup penuh oleh poin) jalankan penerapan pembayaran tanpa Midtrans.

import type { createClient } from 'npm:@supabase/supabase-js@2'

type Admin = ReturnType<typeof createClient>

/** Saldo poin siswa (1 poin = Rp1). 0 bila gagal dibaca. */
export async function readCreditBalance(
  admin: Admin,
  studentId: string,
): Promise<number> {
  const { data, error } = await admin.rpc('student_credit_balance', {
    p_student: studentId,
  })
  if (error) return 0
  return Number(data ?? 0)
}

/** Poin yang dipakai: sebanyak mungkin, maksimal sebesar tagihan. */
export function creditPlan(balance: number, base: number): number {
  if (balance <= 0 || base <= 0) return 0
  return Math.min(Math.floor(balance), Math.floor(base))
}

/** Penanda transaksi lunas penuh lewat poin (tanpa Midtrans). */
export const CREDIT_METHOD = 'credits'
