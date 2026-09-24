#!/usr/bin/env bash
#
# Upload files to a Cloudflare R2 bucket and print a public URL and a
# markdown snippet for each one.
#
# Usage: upload.sh [--prefix <dir>] <file> [<file>...]
#
# Credentials are read from the environment, falling back to
# ~/.config/file-upload/config (a shell file with KEY=value lines):
#   R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, R2_SECRET_ACCESS_KEY, R2_BUCKET,
#   R2_PUBLIC_URL (e.g. https://files.example.com, no trailing slash)

set -euo pipefail

config="${FILE_UPLOAD_CONFIG:-$HOME/.config/file-upload/config}"
if [[ -f "$config" ]]; then
  set -a
  # shellcheck disable=SC1090
  source "$config"
  set +a
fi

for var in R2_ACCOUNT_ID R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY R2_BUCKET R2_PUBLIC_URL; do
  if [[ -z "${!var:-}" ]]; then
    echo "error: $var is not set (checked environment and $config)" >&2
    exit 1
  fi
done

slugify() {
  echo "$1" | tr '[:upper:]' '[:lower:]' | sed -E 's/[^a-z0-9._-]+/-/g; s/^[-.]+//; s/-+$//'
}

prefix=""
if [[ "${1:-}" == "--prefix" ]]; then
  prefix="$(slugify "$2")"
  shift 2
fi

if [[ $# -eq 0 ]]; then
  echo "usage: $(basename "$0") [--prefix <dir>] <file> [<file>...]" >&2
  exit 1
fi

# Group uploads by repository when run inside one.
if [[ -z "$prefix" ]] && toplevel="$(git rev-parse --show-toplevel 2>/dev/null)"; then
  prefix="$(slugify "$(basename "$toplevel")")"
fi
prefix="${prefix:-misc}"

# The macOS system curl is built against LibreSSL, which fails the TLS
# handshake with R2, so prefer the Homebrew build when it is installed.
curl_bin="$(command -v /opt/homebrew/opt/curl/bin/curl || command -v curl)"

endpoint="https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com/${R2_BUCKET}"
status=0

for file in "$@"; do
  if [[ ! -f "$file" ]]; then
    echo "error: $file does not exist" >&2
    status=1
    continue
  fi

  name="$(slugify "$(basename "$file")")"
  key="${prefix}/$(date +%Y/%m)/$(openssl rand -hex 8)-${name}"
  case "$(echo "${file##*.}" | tr '[:upper:]' '[:lower:]')" in
    png) mime="image/png" ;;
    jpg|jpeg) mime="image/jpeg" ;;
    gif) mime="image/gif" ;;
    webp) mime="image/webp" ;;
    svg) mime="image/svg+xml" ;;
    mp4) mime="video/mp4" ;;
    mov) mime="video/quicktime" ;;
    webm) mime="video/webm" ;;
    pdf) mime="application/pdf" ;;
    txt|log) mime="text/plain" ;;
    *) mime="$(file --mime-type -b "$file")" ;;
  esac

  if ! response="$("$curl_bin" --silent --show-error --fail-with-body \
    --aws-sigv4 "aws:amz:auto:s3" \
    --user "${R2_ACCESS_KEY_ID}:${R2_SECRET_ACCESS_KEY}" \
    --header "Content-Type: ${mime}" \
    --upload-file "$file" \
    "${endpoint}/${key}")"; then
    echo "error: failed to upload $file" >&2
    [[ -n "$response" ]] && echo "$response" >&2
    status=1
    continue
  fi

  url="${R2_PUBLIC_URL%/}/${key}"
  label="$(basename "$file")"
  label="${label%.*}"

  case "$mime" in
    image/*) markdown="![${label}](${url})" ;;
    *) markdown="[$(basename "$file")](${url})" ;;
  esac

  printf '%s\t%s\t%s\n' "$file" "$url" "$markdown"
done

exit $status
