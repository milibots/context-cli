#!/bin/bash

# Configuration
WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

# ANSI Colors
CYAN='\033[0;36m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo -e "${RED}Error: python3 is required but not installed.${NC}"
    exit 1
fi

echo -e "${CYAN}${BOLD}🧠 Context CLI${NC}"
echo -e "${CYAN}Scanning directory...${NC}"

# Python script to handle logic securely
python3 -c "
import os
import json
import sys
import urllib.request

# --- CONFIGURATION ---
WORKER_URL = '${WORKER_URL}'

IGNORE_DIRS = {
    '.git', 'node_modules', '__pycache__', 'venv', '.venv', 'env', '.env', 
    'dist', 'build', 'coverage', '.idea', '.vscode', 'target', 'vendor', 
    '.next', 'out', '.nuxt', 'bin', 'obj'
}

IGNORE_EXTS = {
    '.pyc', '.pyo', '.pyd', '.db', '.sqlite', '.png', '.jpg', '.jpeg', 
    '.gif', '.ico', '.svg', '.zip', '.tar', '.gz', '.pdf', '.exe', '.dll',
    'package-lock.json', 'yarn.lock', 'bun.lockb', 'pnpm-lock.yaml'
}

# --- COLORS FOR PYTHON ---
C_GREEN = '\033[0;32m'
C_YELLOW = '\033[1;33m'
C_BLUE = '\033[0;34m'
C_RED = '\033[0;31m'
C_NC = '\033[0m'
C_BOLD = '\033[1m'

def get_stats_and_payload():
    payload = {'files': []}
    file_count = 0
    dir_count = 0
    total_size = 0
    
    for root, dirs, files in os.walk('.'):
        # Filter directories in-place
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        dir_count += len(dirs)
        
        for file in files:
            if any(file.endswith(ext) for ext in IGNORE_EXTS):
                continue
                
            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, '.')
            
            if rel_path.startswith('./'): rel_path = rel_path[2:]
            
            # Skip the output file itself if it exists to avoid loops
            if rel_path == 'context.txt': continue

            try:
                # Size limit 1MB per file
                f_size = os.path.getsize(file_path)
                if f_size > 1024 * 1024: continue

                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    payload['files'].append({
                        'path': rel_path,
                        'content': content
                    })
                    file_count += 1
                    total_size += len(content)
            except:
                pass

    return payload, file_count, dir_count, total_size

try:
    # 1. SCAN
    data, f_count, d_count, size = get_stats_and_payload()
    
    if f_count == 0:
        print(f'{C_RED}No valid files found.{C_NC}')
        sys.exit(1)

    # Calculate Tokens (Rough estimate: 1 token ~= 4 chars)
    est_tokens = int(size / 4)
    size_kb = size / 1024

    # 2. PRINT SUMMARY
    print(f'\n{C_BOLD}📊 Codebase Summary:{C_NC}')
    print(f'   {C_BLUE}📁 Folders:{C_NC} {d_count}')
    print(f'   {C_BLUE}📄 Files:{C_NC}   {f_count}')
    print(f'   {C_BLUE}💾 Size:{C_NC}    {size_kb:.1f} KB')
    print(f'   {C_BLUE}🔢 Tokens:{C_NC}  ~{est_tokens:,} (Estimate)')
    print(f'')

    # 3. UPLOAD
    print(f'{C_YELLOW}⚡ Processing with Worker...{C_NC}', end='', flush=True)
    
    json_data = json.dumps(data).encode('utf-8')
    req = urllib.request.Request(WORKER_URL, data=json_data, method='POST')
    req.add_header('Content-Type', 'application/json')
    req.add_header('User-Agent', 'Context-CLI/2.0')

    with urllib.request.urlopen(req) as response:
        result_text = response.read().decode('utf-8')
        print(f'\r{C_GREEN}✅ Successfully processed!      {C_NC}')

    # 4. INTERACTIVE PROMPT
    # We open /dev/tty to ensure we get user input even if script is piped
    try:
        sys.stdin = open('/dev/tty')
        user_input = input(f'\n{C_BOLD}💾 Save to \'context.txt\'? [Y/n] {C_NC}').strip().lower()
    except:
        user_input = 'y' # Default to yes if no tty

    if user_input == '' or user_input == 'y':
        with open('context.txt', 'w', encoding='utf-8') as f:
            f.write(result_text)
        print(f'\n{C_GREEN}🎉 Saved to: {os.getcwd()}/context.txt{C_NC}')
    else:
        print(f'\n{C_YELLOW}📄 Outputting to terminal:{C_NC}\n')
        print(result_text)

except Exception as e:
    print(f'\n{C_RED}Error: {e}{C_NC}')
    sys.exit(1)
"
