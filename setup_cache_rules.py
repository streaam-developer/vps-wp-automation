#!/usr/bin/env python3

import requests
import os
import sys

API = "https://api.cloudflare.com/client/v4"

CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")

if not CF_EMAIL or not CF_API_KEY:
    print("❌ CF_EMAIL or CF_API_KEY not set. Run: source cf.env")
    sys.exit(1)

HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

def get_zone_id(domain):
    r = requests.get(f"{API}/zones?name={domain}", headers=HEADERS).json()
    if r.get("success") and r["result"]:
        return r["result"][0]["id"]
    return None

def get_cache_ruleset(zone_id):
    r = requests.get(f"{API}/zones/{zone_id}/rulesets", headers=HEADERS).json()
    if not r.get("success"):
        return None

    for rs in r["result"]:
        if rs.get("phase") == "http_request_cache_settings":
            return rs["id"]
    return None

def create_cache_ruleset(zone_id):
    r = requests.post(
        f"{API}/zones/{zone_id}/rulesets",
        headers=HEADERS,
        json={
            "name": "Auto Cache Rules",
            "kind": "zone",
            "phase": "http_request_cache_settings",
            "rules": []
        }
    )
    if r.status_code in (200, 201):
        return r.json()["result"]["id"]
    return None

def clear_and_add_cache_everything(zone_id, ruleset_id):
    r = requests.put(
        f"{API}/zones/{zone_id}/rulesets/{ruleset_id}",
        headers=HEADERS,
        json={
            "rules": [
                {
                    "description": "Bypass cache for wp-admin",
                    "expression": "http.request.uri.path contains \"/wp-admin/\"",
                    "action": "set_cache_settings",
                    "action_parameters": {
                        "cache": False
                    }
                },
                {
                    "description": "Bypass cache for logged-in users",
                    "expression": "http.cookie contains \"wordpress_logged_in\"",
                    "action": "set_cache_settings",
                    "action_parameters": {
                        "cache": False
                    }
                },
                {
                    "description": "Cache Everything (Free plan safe)",
                    "expression": "true",
                    "action": "set_cache_settings",
                    "action_parameters": {
                        "cache": True,
                        "edge_ttl": {
                            "mode": "override_origin",
                            "default": 86400
                        }
                    }
                }
            ]
        }
    )
    return r.status_code, r.text

# ===================== MAIN =====================

with open("domains.txt") as f:
    domains = [d.strip() for d in f if d.strip()]

for domain in domains:
    print(f"\n🔹 Processing {domain}")

    zone_id = get_zone_id(domain)
    if not zone_id:
        print("❌ Zone not found")
        continue

    ruleset_id = get_cache_ruleset(zone_id)
    if not ruleset_id:
        print("ℹ Cache ruleset not found — creating one")
        ruleset_id = create_cache_ruleset(zone_id)

    if not ruleset_id:
        print("❌ Failed to create cache ruleset")
        continue

    status, response = clear_and_add_cache_everything(zone_id, ruleset_id)

    if status == 200:
        print("✅ Cache Everything applied (Free plan)")
    else:
        print(f"❌ Failed ({status})")
        print(response)
