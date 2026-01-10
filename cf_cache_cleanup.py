import requests
import concurrent.futures
import os

# ================= CONFIG =================
CF_EMAIL = os.getenv("CF_EMAIL")
CF_API_KEY = os.getenv("CF_API_KEY")
MAX_WORKERS = 15

HEADERS = {
    "X-Auth-Email": CF_EMAIL,
    "X-Auth-Key": CF_API_KEY,
    "Content-Type": "application/json"
}

# ================= ZONE =================
def get_zone_id(domain):
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones?name={domain}",
        headers=HEADERS
    ).json()

    if r.get("success") and r.get("result"):
        return r["result"][0]["id"]
    return None

# ================= PAGE RULES =================
def delete_page_rules(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/pagerules"
    r = requests.get(url, headers=HEADERS).json()

    for rule in r.get("result", []):
        requests.delete(
            f"{url}/{rule['id']}",
            headers=HEADERS
        )

# ================= RULESETS (CACHE RULES) =================
def delete_rulesets(zone_id):
    # Get all rulesets
    r = requests.get(
        f"https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets",
        headers=HEADERS
    ).json()

    for rs in r.get("result", []):
        requests.delete(
            f"https://api.cloudflare.com/client/v4/zones/{zone_id}/rulesets/{rs['id']}",
            headers=HEADERS
        )

# ================= PURGE CACHE =================
def purge_everything(zone_id):
    url = f"https://api.cloudflare.com/client/v4/zones/{zone_id}/purge_cache"
    requests.post(url, headers=HEADERS, json={"purge_everything": True})

# ================= MAIN =================
def process_domain(domain):
    domain = domain.strip()
    if not domain:
        return

    zone_id = get_zone_id(domain)
    if not zone_id:
        print(f"❌ Zone not found: {domain}")
        return

    delete_page_rules(zone_id)
    delete_rulesets(zone_id)
    purge_everything(zone_id)

    print(f"🧹 Cache cleaned + purged: {domain}")

# ================= RUN =================
if __name__ == "__main__":
    with open("domains.txt") as f:
        domains = f.readlines()

    with concurrent.futures.ThreadPoolExecutor(max_workers=MAX_WORKERS) as executor:
        executor.map(process_domain, domains)
