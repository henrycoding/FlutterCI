#!/usr/bin/env bash
set -euo pipefail

if [ "$#" -ne 1 ] || [ -z "${1:-}" ]; then
  echo "usage: $0 <url>" >&2
  exit 2
fi

: "${FEISHU_APP_ID:?FEISHU_APP_ID is required}"
: "${FEISHU_APP_SECRET:?FEISHU_APP_SECRET is required}"

target_url="$1"
tmp_dir=$(mktemp -d)
trap 'rm -rf "$tmp_dir"' EXIT
qr_path="$tmp_dir/download-qr.png"

qrencode -o "$qr_path" -s 8 -m 2 "$target_url"

token_response=$(curl --fail-with-body --silent --show-error \
  -X POST 'https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal' \
  -H 'Content-Type: application/json; charset=utf-8' \
  --data "$(jq -cn --arg app_id "$FEISHU_APP_ID" --arg app_secret "$FEISHU_APP_SECRET" \
    '{app_id: $app_id, app_secret: $app_secret}')")
tenant_access_token=$(jq -r '.tenant_access_token // empty' <<<"$token_response")
if [ -z "$tenant_access_token" ]; then
  echo "Feishu tenant access token was not returned" >&2
  exit 1
fi

upload_response=$(curl --fail-with-body --silent --show-error \
  -X POST 'https://open.feishu.cn/open-apis/im/v1/images?type=message' \
  -H "Authorization: Bearer ${tenant_access_token}" \
  -F "image_type=message" \
  -F "image=@${qr_path};type=image/png")
image_key=$(jq -r '.data.image_key // empty' <<<"$upload_response")
if [ -z "$image_key" ]; then
  echo "Feishu image upload did not return image_key" >&2
  exit 1
fi

printf '%s\n' "$image_key"
