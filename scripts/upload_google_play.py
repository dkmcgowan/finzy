#!/usr/bin/env python3
"""
Upload AAB to Google Play Closed Testing (alpha) via Android Publisher API.

Uses the Edits API: create edit, upload bundle, add to track release, commit.
Ensures the bundle is properly attached to the release (fixes r0adkll draft issue).

Usage: python scripts/upload_google_play.py <aab_path>
Env: GOOGLE_PLAY_SERVICE_JSON (service account JSON string)
     GOOGLE_PLAY_RELEASE_NOTES (optional, for en-US)
     GOOGLE_PLAY_RELEASE_NAME (optional, e.g. 0.1.9)
"""
import json
import os
import sys

try:
    from google.oauth2 import service_account
    from googleapiclient.discovery import build
    from googleapiclient.http import MediaFileUpload
except ImportError:
    print(
        "Install: pip install google-auth google-auth-oauthlib google-api-python-client",
        file=sys.stderr,
    )
    sys.exit(1)

SCOPES = ["https://www.googleapis.com/auth/androidpublisher"]
PACKAGE_NAME = "com.dkmcgowan.finzy"
TRACK = "alpha"  # closed testing


def main():
    aab_path = sys.argv[1] if len(sys.argv) > 1 else None
    if not aab_path or not os.path.isfile(aab_path):
        print("Usage: python upload_google_play.py <aab_path>", file=sys.stderr)
        sys.exit(1)

    key_json = os.environ.get("GOOGLE_PLAY_SERVICE_JSON")
    if not key_json:
        print("Set GOOGLE_PLAY_SERVICE_JSON secret", file=sys.stderr)
        sys.exit(1)

    try:
        key_data = json.loads(key_json)
    except json.JSONDecodeError as e:
        print(f"Invalid GOOGLE_PLAY_SERVICE_JSON: {e}", file=sys.stderr)
        sys.exit(1)

    credentials = service_account.Credentials.from_service_account_info(
        key_data, scopes=SCOPES
    )
    service = build("androidpublisher", "v3", credentials=credentials)

    # 1. Create edit
    edit = service.edits().insert(body={}, packageName=PACKAGE_NAME).execute()
    edit_id = edit["id"]
    print(f"Created edit {edit_id}")

    # 2. Upload bundle
    media = MediaFileUpload(
        aab_path,
        mimetype="application/octet-stream",
        resumable=True,
    )
    bundle = (
        service.edits()
        .bundles()
        .upload(
            editId=edit_id,
            packageName=PACKAGE_NAME,
            media_body=media,
            media_mime_type="application/octet-stream",
        )
        .execute()
    )
    version_code = bundle["versionCode"]
    print(f"Uploaded bundle, version code {version_code}")

    # 3. Add to track release (must include bundle in versionCodes)
    release_notes_text = os.environ.get("GOOGLE_PLAY_RELEASE_NOTES", "").strip()
    if not release_notes_text:
        release_notes_text = "Bug fixes and improvements."

    track_body = {
        "track": TRACK,
        "releases": [
            {
                "name": os.environ.get("GOOGLE_PLAY_RELEASE_NAME", "Release")[:50],
                "versionCodes": [str(version_code)],
                "releaseNotes": [
                    {"language": "en-US", "text": release_notes_text[:500]}
                ],
                "status": "draft",
            }
        ],
    }

    service.edits().tracks().update(
        editId=edit_id,
        packageName=PACKAGE_NAME,
        track=TRACK,
        body=track_body,
    ).execute()
    print(f"Added bundle to {TRACK} track release (draft)")

    # 4. Commit edit
    service.edits().commit(editId=edit_id, packageName=PACKAGE_NAME).execute()
    print("Committed edit - release created with bundle attached")


if __name__ == "__main__":
    main()
