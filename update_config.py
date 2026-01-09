#!/usr/bin/env python3
import json
import re
import random
import os

# Read local config.json
with open('/home/ubuntu/vps-wp-automation/config.json', 'r') as f:
    config = json.load(f)

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

# Write updated config back to local file
with open('/home/ubuntu/vps-wp-automation/config.json', 'w') as f:
    json.dump(config, f, indent=2)

print("Config updated locally successfully.")