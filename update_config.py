#!/usr/bin/env python3
import json
import re
import random
import os
import requests
import base64

# ------------------- 🔑 PRIVATE REPO ACCESS (classic token) -------------------
# Recommended: set GITHUB_TOKEN in your environment instead of hardcoding
GITHUB_TOKEN = os.getenv("GITHUB_TOKEN", "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")
REPO = "streaam-developer/central-config-repo"
FILE_PATH = "config.json"
BRANCH = "main"

REMOTE_ENV_URL = f"https://api.github.com/repos/{REPO}/contents/{FILE_PATH}?ref={BRANCH}"

headers = {"Authorization": f"token {GITHUB_TOKEN}"}

# Fetch config from GitHub
response = requests.get(REMOTE_ENV_URL, headers=headers)
if response.status_code != 200:
    print(f"Failed to fetch config from GitHub. Status: {response.status_code}, Response: {response.text}")
    exit(1)

data = response.json()
config = json.loads(base64.b64decode(data['content']).decode('utf-8'))
sha = data['sha']

# Read report
with open('install-report.txt', 'r') as f:
    report = f.read()

# Parse lines
for line in report.strip().split('\n'):
    match = re.search(r'domain : (.+) \| application pass: (.+)', line)
    if match:
        domain = match.group(1)
        app_pass = match.group(2)
        base_url = f'https://{domain}/'
        found = False
        for source in config['sources']:
            for d in source['domains']:
                if d['base_url'] == base_url:
                    d['application_password'] = app_pass
                    found = True
                    break
            if found:
                break
        if not found:
            # Add to random source
            source = random.choice(config['sources'])
            category = source['default_categories'][0] if source['default_categories'] else 'general'
            source['domains'].append({
                'base_url': base_url,
                'username': 'publisher',
                'application_password': app_pass,
                'category': category
            })

# Encode new config
new_content = json.dumps(config, indent=2)
encoded = base64.b64encode(new_content.encode('utf-8')).decode('utf-8')

# Update on GitHub
update_data = {
    "message": "Update config with new application passwords",
    "content": encoded,
    "sha": sha,
    "branch": BRANCH
}

response = requests.put(REMOTE_ENV_URL, headers=headers, json=update_data)
if response.status_code == 200:
    print("Config updated on GitHub successfully.")
else:
    print("Failed to update config on GitHub:", response.text)