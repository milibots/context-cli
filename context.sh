#!/bin/bash

# Configuration
WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

# Check if python3 is installed
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

echo "Reading files from current directory..."

# We use Python to handle JSON serialization safely to avoid Bash escaping hell
# and to efficiently ignore directories.
python3 -c "
import os
import json
import sys
import urllib.request

# Configuration of ignores
IGNORE_DIRS = {
    '.git', 'node_modules', '__pycache__', 'venv', '.venv', 'dist', 'build', 
    'coverage', '.idea', '.vscode', 'target', 'vendor', '.next', 'out'
}
IGNORE_EXTS = {
    '.pyc', '.pyo', '.pyd', '.db', '.sqlite', '.png', '.jpg', '.jpeg', 
    '.gif', '.ico', '.svg', '.zip', '.tar', '.gz', '.pdf', '.exe', 
    'package-lock.json', 'yarn.lock', 'bun.lockb'
}

def should_ignore(path, filename):
    parts = path.split(os.sep)
    # Check ignored directories
    if any(p in IGNORE_DIRS for p in parts):
        return True
    # Check ignored extensions
    if any(filename.endswith(ext) for ext in IGNORE_EXTS):
        return True
    return False

def collect_files():
    payload = {'files': []}
    count = 0
    total_size = 0
    
    for root, dirs, files in os.walk('.'):
        # Modify dirs in-place to prevent walking ignored directories
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        
        for file in files:
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, '.')
            
            if rel_path.startswith('./'):
                rel_path = rel_path[2:]
                
            if should_ignore(root, file):
                continue
                
            try:
                # Limit individual file size to 1MB to prevent timeouts
                if os.path.getsize(file_path) > 1024 * 1024: 
                    print(f'Skipping large file: {rel_path}', file=sys.stderr)
                    continue

                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    payload['files'].append({
                        'path': rel_path,
                        'content': content
                    })
                    count += 1
                    total_size += len(content)
            except Exception as e:
                print(f'Error reading {rel_path}: {e}', file=sys.stderr)

    return payload, count, total_size

try:
    data, count, size = collect_files()
    if count == 0:
        print('No valid files found to upload.')
        sys.exit(1)

    print(f'Uploading {count} files (~{size/1024:.1f} KB)...')

    json_data = json.dumps(data).encode('utf-8')
    req = urllib.request.Request('${WORKER_URL}', data=json_data, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('User-Agent', 'Context-CLI/1.0')

    with urllib.request.urlopen(req) as response:
        response_text = response.read().decode('utf-8')
        print(response_text)

except Exception as e:
    print(f'Error: {e}')
    sys.exit(1)
"
