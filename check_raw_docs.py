#!/usr/bin/env python3
import requests

# Query the ES index for ALL documents with their fields
response = requests.get('http://localhost:9200/copilot_ai_credit_usage/_search?size=3')
data = response.json()

print("Raw Records from Elasticsearch (copilot_ai_credit_usage):\n")
for i, hit in enumerate(data['hits']['hits']):
    doc = hit['_source']
    print(f"Document {i+1}:")
    # Print ALL fields
    for key in sorted(doc.keys()):
        val = doc[key]
        if isinstance(val, (int, float, str, type(None), bool)):
            print(f"  {key}: {val}")
    print()
