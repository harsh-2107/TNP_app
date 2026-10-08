import os
import re

app_dir = r'd:\app_works\crispr-tnp\app'
routes = []

for root, _, files in os.walk(app_dir):
    for file in files:
        if file == 'router.py':
            path = os.path.join(root, file)
            with open(path, 'r', encoding='utf-8') as f:
                content = f.read()
            
            # Find all decorators like @admin_router.get("/something")
            matches = re.finditer(r'@([a-z_]+_router)\.(get|post|put|delete|patch)\(\s*["\']([^"\']+)["\']', content)
            for m in matches:
                router_name, method, endpoint = m.groups()
                # Deduce base path from router name, e.g. admin_router -> /api/admin
                base = router_name.replace('_router', '')
                full_path = f"/api/{base}{endpoint}".replace('//', '/')
                routes.append(f"{method.upper()} {full_path}")

for r in sorted(routes):
    print(r)
