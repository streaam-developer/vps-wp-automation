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


def purge_all(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache"
    r = requests.post(url, headers=HEADERS, json={"purge_everything": True})
    return r.status_code


with open("domains.txt") as f:
    domains = [d.strip() for d in f if d.strip()]

for domain in domains:
    print(f"Purging {domain}")
    zone_id = get_zone_id(domain)
    if not zone_id:
        print("❌ Zone not found")
        continue
    status = purge_all(zone_id)
    print(f"✅ Purged ({status})")
