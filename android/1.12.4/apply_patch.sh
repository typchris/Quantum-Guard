#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <base-1.12.3.apk> <apktool-3.0.3.jar> <output-unsigned.apk>"
  exit 2
fi

BASE="$1"
APKTOOL="$2"
OUT="$3"
ROOT="$(cd "$(dirname "$0")" && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

EXPECTED="0cc9a20fda41d017c464ee66f3bce285378b02af2663ed51b9af4f1fc4ff0c4c"
ACTUAL="$(sha256sum "$BASE" | awk '{print $1}')"
if [ "$ACTUAL" != "$EXPECTED" ]; then
  echo "Unexpected base APK SHA-256: $ACTUAL"
  exit 1
fi

java -jar "$APKTOOL" d -f "$BASE" -o "$WORK/decoded"
base64 -d "$ROOT/qg-1.12.4-smali.patch.xz.b64" | xz -d > "$WORK/fix.patch"
patch -d "$WORK/decoded" -p1 < "$WORK/fix.patch"
java -Xmx2g -jar "$APKTOOL" b "$WORK/decoded" -o "$OUT"

echo "Built unsigned APK: $OUT"
echo "Sign it with the authorized Quantum Guard signing identity before distribution."
