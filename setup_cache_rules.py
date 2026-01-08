import requests
import os

CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")

HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

def get_zone_id(domain):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain}",
        headers=HEADERS
    ).json()
    return r["result"][0]["id"] if r["success"] else None


def create_cache_rule(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets"

    payload = {
        "name": "WP Cache Everything",
        "kind": "zone",
        "phase": "http_request_cache_settings",
        "rules": [
            {
                "expression": '(not http.request.uri.path contains "/wp-admin" and not http.request.uri.path contains "/wp-login.php")',
                "action": "set_cache_settings",
                "description": "Cache everything except admin",
                "action_parameters": {
                    "cache": True,
                    "browser_ttl": {"mode": "override", "default": 86400},
                    "edge_ttl": {"mode": "override", "default": 86400}
                }
            }
        ]
    }

    r = requests.post(url, headers=HEADERS, json=payload)
    print(f"[+] Cache rule created: {r.status_code}")


with open("domains.txt") as f:
    domains = [d.strip() for d in f if d.strip()]

for domain in domains:
    print(f"\nProcessing {domain}")
    zone_id = get_zone_id(domain)
    if not zone_id:
        print("❌ Zone not found")
        continue
    create_cache_rule(zone_id)
