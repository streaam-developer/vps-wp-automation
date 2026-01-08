
#!/usr/bin/env python3

import requests
import os
import sys
import time

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

def zone_exists(domain):
    r = requests.get(f"{API}/zones?name={domain}", headers=HEADERS).json()
    if r.get("success") and r["result"]:
        return r["result"][0]
    return None

def add_zone(domain):
    r = requests.post(
        f"{API}/zones",
        headers=HEADERS,
        json={
            "name": domain,
            "jump_start": False
        }
    ).json()
    if r.get("success"):
        return r["result"]
    return None

def get_nameservers(zone):
    return zone.get("name_servers", [])

# ===================== MAIN =====================

with open("domains.txt") as f:
    domains = [d.strip() for d in f if d.strip()]

output = []

for domain in domains:
    print(f"\n🔹 Processing {domain}")

    zone = zone_exists(domain)
    if zone:
        print("ℹ Already exists in Cloudflare")
    else:
        print("➕ Adding domain to Cloudflare (Free plan)")
        zone = add_zone(domain)
        if not zone:
            print("❌ Failed to add domain")
            continue
        time.sleep(1)  # CF rate-limit safe

    ns = get_nameservers(zone)
    if ns:
        ns_line = f"{domain} -> {', '.join(ns)}"
        print("✅ Nameservers:", ", ".join(ns))
        output.append(ns_line)
    else:
        print("❌ Nameservers not available yet")

# Save to file
with open("cf-nameservers.txt", "w") as f:
    f.write("\n".join(output))

print("\n📄 Saved all nameservers to cf-nameservers.txt")
