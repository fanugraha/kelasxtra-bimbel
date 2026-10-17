#!/usr/bin/env bash
# Build APK rilis (app SISWA) memakai kredensial dari .dev.env.
# Pakai:            ./build-apk.sh
# Ganti entrypoint: ENTRY=lib/main_tutor.dart ./build-apk.sh
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

flutter build apk --release -t "$ENTRY" \
  --dart-define=SUPABASE_URL="$SUPABASE_URL" \
  --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"
