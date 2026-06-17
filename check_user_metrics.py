#!/usr/bin/env python3
import requests
import json

# Check what user metrics data is available
response = requests.get('http://localhost:9200/copilot_user_metrics/_search?size=1')
data = response.json()

if data['hits']['hits']:
    doc = data['hits']['hits'][0]['_source']
    print("Sample User Metrics Document:")
    print(json.dumps(doc, indent=2, default=str))
else:
    print("No user metrics data found")
    
# Also check indices that might have user activity
response = requests.get('http://localhost:9200/_cat/indices?format=json')
indices = response.json()

print("\n\nAvailable Indices with 'user' or 'metric' in name:")
for idx in indices:
    if 'user' in idx['index'] or 'metric' in idx['index']:
        print(f"  {idx['index']}: {idx['docs.count']} docs")
