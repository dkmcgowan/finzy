#!/usr/bin/env python3
"""
Update TestFlight Beta App Review info via App Store Connect API.

Sets BetaAppReviewDetail (demo account, notes) and BetaAppLocalization
(description, feedback email) so Beta App Review submission succeeds.

Configuration: .github/testflight-instructions.yaml
- instructions_file: path to reviewer notes (e.g. docs/TESTING_INSTRUCTIONS.txt)
- demo_account: server_url, username, no_password (true = no TESTFLIGHT_DEMO_PASSWORD needed)

Usage:
  python scripts/update_testflight_review_info.py

Env:
  APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID,
  APP_STORE_CONNECT_API_KEY_P8 (base64), APP_STORE_CONNECT_APP_ID,
  TESTFLIGHT_DEMO_PASSWORD (optional when demo_account.no_password is true),
  TESTFLIGHT_INSTRUCTIONS_PATH (optional, defaults to .github/testflight-instructions.yaml)
"""
from __future__ import annotations

import base64
import os
import sys
from pathlib import Path

try:
    import jwt
    import requests
    import yaml
except ImportError:
    print(
        "Install deps: pip install PyJWT cryptography requests PyYAML",
        file=sys.stderr,
    )
    sys.exit(1)

API_BASE = "https://api.appstoreconnect.apple.com/v1"


def load_instructions(path: str | None) -> dict:
    p = path or os.path.join(
        Path(__file__).resolve().parent.parent, ".github", "testflight-instructions.yaml"
    )
    with open(p, encoding="utf-8") as f:
        return yaml.safe_load(f)


def load_instructions_content(instructions: dict, repo_root: Path) -> str:
    """Load reviewer notes from instructions_file or build from what_to_test."""
    instructions_file = instructions.get("instructions_file")
    if instructions_file:
        full_path = repo_root / instructions_file
        if full_path.exists():
            return full_path.read_text(encoding="utf-8").strip()
    # Fallback: build from demo + what_to_test
    demo = instructions.get("demo_account", {})
    notes_parts = []
    if demo.get("server_url"):
        notes_parts.append(f"Server URL: {demo['server_url']}")
    notes_parts.append("\nHow to test:\n" + (instructions.get("what_to_test", "") or ""))
    return "\n".join(notes_parts).strip()


def make_token(key_id: str, issuer_id: str, p8_b64: str) -> str:
    import time

    payload = {
        "iss": issuer_id,
        "iat": int(time.time()),
        "exp": int(time.time()) + 20 * 60,
        "aud": "appstoreconnect-v1",
    }
    p8_pem = base64.b64decode(p8_b64).decode()
    return str(
        jwt.encode(
            payload,
            p8_pem,
            algorithm="ES256",
            headers={"kid": key_id},
        )
    )


def api_get(token: str, path: str, params: dict | None = None) -> dict:
    r = requests.get(
        f"{API_BASE}{path}",
        headers={"Authorization": f"Bearer {token}"},
        params=params or {},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def api_patch(token: str, path: str, data: dict) -> dict:
    r = requests.patch(
        f"{API_BASE}{path}",
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        },
        json={"data": data},
        timeout=30,
    )
    r.raise_for_status()
    return r.json()


def main() -> None:
    key_id = os.environ.get("APP_STORE_CONNECT_API_KEY_ID")
    issuer_id = os.environ.get("APP_STORE_CONNECT_API_ISSUER_ID")
    p8_b64 = os.environ.get("APP_STORE_CONNECT_API_KEY_P8")
    app_id = os.environ.get("APP_STORE_CONNECT_APP_ID")
    demo_password = os.environ.get("TESTFLIGHT_DEMO_PASSWORD")
    instructions_path = os.environ.get("TESTFLIGHT_INSTRUCTIONS_PATH")

    if not all([key_id, issuer_id, p8_b64, app_id]):
        print(
            "Set APP_STORE_CONNECT_API_KEY_ID, APP_STORE_CONNECT_API_ISSUER_ID, "
            "APP_STORE_CONNECT_API_KEY_P8, APP_STORE_CONNECT_APP_ID",
            file=sys.stderr,
        )
        sys.exit(1)

    instructions = load_instructions(instructions_path)
    demo = instructions.get("demo_account", {})
    no_password = demo.get("no_password", False)
    if demo.get("username") and not no_password and not demo_password:
        print(
            "Demo account requires TESTFLIGHT_DEMO_PASSWORD secret (or set no_password: true)",
            file=sys.stderr,
        )
        sys.exit(1)

    token = make_token(key_id, issuer_id, p8_b64)

    repo_root = Path(__file__).resolve().parent.parent
    notes = load_instructions_content(instructions, repo_root)

    # 1. Update BetaAppReviewDetail (demo account, notes)
    try:
        detail_resp = api_get(token, f"/apps/{app_id}/betaAppReviewDetail")
    except requests.HTTPError as e:
        if e.response.status_code == 404:
            print("BetaAppReviewDetail not found for app - skipping review detail update")
        else:
            raise
    else:
        detail_data = detail_resp.get("data")
        if detail_data:
            detail_id = detail_data["id"]
            patch_data = {
                "id": detail_id,
                "type": "betaAppReviewDetails",
                "attributes": {
                    "demoAccountRequired": True,
                    "notes": notes,
                    "contactEmail": instructions.get("feedback_email", ""),
                    "contactFirstName": "Finzy",
                    "contactLastName": "Review",
                },
                "relationships": {},
            }
            if demo.get("username"):
                patch_data["attributes"]["demoAccountName"] = demo["username"]
            if demo_password:
                patch_data["attributes"]["demoAccountPassword"] = demo_password

            api_patch(token, f"/betaAppReviewDetails/{detail_id}", patch_data)
            print("Updated BetaAppReviewDetail")
        else:
            print("No BetaAppReviewDetail data - skipping")

    # 2. Update BetaAppLocalization (description, feedback email)
    loc_resp = api_get(token, f"/apps/{app_id}/betaAppLocalizations")
    locs = loc_resp.get("data", [])
    en_us = next(
        (l for l in locs if l.get("attributes", {}).get("locale") == "en-US"),
        locs[0] if locs else None,
    )
    if en_us:
        loc_id = en_us["id"]
        patch_data = {
            "id": loc_id,
            "type": "betaAppLocalizations",
            "attributes": {
                "description": (instructions.get("beta_app_description") or "").strip(),
                "feedbackEmail": instructions.get("feedback_email", ""),
            },
            "relationships": {},
        }
        api_patch(token, f"/betaAppLocalizations/{loc_id}", patch_data)
        print("Updated BetaAppLocalization (en-US)")
    else:
        print("No BetaAppLocalization found - create one in App Store Connect first")

    print("TestFlight review info updated successfully")


if __name__ == "__main__":
    main()
