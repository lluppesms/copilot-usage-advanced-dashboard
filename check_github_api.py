#!/usr/bin/env python3
import requests
import json
import os

github_pat = os.getenv("GITHUB_PAT")
org = "ms-mfg-community"
headers = {"Authorization": f"Bearer {github_pat}"}

# Get a sample of AI credit usage data from the API
url = f"https://api.github.com/organizations/{org}/settings/billing/ai_credit/usage?year=2026&month=6&day=1"
response = requests.get(url, headers=headers)

if response.status_code == 200:
    data = response.json()
    items = data.get("usage_records", [])
    if items:
        print("Sample Raw API Response (first item):")
        print(json.dumps(items[0], indent=2))
    else:
        print("No usage records in response")
else:
    print(f"Error: {response.status_code}")
    print(response.text[:500])
