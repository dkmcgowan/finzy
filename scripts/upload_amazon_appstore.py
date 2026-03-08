#!/usr/bin/env python3
"""
Upload APK to Amazon Appstore via App Submission API.

Note: Amazon's App Submission API does NOT support AAB - only APK.
Uses: LWA token, create/get edit, replace APK, commit edit.

Usage: python scripts/upload_amazon_appstore.py <apk_path>
Env: AMAZON_APPSTORE_CLIENT_ID, AMAZON_APPSTORE_CLIENT_SECRET, AMAZON_APP_ID
"""
import os
import sys

try:
    import requests
except ImportError:
    print("Install requests: pip install requests", file=sys.stderr)
    sys.exit(1)

BASE_URL = "https://developer.amazon.com/api/appstore"
AUTH_URL = "https://api.amazon.com/auth/o2/token"
SCOPE = "appstore::apps:readwrite"


def get_token(client_id: str, client_secret: str) -> str:
    resp = requests.post(
        AUTH_URL,
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
            "scope": SCOPE,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
    )
    resp.raise_for_status()
    return resp.json()["access_token"]


def main():
    apk_path = sys.argv[1] if len(sys.argv) > 1 else None
    if not apk_path or not os.path.isfile(apk_path):
        print("Usage: python upload_amazon_appstore.py <apk_path>", file=sys.stderr)
        sys.exit(1)

    client_id = os.environ.get("AMAZON_APPSTORE_CLIENT_ID")
    client_secret = os.environ.get("AMAZON_APPSTORE_CLIENT_SECRET")
    app_id = os.environ.get("AMAZON_APP_ID")
    if not all([client_id, client_secret, app_id]):
        print("Set AMAZON_APPSTORE_CLIENT_ID, AMAZON_APPSTORE_CLIENT_SECRET, AMAZON_APP_ID", file=sys.stderr)
        sys.exit(1)

    token = get_token(client_id, client_secret)
    headers = {"Authorization": f"Bearer {token}"}

    # Get or create edit
    edits_url = f"{BASE_URL}/v1/applications/{app_id}/edits"
    edits_resp = requests.get(edits_url, headers=headers)
    edits_resp.raise_for_status()
    edits_data = edits_resp.json() or {}

    edit_id = edits_data.get("id")
    if not edit_id:
        # Create new edit
        create_resp = requests.post(edits_url, headers=headers)
        create_resp.raise_for_status()
        edit_id = create_resp.json()["id"]
        print(f"Created edit {edit_id}")
    else:
        print(f"Using existing edit {edit_id}")

    # List APKs to get first one for replace (or upload new)
    apks_url = f"{BASE_URL}/v1/applications/{app_id}/edits/{edit_id}/apks"
    apks_resp = requests.get(apks_url, headers=headers)
    apks_resp.raise_for_status()
    apks_list = apks_resp.json()
    if not isinstance(apks_list, list):
        apks_list = apks_list.get("apks", []) if isinstance(apks_list, dict) else []

    with open(apk_path, "rb") as f:
        apk_data = f.read()

    apk_headers = {
        **headers,
        "Content-Type": "application/vnd.android.package-archive",
    }

    if apks_list:
        # Replace existing APK
        first_apk = apks_list[0]
        apk_id = first_apk["id"]
        etag = first_apk.get("etag", "")
        replace_url = f"{apks_url}/{apk_id}/replace"
        apk_headers["If-Match"] = etag
        resp = requests.put(replace_url, headers=apk_headers, data=apk_data)
        print(f"Replaced APK {apk_id}")
    else:
        # Add new APK
        upload_url = f"{apks_url}/upload"
        resp = requests.post(upload_url, headers=apk_headers, data=apk_data)
        print("Uploaded new APK")

    resp.raise_for_status()

    # Commit edit
    commit_url = f"{BASE_URL}/v1/applications/{app_id}/edits/{edit_id}/commit"
    commit_resp = requests.post(commit_url, headers=headers)
    if commit_resp.status_code == 412:
        print("", file=sys.stderr)
        print("ERROR: App is still in Amazon review. The API cannot update apps", file=sys.stderr)
        print("while they are pending approval. Wait until the app is Live, then retry.", file=sys.stderr)
        sys.exit(1)
    commit_resp.raise_for_status()
    print("Committed edit - app submitted for review")


if __name__ == "__main__":
    main()
