#!/usr/bin/env bash
# Build APK rilis memakai kredensial dari .dev.env.
# Pakai:            ./build-apk.sh                      (app SISWA)
# Ganti peran:      ENTRY=lib/main_tutor.dart ./build-apk.sh
# Hasil: build/app/outputs/flutter-apk/app-<peran>-release.apk
set -euo pipefail

cd "$(dirname "$0")"

ENV_FILE=".dev.env"
if [[ ! -f "$ENV_FILE" ]]; then
  echo "File $ENV_FILE belum ada (lihat run-dev.sh)." >&2
  exit 1
fi

# shellcheck disable=SC1090
source "$ENV_FILE"

ENTRY="${ENTRY:-lib/main_siswa.dart}"

# Flavor Android ditentukan dari entry point (siswa/tutor), kecuali diisi manual.
FLAVOR="${FLAVOR:-}"
if [[ -z "$FLAVOR" ]]; then
  case "$ENTRY" in
    *tutor*) FLAVOR="tutor" ;;
    *)       FLAVOR="siswa" ;;
  esac
fi

flutter build apk --"${MODE:-release}" --flavor "$FLAVOR" -t "$ENTRY" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
