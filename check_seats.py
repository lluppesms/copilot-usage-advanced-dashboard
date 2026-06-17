#!/usr/bin/env python3
import requests

# Check seat assignments to find user list
response = requests.get('http://localhost:9200/copilot_seat_assignments/_search?size=3')
data = response.json()

if data['hits']['hits']:
    doc = data['hits']['hits'][0]['_source']
    print("Sample seat assignment fields:")
    for key in sorted(doc.keys()):
        print(f"  {key}: {doc[key]}")

# Count unique users with assignments
count_response = requests.post(
    'http://localhost:9200/copilot_seat_assignments/_search',
    json={
        "size": 0,
        "aggs": {
            "unique_users": {
                "cardinality": {"field": "assignee_login"}
            }
        }
    }
)
print(f"\nUnique seat assignees: {count_response.json()['aggregations']['unique_users']['value']}")
