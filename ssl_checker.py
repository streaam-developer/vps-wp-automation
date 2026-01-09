#!/usr/bin/env python3
import json
import os
import subprocess
import sys

CONFIG_PATH = '/home/ubuntu/vps-wp-automation/config.json'

def load_domains():
    with open(CONFIG_PATH, 'r') as f:
        config = json.load(f)
    
    domains = set()
    for source in config['sources']:
        for d in source['domains']:
            url = d['base_url']
            domain = url.replace('https://', '').replace('http://', '').rstrip('/')
            domains.add(domain)
    return domains

def check_and_add_ssl(domain):
    cert_path = f'/etc/letsencrypt/live/{domain}'
    if os.path.exists(cert_path):
        print(f'SSL already exists for {domain}')
        return True
    
    print(f'Getting SSL for {domain}')
    cmd = [
        'certbot', '--nginx',
        '-d', domain,
        '-d', f'www.{domain}',
        '--non-interactive',
        '--agree-tos',
        '-m', f'admin@{domain}',
        '--redirect'
    ]
    
    try:
        result = subprocess.run(cmd, capture_output=True, text=True, check=True)
        print(f'SSL added successfully for {domain}')
        return True
    except subprocess.CalledProcessError as e:
        print(f'Failed to add SSL for {domain}: {e.stderr}')
        return False

def main():
    domains = load_domains()
    for domain in sorted(domains):
        check_and_add_ssl(domain)

if __name__ == '__main__':
    main()