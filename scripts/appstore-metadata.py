#!/usr/bin/env python3
"""Pushes the App Store listing kept in docs/app-store to App Store Connect.

    appstore-metadata.py push      texts, screenshots, category, rights, age
                                   rating, the build of the version
    appstore-metadata.py submit    sends the version to App Review

Environment: ASC_KEY_ID, ASC_ISSUER_ID, ASC_KEY_P8; optionally
ASC_CONTACT_FIRST_NAME, ASC_CONTACT_LAST_NAME, ASC_CONTACT_PHONE,
ASC_CONTACT_EMAIL for the App Review contact.
"""
import hashlib
import json
import os
import pathlib
import sys
import urllib.request

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from asc_api import API  # noqa: E402

ROOT = pathlib.Path(__file__).resolve().parent.parent
META = json.loads((ROOT / "docs/app-store/metadata.json").read_text())
PLATFORM = "MAC_OS"


def data(type_, id_=None, attributes=None, relationships=None):
    item = {"type": type_}
    if id_:
        item["id"] = id_
    if attributes:
        item["attributes"] = attributes
    if relationships:
        item["relationships"] = {k: {"data": v} for k, v in relationships.items()}
    return {"data": item}


def find_app(api):
    apps = api.get("/v1/apps", **{"filter[bundleId]": META["bundleId"]})["data"]
    if not apps:
        sys.exit(f"no App Store Connect record for {META['bundleId']}")
    return apps[0]


def find_version(api, app_id):
    versions = api.get(f"/v1/apps/{app_id}/appStoreVersions", **{"filter[platform]": PLATFORM})["data"]
    editable = [v for v in versions if (v["attributes"].get("appVersionState") or v["attributes"].get("appStoreState"))
                in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "INVALID_BINARY")]
    if not editable:
        sys.exit("no editable App Store version; create the next version in App Store Connect first")
    return editable[0]


def find_build(api, app_id, version_string):
    page = api.get("/v1/builds", include="preReleaseVersion", sort="-uploadedDate", limit="20",
                   **{"filter[app]": app_id, "filter[processingState]": "VALID", "filter[expired]": "false",
                      "fields[preReleaseVersions]": "version"})
    marketing = {i["id"]: i["attributes"]["version"] for i in page.get("included", [])}
    for build in page["data"]:
        pre = (build["relationships"].get("preReleaseVersion", {}).get("data") or {}).get("id")
        if marketing.get(pre) == version_string:
            return build
    return None


def upsert_localization(api, path_list, path_create, type_, parent_type, parent_id, locale, attributes):
    existing = {l["attributes"]["locale"]: l for l in api.get(path_list)["data"]}
    if locale in existing:
        api.request("PATCH", f"/v1/{type_}/{existing[locale]['id']}", data(type_, existing[locale]["id"], attributes))
        return existing[locale]["id"]
    created = api.request("POST", path_create, data(type_, attributes={"locale": locale, **attributes},
                                                    relationships={parent_type: {"type": parent_type + "s", "id": parent_id}}))
    return created["data"]["id"]


def upload_screenshots(api, localization_id, display_type, folder):
    files = sorted(p for p in (ROOT / folder).iterdir() if p.suffix.lower() in (".png", ".jpg", ".jpeg"))
    sets = api.get(f"/v1/appStoreVersionLocalizations/{localization_id}/appScreenshotSets", include="appScreenshots",
                   **{"fields[appScreenshots]": "fileName,assetDeliveryState"})["data"]
    the_set = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
    if the_set is None:
        the_set = api.request("POST", "/v1/appScreenshotSets", data(
            "appScreenshotSets", attributes={"screenshotDisplayType": display_type},
            relationships={"appStoreVersionLocalization": {"type": "appStoreVersionLocalizations", "id": localization_id}}))["data"]
        present = set()
    else:
        present = {s["attributes"]["fileName"] for s in api.get(f"/v1/appScreenshotSets/{the_set['id']}/appScreenshots")["data"]}
    uploaded = 0
    for file in files:
        if file.name in present:
            continue
        payload = file.read_bytes()
        reservation = api.request("POST", "/v1/appScreenshots", data(
            "appScreenshots", attributes={"fileName": file.name, "fileSize": len(payload)},
            relationships={"appScreenshotSet": {"type": "appScreenshotSets", "id": the_set["id"]}}))["data"]
        for op in reservation["attributes"]["uploadOperations"]:
            chunk = payload[op["offset"]: op["offset"] + op["length"]]
            request = urllib.request.Request(op["url"], data=chunk, method=op["method"])
            for header in op.get("requestHeaders", []):
                request.add_header(header["name"], header["value"])
            urllib.request.urlopen(request, timeout=300).read()
        api.request("PATCH", f"/v1/appScreenshots/{reservation['id']}", data(
            "appScreenshots", reservation["id"], {"uploaded": True, "sourceFileChecksum": hashlib.md5(payload).hexdigest()}))
        uploaded += 1
    return uploaded, len(files)


LEVEL_FIELDS = {"alcoholTobaccoOrDrugUseOrReferences", "contests", "gamblingSimulated", "gunsOrOtherWeapons",
                "horrorOrFearThemes", "matureOrSuggestiveThemes", "medicalOrTreatmentInformation",
                "profanityOrCrudeHumor", "sexualContentGraphicAndNudity", "sexualContentOrNudity",
                "violenceCartoonOrFantasy", "violenceRealistic", "violenceRealisticProlongedGraphicOrSadistic"}
BOOL_FIELDS = {"advertising", "gambling", "lootBox", "messagingAndChat", "parentalControls",
               "unrestrictedWebAccess", "healthOrWellnessTopics", "ageAssurance"}


def declare_age_rating(api, info_id):
    """Every question answered with none or no: a clipboard manager has no
    content of its own. The questionnaire grows over time, so the answers
    follow the attributes the declaration actually carries; a value the
    API refuses is flipped between its two shapes and tried again."""
    rating = api.get(f"/v1/appInfos/{info_id}/ageRatingDeclaration").get("data")
    if not rating:
        print("age rating: no declaration to fill")
        return
    attributes = {}
    for key in rating["attributes"]:
        # The URL is optional, and the legacy override may not be sent next
        # to its V2.
        if key in ("developerAgeRatingInfoUrl", "ageRatingOverride"):
            continue
        if key in LEVEL_FIELDS or "Override" in key:
            attributes[key] = "NONE"
        elif key == "kidsAgeBand":
            attributes[key] = None
        else:
            attributes[key] = False
    for _ in range(4):
        try:
            api.request("PATCH", f"/v1/ageRatingDeclarations/{rating['id']}",
                        data("ageRatingDeclarations", rating["id"], attributes))
            print("age rating -> none of the categories")
            return
        except RuntimeError as error:
            message = str(error)
            flipped = False
            for key in list(attributes):
                if f"/data/attributes/{key}" in message and ("INVALID" in message or "TYPE" in message):
                    attributes[key] = "NONE" if attributes[key] is False else False
                    flipped = True
            if not flipped:
                print(f"age rating: left for the web form ({message[:300]})")
                return
    print("age rating: left for the web form (values not accepted)")


def ensure_free_price(api, app_id):
    try:
        api.get(f"/v1/apps/{app_id}/appPriceSchedule")
        print("price: schedule already set")
        return
    except RuntimeError as error:
        if "404" not in str(error):
            print(f"price: {str(error)[:200]}")
            return
    points = api.get(f"/v1/apps/{app_id}/appPricePoints", **{"filter[territory]": "USA", "limit": "5"})["data"]
    free = next((p for p in points if float(p["attributes"]["customerPrice"]) == 0), None)
    if not free:
        print("price: no free price point found, set it in App Store Connect")
        return
    body = {"data": {"type": "appPriceSchedules", "relationships": {
                "app": {"data": {"type": "apps", "id": app_id}},
                "baseTerritory": {"data": {"type": "territories", "id": "USA"}},
                "manualPrices": {"data": [{"type": "appPrices", "id": "${free}"}]}}},
            "included": [{"type": "appPrices", "id": "${free}", "attributes": {"startDate": None},
                          "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": free["id"]}}}}]}
    try:
        api.request("POST", "/v1/appPriceSchedules", body)
        print("price -> free, every territory")
    except RuntimeError as error:
        print(f"price: left for the web form ({str(error)[:300]})")


def push():
    api = API()
    app = find_app(api)
    app_id = app["id"]
    version = find_version(api, app_id)
    version_id = version["id"]
    print(f"app {app_id}, version {version['attributes'].get('versionString')} ({version_id})")

    if version["attributes"].get("versionString") != META["version"]:
        api.request("PATCH", f"/v1/appStoreVersions/{version_id}",
                    data("appStoreVersions", version_id, {"versionString": META["version"]}))
        print(f"version string -> {META['version']}")

    if app["attributes"].get("contentRightsDeclaration") != META["contentRightsDeclaration"]:
        api.request("PATCH", f"/v1/apps/{app_id}", data("apps", app_id, {"contentRightsDeclaration": META["contentRightsDeclaration"]}))
        print(f"content rights -> {META['contentRightsDeclaration']}")

    infos = api.get(f"/v1/apps/{app_id}/appInfos")["data"]
    info = next((i for i in infos if (i["attributes"].get("state") or i["attributes"].get("appStoreState")) != "READY_FOR_DISTRIBUTION"), infos[0])
    api.request("PATCH", f"/v1/appInfos/{info['id']}", {"data": {"type": "appInfos", "id": info["id"], "relationships": {
        "primaryCategory": {"data": {"type": "appCategories", "id": META["primaryCategory"]}}}}})
    print(f"category -> {META['primaryCategory']}")

    for locale, texts in META["localizations"].items():
        upsert_localization(api, f"/v1/appInfos/{info['id']}/appInfoLocalizations", "/v1/appInfoLocalizations",
                            "appInfoLocalizations", "appInfo", info["id"], locale,
                            {"name": texts["name"], "subtitle": texts["subtitle"], "privacyPolicyUrl": META["privacyPolicyUrl"]})
        version_fields = {"description": texts["description"], "keywords": texts["keywords"],
                          "promotionalText": texts["promotionalText"], "supportUrl": META["supportUrl"],
                          "marketingUrl": META["marketingUrl"]}
        localization_id = upsert_localization(api, f"/v1/appStoreVersions/{version_id}/appStoreVersionLocalizations",
                                              "/v1/appStoreVersionLocalizations", "appStoreVersionLocalizations",
                                              "appStoreVersion", version_id, locale, version_fields)
        print(f"{locale}: texts written")
        for display_type, folder in META["screenshots"].items():
            uploaded, total = upload_screenshots(api, localization_id, display_type, folder)
            print(f"{locale}: screenshots {display_type}: {uploaded} uploaded, {total} in the set")

    declare_age_rating(api, info["id"])
    ensure_free_price(api, app_id)

    build = find_build(api, app_id, META["version"])
    if build:
        api.request("PATCH", f"/v1/appStoreVersions/{version_id}/relationships/build", {"data": {"type": "builds", "id": build["id"]}})
        print(f"build -> {META['version']} ({build['attributes']['version']})")
    else:
        print(f"build {META['version']}: none processed yet, attach it later")

    contact = {k: os.environ.get(f"ASC_CONTACT_{k.upper()}") for k in ("first_name", "last_name", "phone", "email")}
    if all(contact.values()):
        attributes = {"contactFirstName": contact["first_name"], "contactLastName": contact["last_name"],
                      "contactPhone": contact["phone"], "contactEmail": contact["email"],
                      "demoAccountRequired": False, "notes": META["reviewNotes"]}
        detail = api.get(f"/v1/appStoreVersions/{version_id}/appStoreReviewDetail").get("data")
        if detail:
            api.request("PATCH", f"/v1/appStoreReviewDetails/{detail['id']}", data("appStoreReviewDetails", detail["id"], attributes))
        else:
            api.request("POST", "/v1/appStoreReviewDetails", data("appStoreReviewDetails", attributes=attributes,
                        relationships={"appStoreVersion": {"type": "appStoreVersions", "id": version_id}}))
        print("review contact and notes written")
    else:
        print("review contact: set ASC_CONTACT_FIRST_NAME/LAST_NAME/PHONE/EMAIL to write it, or fill it in App Store Connect")


def submit():
    api = API()
    app = find_app(api)
    version = find_version(api, app["id"])
    submission = api.request("POST", "/v1/reviewSubmissions", data(
        "reviewSubmissions", attributes={"platform": PLATFORM}, relationships={"app": {"type": "apps", "id": app["id"]}}))["data"]
    api.request("POST", "/v1/reviewSubmissionItems", data(
        "reviewSubmissionItems", relationships={"reviewSubmission": {"type": "reviewSubmissions", "id": submission["id"]},
                                                "appStoreVersion": {"type": "appStoreVersions", "id": version["id"]}}))
    api.request("PATCH", f"/v1/reviewSubmissions/{submission['id']}", data("reviewSubmissions", submission["id"], {"submitted": True}))
    print(f"submitted {version['attributes'].get('versionString')} for review (submission {submission['id']})")


if __name__ == "__main__":
    command = sys.argv[1] if len(sys.argv) > 1 else ""
    if command == "push":
        push()
    elif command == "submit":
        submit()
    else:
        print(__doc__)
        sys.exit(2)
