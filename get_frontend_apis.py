import os
import re

app_dir = r'd:\app_works\place_row\lib'
frontend_apis = []

for root, _, files in os.walk(app_dir):
    for file in files:
        if file.endswith('.dart'):
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find client.get('/api/...') or apiClient.post('/api/...')
            matches = re.finditer(r'\.(get|post|put|delete|patch|postMultipart)\(\s*["\'](/api/[^"\']+)["\']', content)
            for m in matches:
                method, endpoint = m.groups()
                # Remove query string if any for base match
                endpoint = endpoint.split('?')[0].split('$')[0]
                frontend_apis.append(f"{method.upper()} {endpoint}")

for r in sorted(set(frontend_apis)):
    print(r)
