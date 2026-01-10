import requests
import concurrent.futures
import os

CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")

HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

TARGET_CNAME = "skybap.pages.dev"

def get_zone_id(domain):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain}",
        headers=HEADERS
    ).json()
    return r["result"][0]["id"] if r["success"] else None

def delete_all_dns(zone_id):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
        headers=HEADERS
    ).json()

    for record in r["result"]:
        requests.delete(
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records/{record['id']}",
            headers=HEADERS
        )

def add_cname(zone_id, domain):
    data = {
        "type": "CNAME",
        "name": "@",
        "content": TARGET_CNAME,
        "ttl": 1,
        "proxied": True
    }

    requests.post(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
        headers=HEADERS,
        json=data
    )
    print(f"✅ {domain} done")

def process_domain(domain):
    domain = domain.strip()
    zone_id = get_zone_id(domain)
    if not zone_id:
        print(f"❌ Zone not found: {domain}")
        return
    delete_all_dns(zone_id)
    add_cname(zone_id, domain)

with open("domains.txt") as f:
    domains = f.readlines()

with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
    executor.map(process_domain, domains)
