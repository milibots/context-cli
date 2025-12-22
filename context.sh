#!/bin/bash

# Configuration
WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

# Run the Python logic directly
python3 -c "
import os
import json
import sys
import urllib.request

# --- CONFIGURATION ---
WORKER_URL = '${WORKER_URL}'
OUTPUT_FILE = 'context.txt'

# --- COLORS ---
class Colors:
    CYAN = '\033[0;36m'
    GREEN = '\033[0;32m'
    YELLOW = '\033[1;33m'
    RED = '\033[0;31m'
    BLUE = '\033[0;34m'
    BOLD = '\033[1m'
    NC = '\033[0m'

IGNORE_DIRS = {
    '.git', 'node_modules', '__pycache__', 'venv', '.venv', 'env', '.env', 
    'dist', 'build', 'coverage', '.idea', '.vscode', 'target', 'vendor', 
    '.next', 'out', '.nuxt', 'bin', 'obj', '.cargo', '.github'
}

IGNORE_EXTS = {
    '.pyc', '.pyo', '.pyd', '.db', '.sqlite', '.png', '.jpg', '.jpeg', 
    '.gif', '.ico', '.svg', '.zip', '.tar', '.gz', '.pdf', '.exe', '.dll',
    'package-lock.json', 'yarn.lock', 'bun.lockb', 'pnpm-lock.yaml', 'context.txt'
}

def main():
    print(f'{Colors.CYAN}{Colors.BOLD}🧠 Context CLI{Colors.NC}')
    print(f'{Colors.CYAN}Scanning directory...{Colors.NC}')

    payload = {'files': []}
    file_count = 0
    dir_count = 0
    total_size = 0
    
    # 1. SCAN FILES
    for root, dirs, files in os.walk('.'):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS] # Block ignored folders
        dir_count += len(dirs)
        
        for file in files:
            if any(file.endswith(ext) for ext in IGNORE_EXTS): continue
            
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, '.')
            if rel_path.startswith('./'): rel_path = rel_path[2:]
            
            # Skip the output file itself
            if rel_path == OUTPUT_FILE: continue

            try:
                # 1MB limit per file
                if os.path.getsize(file_path) > 1024 * 1024: continue

                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    # Skip binary files if any slipped through
                    if '\\0' in content: continue 
                    
                    payload['files'].append({'path': rel_path, 'content': content})
                    file_count += 1
                    total_size += len(content)
            except:
                pass

    if file_count == 0:
        print(f'{Colors.RED}No valid files found.{Colors.NC}')
        sys.exit(1)

    est_tokens = int(total_size / 4)
    size_kb = total_size / 1024

    # 2. PRINT SUMMARY
    print(f'\n{Colors.BOLD}📊 Codebase Summary:{Colors.NC}')
    print(f'   {Colors.BLUE}📁 Folders:{Colors.NC} {dir_count}')
    print(f'   {Colors.BLUE}📄 Files:{Colors.NC}   {file_count}')
    print(f'   {Colors.BLUE}💾 Size:{Colors.NC}    {size_kb:.1f} KB')
    print(f'   {Colors.BLUE}🔢 Tokens:{Colors.NC}  ~{est_tokens:,}')
    print(f'')

    # 3. UPLOAD AND SAVE
    print(f'{Colors.YELLOW}⚡ Fetching formatted context...{Colors.NC}', end='', flush=True)
    
    try:
        json_data = json.dumps(payload).encode('utf-8')
        req = urllib.request.Request(WORKER_URL, data=json_data, method='POST')
        req.add_header('Content-Type', 'application/json')
        req.add_header('User-Agent', 'Context-CLI/3.0')

        with urllib.request.urlopen(req) as response:
            result_text = response.read().decode('utf-8')
            
            # 4. WRITE TO FILE
            with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                f.write(result_text)
            
            print(f'\r{Colors.GREEN}✅ Done! Saved to: {Colors.BOLD}{OUTPUT_FILE}{Colors.NC}      ')
            print(f'{Colors.CYAN}   Path: {os.path.abspath(OUTPUT_FILE)}{Colors.NC}')

    except Exception as e:
        print(f'\n{Colors.RED}Error: {e}{Colors.NC}')
        sys.exit(1)

if __name__ == '__main__':
    main()
"
