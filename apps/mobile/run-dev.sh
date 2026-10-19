#!/usr/bin/env bash
# Jalankan app SISWA di HP dengan hot reload (perubahan UI langsung ter-reload).
#
# Pakai:   ./run-dev.sh            (pakai HP default di bawah)
#          ./run-dev.sh <device-id> (lihat id-nya dengan: flutter devices)
#
# Tombol saat jalan:  r = hot reload · R = hot restart · q = keluar
#
# Kredensial dibaca dari file .dev.env (tidak ikut masuk git).
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".dev.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "File $ENV_FILE belum ada. Buat berisi:" >&2
  echo "  SUPABASE_URL=\"https://<ref>.supabase.co\"" >&2
  echo "  SUPABASE_ANON_KEY=\"<anon key>\"" >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

if [[ -z "${SUPABASE_URL:-}" || -z "${SUPABASE_ANON_KEY:-}" ]]; then
  echo "SUPABASE_URL / SUPABASE_ANON_KEY belum diisi di $ENV_FILE." >&2
  exit 1
fi

DEVICE="${1:-${DEVICE:-e68890180406}}"
ENTRY="${ENTRY:-lib/main_siswa.dart}"

# Flavor Android ditentukan dari entry point (siswa/tutor), kecuali diisi manual.
FLAVOR="${FLAVOR:-}"
if [[ -z "$FLAVOR" ]]; then
  case "$ENTRY" in
    *tutor*) FLAVOR="tutor" ;;
    *)       FLAVOR="siswa" ;;
  esac
fi

CMD=(flutter run -d "$DEVICE" --flavor "$FLAVOR" -t "$ENTRY"
  --dart-define=SUPABASE_URL="$SUPABASE_URL"
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY")

# Uji tanpa menjalankan: DRY_RUN=1 ./run-dev.sh
if [[ "${DRY_RUN:-0}" == "1" ]]; then
  printf '%q ' "${CMD[@]}"
  echo
  exit 0
fi

exec "${CMD[@]}"
