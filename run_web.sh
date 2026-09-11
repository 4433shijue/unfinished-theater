#!/usr/bin/env sh
set -eu
cd "$(dirname "$0")"
command -v flutter >/dev/null 2>&1 || { echo 'Install Flutter first. See README.md.' >&2; exit 1; }
flutter pub get
exec flutter run -d web-server --web-hostname 127.0.0.1 --web-port "${PORT:-5173}"
