#!/usr/bin/env bash
# Polls Firestore for task documents under users/*/tasks after app sync.
set -euo pipefail

PROJECT="${FIREBASE_PROJECT:-flowdo-fdb67}"
DATABASE="(default)"
POLL_SECONDS="${POLL_SECONDS:-120}"

echo "Checking Firestore task documents in project: $PROJECT"
echo "Polling for up to ${POLL_SECONDS}s..."

if ! command -v gcloud >/dev/null 2>&1; then
  echo "gcloud CLI not found. Open Firebase Console → Firestore → users/{uid}/tasks"
  exit 1
fi

deadline=$((SECONDS + POLL_SECONDS))
while (( SECONDS < deadline )); do
  mapfile -t docs < <(
    gcloud firestore documents list \
      --project="$PROJECT" \
      --database="$DATABASE" \
      --collection-group=tasks \
      --format='value(name)' 2>/dev/null || true
  )

  if ((${#docs[@]} > 0)); then
    echo "Found ${#docs[@]} task document(s):"
    for doc in "${docs[@]}"; do
      echo "  $doc"
      gcloud firestore documents describe "$doc" \
        --project="$PROJECT" \
        --database="$DATABASE" \
        --format='yaml(fields.title.stringValue,fields.id.integerValue,fields.createdAt.stringValue)' 2>/dev/null || true
    done
    exit 0
  fi

  sleep 5
done

echo "No task documents found within ${POLL_SECONDS}s."
echo "Sign in on the device, add a task, then re-run this script."
exit 1
