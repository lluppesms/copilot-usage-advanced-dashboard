#!/usr/bin/env python3
import requests
import json

# Get sample documents from both indices
indices = ['copilot_ai_credit_usage', 'copilot_ai_credit_user_daily']

for idx_name in indices:
    print(f"\n{'='*70}")
    print(f"Index: {idx_name}")
    print(f"{'='*70}")
    
    response = requests.get(f'http://localhost:9200/{idx_name}/_search?size=2')
    data = response.json()
    
    if data.get('hits', {}).get('hits'):
        for i, hit in enumerate(data['hits']['hits']):
            doc = hit['_source']
            print(f"\nDocument {i+1}:")
            # Show key fields
            key_fields = ['day', 'user_login', 'scope_slug', 'model', 'sku', 
                         'ai_credits_gross', 'ai_credits_net', 'ai_credits_discount',
                         'gross_quantity', 'net_quantity']
            for field in key_fields:
                if field in doc:
                    print(f"  {field}: {doc[field]}")
    else:
        print("No documents found!")
