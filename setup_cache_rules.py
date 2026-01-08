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
        if rs["phase"] == "http_request_cache_settings":
            return rs["id"]
    return None

def clear_and_add_cache_everything(zone_id, ruleset_id):
    url = f"{API}/zones/{zone_id}/rulesets/{ruleset_id}"

    payload = {
        "rules": [
            {
                "description": "Cache Everything (auto-managed)",
                "expression": "true",
                "action": "set_cache_settings",
                "action_parameters": {
                    "cache": True,
                    "browser_ttl": {
                        "mode": "override_origin",
                        "default": 86400
                    },
                    "edge_ttl": {
                        "mode": "override",
                        "default": 86400
                    }
                }
            }
        ]
    }

    r = requests.put(url, headers=HEADERS, json=payload)
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
        print("❌ Cache ruleset not found")
        continue

    status, response = clear_and_add_cache_everything(zone_id, ruleset_id)

    if status == 200:
        print("✅ Old rules removed & Cache Everything applied")
    else:
        print(f"❌ Failed ({status})")
        print(response)
