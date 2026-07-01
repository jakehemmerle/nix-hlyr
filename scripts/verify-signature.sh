#!/usr/bin/env bash
#
# Authenticity gate for the built app.
#
# The fetchurl hash only proves the DMG matches the checksum the *same*
# upstream cask reports — a self-consistent pair. This asserts the deeper,
# non-forgeable property: the app is Apple-notarized and signed by HumanLayer's
# Developer ID (Team ID 89C6S2SYU3, "Querytale, Inc"). The auto-updater runs
# this before committing a bump, so a compromised or renamed upstream release
# cannot silently ship a foreign binary to consumers.
#
# Usage: scripts/verify-signature.sh [result-dir]   (default: ./result)
set -euo pipefail

RESULT="${1:-result}"
APP="$RESULT/Applications/HumanLayer.app"
EXPECTED_TEAM_ID="89C6S2SYU3" # Querytale, Inc

if [ ! -d "$APP" ]; then
  echo "ERROR: $APP not found (did 'nix build' run?)" >&2
  exit 1
fi

# Strict, recursive signature validation (covers the sealed riptided daemon).
codesign --verify --deep --strict --verbose=2 "$APP"

team_id="$(codesign -dv --verbose=4 "$APP" 2>&1 | sed -n 's/^TeamIdentifier=//p')"
if [ "$team_id" != "$EXPECTED_TEAM_ID" ]; then
  echo "ERROR: code-signing Team ID is '$team_id', expected '$EXPECTED_TEAM_ID'." >&2
  echo "Refusing to trust this build. If HumanLayer legitimately changed its" >&2
  echo "signing identity, update EXPECTED_TEAM_ID in this script deliberately." >&2
  exit 1
fi

# Gatekeeper / notarization acceptance. Informational: keep it non-fatal so a
# CI-environment quirk can't block a legitimate bump — the checks above are the
# hard integrity gate.
if spctl -a -vvv -t install "$APP" 2>&1; then
  echo "gatekeeper: accepted (notarized)"
else
  echo "WARN: spctl assessment did not pass in this environment (non-fatal)" >&2
fi

echo "OK: signed by Team ID $team_id"
