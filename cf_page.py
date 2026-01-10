import requests
import concurrent.futures
import os
import time

# ================= CONFIG =================
CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")

PAGES_PROJECT = "skybap"
TARGET_CNAME = "skybap.pages.dev"
MAX_WORKERS = 15

# ================= HEADERS =================
HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

# ================= ACCOUNT =================
def get_account_id():
    r = requests.get(
        "https://api.cloudflare.com/client/v4/accounts",
        headers=HEADERS
    ).json()

    if not r.get("success") or not r.get("result"):
        raise Exception(f"Account fetch failed: {r}")

    return r["result"][0]["id"]

ACCOUNT_ID = get_account_id()

# ================= ZONE =================
def get_zone_id(domain):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain}",
        headers=HEADERS
    ).json()

    if r.get("success") and r.get("result"):
        return r["result"][0]["id"]
    return None

# ================= DNS =================
def delete_all_dns(zone_id):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/dns_records",
        headers=HEADERS
    ).json()

    for record in r.get("result", []):
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

# ================= PAGES =================
def get_pages_domains():
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/pages/projects/{PAGES_PROJECT}/domains"
    r = requests.get(url, headers=HEADERS).json()

    if r.get("success"):
        return {d["name"]: d["id"] for d in r["result"]}
    return {}

def delete_pages_domain(domain, domain_id):
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/pages/projects/{PAGES_PROJECT}/domains/{domain_id}"
    requests.delete(url, headers=HEADERS)
    print(f"🗑 Pages domain removed: {domain}")
    time.sleep(1)

def add_domain_to_pages(domain):
    url = f"https://api.cloudflare.com/client/v4/accounts/{ACCOUNT_ID}/pages/projects/{PAGES_PROJECT}/domains"
    r = requests.post(url, headers=HEADERS, json={"name": domain}).json()

    if r.get("success"):
        print(f"🌐 Pages domain activated: {domain}")
    else:
        print(f"⚠ Pages add issue ({domain}): {r.get('errors')}")

# ================= MAIN =================
def process_domain(domain):
    domain = domain.strip()
    if not domain:
        return

    zone_id = get_zone_id(domain)
    if not zone_id:
        print(f"❌ Zone not found: {domain}")
        return

    # DNS RESET
    delete_all_dns(zone_id)
    add_cname(zone_id)

    # PAGES FIX (inactive → active)
    pages_domains = get_pages_domains()
    if domain in pages_domains:
        delete_pages_domain(domain, pages_domains[domain])

    add_domain_to_pages(domain)
    print(f"✅ DONE: {domain}")

# ================= RUN =================
if __name__ == "__main__":
    with open("domains.txt") as f:
        domains = f.readlines()

    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        executor.map(process_domain, domains)
