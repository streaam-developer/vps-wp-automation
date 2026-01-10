import requests
import concurrent.futures
import os

CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")

PAGES_PROJECT = "skybap"
TARGET_CNAME = "skybap.pages.dev"

HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

# ---------- ACCOUNT ID ----------
def get_account_id():
    r = requests.get(
        "https://api.cloudflare.com/client/v4/accounts",
        headers=HEADERS
    ).json()
    return r["result"][0]["id"]

ACCOUNT_ID = get_account_id()

# ---------- ZONE ----------
def get_zone_id(domain):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain}",
        headers=HEADERS
    ).json()
    return r["result"][0]["id"] if r["success"] and r["result"] else None

# ---------- DNS ----------
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

def add_cname(zone_id):
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

# ---------- PAGES ----------
def add_domain_to_pages(domain):
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/pages/projects/{PAGES_PROJECT}/domains"
    data = {"name": domain}

    r = requests.post(url, headers=HEADERS, json=data).json()

    if r.get("success"):
        print(f"🌐 Pages domain added: {domain}")
    else:
        print(f"⚠ Pages warning ({domain}): {r.get('errors')}")

# ---------- MAIN ----------
def process_domain(domain):
    domain = domain.strip()
    zone_id = get_zone_id(domain)

    if not zone_id:
        print(f"❌ Zone not found: {domain}")
        return

    delete_all_dns(zone_id)
    add_cname(zone_id)
    add_domain_to_pages(domain)

    print(f"✅ DONE: {domain}")

with open("domains.txt") as f:
    domains = f.readlines()

with concurrent.futures.ThreadPoolExecutor(max_workers=15) as executor:
    executor.map(process_domain, domains)
