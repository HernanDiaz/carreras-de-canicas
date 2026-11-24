"""Activa una capacidad (por defecto iCloud) en el App ID con la API de App Store Connect.

Uso (en el workflow de iOS): python3 enable_capability.py <bundle_id> [ICLOUD]
Lee la clave de API de las variables ASC_KEY_ID, ASC_ISSUER_ID y ASC_KEY_PATH.
Si la capacidad ya está activada no hace nada.
"""
import json
import os
import sys
import time
import urllib.error
import urllib.request

import jwt  # PyJWT (pip install pyjwt cryptography)

API = "https://api.appstoreconnect.apple.com/v1"


def token():
    with open(os.environ["ASC_KEY_PATH"]) as f:
        key = f.read()
    now = int(time.time())
    payload = {"iss": os.environ["ASC_ISSUER_ID"], "iat": now, "exp": now + 600,
               "aud": "appstoreconnect-v1"}
    return jwt.encode(payload, key, algorithm="ES256", headers={"kid": os.environ["ASC_KEY_ID"]})


def call(method, path, body=None):
    request = urllib.request.Request(API + path, method=method,
                                     data=json.dumps(body).encode() if body else None)
    request.add_header("Authorization", "Bearer " + token())
    request.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(request) as response:
            data = response.read()
            return json.loads(data) if data else {}
    except urllib.error.HTTPError as error:
        raise SystemExit("%s %s -> %d %s" % (method, path, error.code, error.read().decode()))


bundle = sys.argv[1]
capability = sys.argv[2] if len(sys.argv) > 2 else "ICLOUD"
found = call("GET", "/bundleIds?filter[identifier]=%s&limit=10" % bundle)["data"]
found = [b for b in found if b["attributes"]["identifier"] == bundle]
if not found:
    raise SystemExit("No existe el App ID " + bundle)
bundle_id = found[0]["id"]
current = call("GET", "/bundleIds/%s/bundleIdCapabilities?limit=200" % bundle_id)["data"]
types = [c["attributes"]["capabilityType"] for c in current]
print("Capacidades de %s: %s" % (bundle, ", ".join(sorted(types))))
if capability in types:
    print(capability + " ya estaba activada")
    sys.exit(0)
attributes = {"capabilityType": capability}
if capability == "ICLOUD":
    attributes["settings"] = [{"key": "ICLOUD_VERSION", "options": [{"key": "XCODE_6"}]}]
call("POST", "/bundleIdCapabilities", {"data": {
    "type": "bundleIdCapabilities",
    "attributes": attributes,
    "relationships": {"bundleId": {"data": {"type": "bundleIds", "id": bundle_id}}},
}})
print(capability + " activada")
