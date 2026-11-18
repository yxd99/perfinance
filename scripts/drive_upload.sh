#!/usr/bin/env bash
# Replace the content of an EXISTING Google Drive file, keeping its ID,
# share link and permissions (the parent folder is never touched).
#
# Usage: scripts/drive_upload.sh <file_id> <local_path> <drive_name> <mime_type>
# Env:   GDRIVE_CLIENT_ID, GDRIVE_CLIENT_SECRET, GDRIVE_REFRESH_TOKEN
set -euo pipefail

file_id="$1"
local_path="$2"
drive_name="$3"
mime_type="$4"

: "${GDRIVE_CLIENT_ID:?missing}" "${GDRIVE_CLIENT_SECRET:?missing}" "${GDRIVE_REFRESH_TOKEN:?missing}"

access_token=$(
  curl -fsS https://oauth2.googleapis.com/token \
    --data-urlencode "client_id=${GDRIVE_CLIENT_ID}" \
    --data-urlencode "client_secret=${GDRIVE_CLIENT_SECRET}" \
    --data-urlencode "refresh_token=${GDRIVE_REFRESH_TOKEN}" \
    --data-urlencode "grant_type=refresh_token" |
    jq -r '.access_token'
)
if [[ -z "$access_token" || "$access_token" == "null" ]]; then
  echo "Could not obtain a Google access token" >&2
  exit 1
fi

# Resumable upload: simple uploads are capped at 5 MB and the APK is bigger.
metadata=$(jq -nc --arg name "$drive_name" '{name: $name}')
session_url=$(
  curl -fsS -X PATCH \
    "https://www.googleapis.com/upload/drive/v3/files/${file_id}?uploadType=resumable" \
    -H "Authorization: Bearer ${access_token}" \
    -H "Content-Type: application/json; charset=UTF-8" \
    -H "X-Upload-Content-Type: ${mime_type}" \
    -d "$metadata" -D - -o /dev/null |
    tr -d '\r' | awk 'tolower($1) == "location:" { print $2 }'
)
if [[ -z "$session_url" ]]; then
  echo "Drive did not return an upload session for ${file_id}" >&2
  exit 1
fi

curl -fsS -X PUT "$session_url" \
  -H "Content-Type: ${mime_type}" \
  --data-binary "@${local_path}" \
  -o /dev/null

echo "Uploaded ${local_path} to Drive as ${drive_name}"
