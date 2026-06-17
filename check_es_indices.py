#!/usr/bin/env python3
import requests
import json

# Get list of indices
response = requests.get('http://localhost:9200/_cat/indices?format=json')
indices = response.json()

# Filter AI credit indices
ai_credit_indices = [idx for idx in indices if 'ai_credit' in idx['index']]

print('AI Credit Indices:')
print(f"{'Index':<45} {'Docs':<10} {'Size':<15}")
print("-" * 70)
for idx in ai_credit_indices:
    print(f"{idx['index']:<45} {idx['docs.count']:<10} {idx['store.size']:<15}")

# Get detailed stats for each
print("\n\nDetailed Index Stats:")
for idx in ai_credit_indices:
    idx_name = idx['index']
    try:
        stats = requests.get(f'http://localhost:9200/{idx_name}/_count').json()
        print(f"\n{idx_name}:")
        print(f"  Total documents: {stats.get('count', 0)}")
        
        # Get a sample document
        sample = requests.get(f'http://localhost:9200/{idx_name}/_search?size=1').json()
        if sample.get('hits', {}).get('hits'):
            doc = sample['hits']['hits'][0]['_source']
            print(f"  Sample fields: {list(doc.keys())[:5]}...")
    except Exception as e:
        print(f"  Error: {e}")
