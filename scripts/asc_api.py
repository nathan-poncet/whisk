#!/usr/bin/env python3
"""A small App Store Connect API client, standard library and openssl only.

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8 (path to the .p8).
Usage: asc_api.py status <bundle-id>
"""
import base64
import json
import os
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

BASE = "https://api.appstoreconnect.apple.com"


def _b64url(data: bytes) -> str:
    return base64.urlsafe_b64encode(data).rstrip(b"=").decode()


def _der_to_raw(der: bytes) -> bytes:
    """ECDSA DER SEQUENCE(INTEGER r, INTEGER s) -> 64-byte r||s."""
    assert der[0] == 0x30
    index = 2 if der[1] < 0x80 else 2 + (der[1] & 0x7F)
    parts = []
    for _ in range(2):
        assert der[index] == 0x02
        length = der[index + 1]
        value = der[index + 2 : index + 2 + length]
        parts.append(value.lstrip(b"\x00").rjust(32, b"\x00"))
        index += 2 + length
    return b"".join(parts)


def token() -> str:
    key_id = os.environ["ASC_KEY_ID"]
    issuer = os.environ["ASC_ISSUER_ID"]
    key_path = os.environ["ASC_KEY_P8"]
    now = int(time.time())
    header = _b64url(json.dumps({"alg": "ES256", "kid": key_id, "typ": "JWT"}).encode())
    payload = _b64url(
        json.dumps({"iss": issuer, "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"}).encode()
    )
    signing_input = f"{header}.{payload}".encode()
    with tempfile.NamedTemporaryFile() as message:
        message.write(signing_input)
        message.flush()
        der = subprocess.run(
            ["openssl", "dgst", "-sha256", "-sign", key_path, message.name], check=True, capture_output=True
        ).stdout
    return f"{header}.{payload}.{_b64url(_der_to_raw(der))}"


class API:
    def __init__(self) -> None:
        self._token = token()

    def request(self, method: str, path: str, body=None, params=None, raw: bytes | None = None, content_type=None):
        url = path if path.startswith("http") else BASE + path
        if params:
            url += ("&" if "?" in url else "?") + urllib.parse.urlencode(params)
        data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
        request = urllib.request.Request(url, data=data, method=method)
        request.add_header("Authorization", f"Bearer {self._token}")
        if data is not None:
            request.add_header("Content-Type", content_type or "application/json")
        try:
            with urllib.request.urlopen(request, timeout=120) as response:
                text = response.read()
                return json.loads(text) if text else {}
        except urllib.error.HTTPError as error:
            detail = error.read().decode(errors="replace")
            raise RuntimeError(f"{method} {path} -> HTTP {error.code}: {detail[:1200]}") from None

    def get(self, path, **params):
        return self.request("GET", path, params=params or None)

    def get_all(self, path, **params):
        page = self.get(path, **params)
        items = list(page.get("data", []))
        while page.get("links", {}).get("next"):
            page = self.request("GET", page["links"]["next"])
            items.extend(page.get("data", []))
        return items


def status(bundle_id: str) -> None:
    api = API()
    apps = api.get("/v1/apps", **{"filter[bundleId]": bundle_id, "fields[apps]": "name,bundleId,sku,primaryLocale,contentRightsDeclaration"})["data"]
    if not apps:
        print(f"no app with bundle id {bundle_id}")
        return
    app = apps[0]
    print(f"app {app['id']}: {app['attributes']}")
    for info in api.get(f"/v1/apps/{app['id']}/appInfos", include="primaryCategory")["data"]:
        attributes = info["attributes"]
        category = (info.get("relationships", {}).get("primaryCategory", {}).get("data") or {}).get("id")
        print(f"appInfo {info['id']}: state={attributes.get('state') or attributes.get('appStoreState')} category={category}")
        rating = (api.get(f"/v1/appInfos/{info['id']}/ageRatingDeclaration").get("data") or {}).get("attributes") or {}
        answered = sum(1 for v in rating.values() if v is not None)
        print(f"  age rating: {answered}/{len(rating)} answers")
        for loc in api.get(f"/v1/appInfos/{info['id']}/appInfoLocalizations")["data"]:
            a = loc["attributes"]
            print(f"  info localization {a['locale']}: name={a.get('name')!r} subtitle={a.get('subtitle')!r} privacy={a.get('privacyPolicyUrl')!r}")
    for version in api.get(f"/v1/apps/{app['id']}/appStoreVersions", **{"filter[platform]": "MAC_OS"})["data"]:
        a = version["attributes"]
        build = api.get(f"/v1/appStoreVersions/{version['id']}/build").get("data")
        print(f"version {version['id']}: {a.get('versionString')} state={a.get('appVersionState') or a.get('appStoreState')} "
              f"release={a.get('releaseType')} build={(build or {}).get('id')}")
        for loc in api.get(f"/v1/appStoreVersions/{version['id']}/appStoreVersionLocalizations")["data"]:
            a = loc["attributes"]
            sets = api.get(f"/v1/appStoreVersionLocalizations/{loc['id']}/appScreenshotSets", include="appScreenshots")["data"]
            shots = sum(len((s.get("relationships", {}).get("appScreenshots", {}).get("data") or [])) for s in sets)
            print(f"  version localization {a['locale']}: description={len(a.get('description') or '')} chars, "
                  f"keywords={a.get('keywords')!r}, screenshots={shots} in {[s['attributes']['screenshotDisplayType'] for s in sets]}")
        try:
            review = api.get(f"/v1/apps/{app['id']}/appPriceSchedule", include="baseTerritory").get("data")
            print(f"  price schedule: {'set' if review else 'none'}")
        except RuntimeError as error:
            print(f"  price schedule: none ({'404' in str(error) and 'not created' or str(error)[:80]})")
        try:
            review = api.get(f"/v1/appStoreVersions/{version['id']}/appStoreReviewDetail").get("data")
            print(f"  review detail: {(review or {}).get('attributes')}")
        except RuntimeError as error:
            print(f"  review detail: {error}")
    builds = api.get("/v1/builds", include="preReleaseVersion", sort="-uploadedDate", limit="5",
                     **{"filter[app]": app["id"], "fields[builds]": "version,uploadedDate,processingState,expired",
                        "fields[preReleaseVersions]": "version"})
    versions = {i["id"]: i["attributes"]["version"] for i in builds.get("included", [])}
    for build in builds["data"]:
        a = build["attributes"]
        pre = (build.get("relationships", {}).get("preReleaseVersion", {}).get("data") or {}).get("id")
        print(f"build {build['id']}: marketing={versions.get(pre)} number={a['version']} {a['processingState']} expired={a['expired']} uploaded={a['uploadedDate']}")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "status":
        status(sys.argv[2])
    else:
        print(__doc__)
        sys.exit(2)
