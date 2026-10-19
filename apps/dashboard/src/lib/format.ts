const WIB = 'Asia/Jakarta'

const dateOnlyFmt = new Intl.DateTimeFormat('id-ID', {
  day: '2-digit',
  month: 'short',
  year: 'numeric',
  timeZone: WIB,
})

const dateShortFmt = new Intl.DateTimeFormat('id-ID', {
  day: '2-digit',
  month: 'short',
  timeZone: WIB,
})

const dateTimeFmt = new Intl.DateTimeFormat('id-ID', {
  day: '2-digit',
  month: 'short',
  hour: '2-digit',
  minute: '2-digit',
  timeZone: WIB,
})

const timeFmt = new Intl.DateTimeFormat('id-ID', {
  hour: '2-digit',
  minute: '2-digit',
  hour12: false,
  timeZone: WIB,
})

export const rupiah = (n: number) => 'Rp' + n.toLocaleString('id-ID')

export const rupiahCompact = (n: number) =>
  n >= 1_000_000
    ? `Rp${(n / 1_000_000).toLocaleString('id-ID', { maximumFractionDigits: 2 })} jt`
    : rupiah(n)

export const formatDate = (value: string | null) =>
  value ? dateOnlyFmt.format(new Date(value)) : '—'

export const formatDateOnly = (value: string) =>
  dateOnlyFmt.format(new Date(`${value}T00:00:00+07:00`))

export const formatDateShort = (value: string) => dateShortFmt.format(new Date(value))

export const formatDateTime = (value: string) => dateTimeFmt.format(new Date(value))

export const formatTime = (value: string) => timeFmt.format(new Date(value))

export const isoDate = (d: Date) =>
  `${d.getFullYear()}-${String(d.getMonth() + 1).padStart(2, '0')}-${String(
    d.getDate(),
  ).padStart(2, '0')}`
