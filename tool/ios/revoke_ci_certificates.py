#!/usr/bin/env python3
"""Revokes the development certificates that CI builds leave behind.

Every iOS build runs on a fresh GitHub-hosted Mac; Xcode's automatic signing
creates a new "Apple Development" certificate there for the archive (the
TestFlight upload itself is signed with an Apple-managed distribution
certificate). Apple limits the number of certificates, so old ones are
revoked before each build. Only certificates created through the API
("Created via API" in their name) are touched – never ones made by hand.

Uses the App Store Connect API key of the workflow:
  ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_PATH (path of the .p8 file)
Needs PyJWT with cryptography (pip install "pyjwt[crypto]"). Prints only
counts, never key material.
"""

from __future__ import annotations

import json
import os
import sys
import time
import urllib.request

API = "https://api.appstoreconnect.apple.com/v1"
DEV_TYPES = ("DEVELOPMENT", "IOS_DEVELOPMENT")
MARKER = "Created via API"


def token(key_id: str, issuer_id: str, private_key: str) -> str:
    import jwt  # PyJWT

    now = int(time.time())
    return jwt.encode(
        {"iss": issuer_id, "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
        private_key, algorithm="ES256", headers={"kid": key_id, "typ": "JWT"})


def ci_certificates(certificates: list[dict]) -> list[dict]:
    """Development certificates created through the API (by CI builds)."""
    out = []
    for c in certificates:
        a = c.get("attributes", {})
        names = f"{a.get('name', '')} {a.get('displayName', '')}"
        if a.get("certificateType") in DEV_TYPES and MARKER in names:
            out.append(c)
    return out


def request(method: str, url: str, bearer: str) -> dict:
    req = urllib.request.Request(url, method=method,
                                 headers={"Authorization": f"Bearer {bearer}"})
    with urllib.request.urlopen(req, timeout=60) as r:
        body = r.read()
    return json.loads(body) if body else {}


def main() -> int:
    key_id, issuer = os.environ.get("ASC_KEY_ID"), os.environ.get("ASC_ISSUER_ID")
    path = os.environ.get("ASC_KEY_PATH")
    if not (key_id and issuer and path and os.path.exists(path)):
        print("App Store Connect key not available – nothing revoked")
        return 0
    with open(path, encoding="utf-8") as f:
        bearer = token(key_id, issuer, f.read())
    types = ",".join(DEV_TYPES)
    data = request("GET", f"{API}/certificates?filter[certificateType]={types}&limit=200",
                   bearer)
    old = ci_certificates(data.get("data", []))
    revoked = 0
    for c in old:
        try:
            request("DELETE", f"{API}/certificates/{c['id']}", bearer)
            revoked += 1
        except Exception as e:  # noqa: BLE001
            print(f"could not revoke a certificate: {getattr(e, 'code', e)}")
    print(f"revoked {revoked} of {len(old)} CI development certificates")
    return 0


if __name__ == "__main__":
    sys.exit(main())
