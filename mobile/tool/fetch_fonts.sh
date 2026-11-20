#!/usr/bin/env bash
# Downloads Be Vietnam Pro (SIL Open Font License) from the official google/fonts repository.
set -euo pipefail
cd "$(dirname "$0")/../assets/fonts"
base="https://raw.githubusercontent.com/google/fonts/main/ofl/bevietnampro"
for w in Regular Medium SemiBold Bold; do
  f="BeVietnamPro-$w.ttf"
  [ -f "$f" ] || curl -fsSL -o "$f" "$base/$f"
done
[ -f OFL.txt ] || curl -fsSL -o OFL.txt "$base/OFL.txt"
echo "Fonts ready in $(pwd)"
