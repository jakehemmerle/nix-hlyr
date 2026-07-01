#!/usr/bin/env bash
#
# Regenerate pkgs/humanlayer/source.json from the upstream Homebrew cask.
#
# The `humanlayer` cask in humanlayer/homebrew-humanlayer is maintained by
# HumanLayer's own release pipeline, so it is an always-current source of
# truth for {version, url, sha256}. We just mirror it and convert the hex
# checksum to the SRI form Nix wants.
#
# Prints a final line of either `changed` or `unchanged` for CI to branch on.
set -euo pipefail

cd "$(dirname "$0")/.."

CASK_URL="https://raw.githubusercontent.com/humanlayer/homebrew-humanlayer/main/Casks/humanlayer.rb"
SRC_JSON="pkgs/humanlayer/source.json"

cask="$(curl -fsSL --retry 3 --retry-delay 2 "$CASK_URL")"

# Pull the first `<keyword> "<value>"` stanza out of the cask.
stanza() {
  printf '%s\n' "$cask" \
    | grep -oE "^[[:space:]]*$1 \"[^\"]+\"" \
    | head -1 \
    | sed -E "s/^[[:space:]]*$1 \"(.*)\"$/\1/"
}

version="$(stanza version)"
sha_hex="$(stanza sha256)"
url="$(stanza url)"

if [ -z "$version" ] || [ -z "$sha_hex" ] || [ -z "$url" ]; then
  echo "ERROR: could not parse version/sha256/url from cask" >&2
  printf '%s\n' "$cask" >&2
  exit 1
fi

# Sanity-check the parsed values so a cask-format change (e.g. Ruby string
# interpolation like `riptide-v#{version}`, or a `:no_check` checksum) fails
# here with a clear message instead of producing a broken source.json.
case "$url" in
  https://*) ;;
  *)
    echo "ERROR: url is not a plain https URL (cask format changed?): $url" >&2
    exit 1
    ;;
esac
if printf '%s' "$version$sha_hex$url" | grep -q '#{'; then
  echo "ERROR: cask uses Ruby interpolation this parser cannot resolve: $url" >&2
  exit 1
fi
if ! printf '%s' "$sha_hex" | grep -qE '^[0-9a-f]{64}$'; then
  echo "ERROR: sha256 is not a 64-char hex digest: $sha_hex" >&2
  exit 1
fi

# Homebrew publishes a hex sha256; Nix fetchers want SRI (sha256-<base64>).
sri="$(nix hash convert --hash-algo sha256 --to sri "$sha_hex")"

new="$(jq -n \
  --arg version "$version" \
  --arg url "$url" \
  --arg sha256 "$sri" \
  '{version: $version, url: $url, sha256: $sha256}')"

old="$(cat "$SRC_JSON" 2>/dev/null || echo '{}')"

if [ "$(jq -S . <<<"$new")" = "$(jq -S . <<<"$old")" ]; then
  echo "already at version $version"
  echo "unchanged"
else
  printf '%s\n' "$new" >"$SRC_JSON"
  echo "updated to version $version"
  echo "changed"
fi
