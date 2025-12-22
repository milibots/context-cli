#!/bin/bash

# Configuration
WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

# Check for Python
if ! command -v python3 &> /dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

# We write the python script to a temp file to ensure TTY/Interactive mode works correctly
cat <<EOF > /tmp/context_cli_runner.py
import os
import json
import sys
import urllib.request

# --- CONFIGURATION ---
WORKER_URL = "${WORKER_URL}"

# --- ANSI COLORS ---
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
    '.next', 'out', '.nuxt', 'bin', 'obj', '.cargo'
}

IGNORE_EXTS = {
    '.pyc', '.pyo', '.pyd', '.db', '.sqlite', '.png', '.jpg', '.jpeg', 
    '.gif', '.ico', '.svg', '.zip', '.tar', '.gz', '.pdf', '.exe', '.dll',
    'package-lock.json', 'yarn.lock', 'bun.lockb', 'pnpm-lock.yaml', 'context.txt'
}

def get_stats_and_payload():
    payload = {'files': []}
    file_count = 0
    dir_count = 0
    total_size = 0
    
    for root, dirs, files in os.walk('.'):
        # Modify dirs in-place to skip ignored folders
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        dir_count += len(dirs)
        
        for file in files:
            # Skip ignored extensions
            if any(file.endswith(ext) for ext in IGNORE_EXTS): continue
            
            # Skip dotfiles (optional, but usually good)
            if file.startswith('.') and file != '.env.example': continue

            file_path = os.path.join(root, file)
            rel_path = os.path.relpath(file_path, '.')
            
            if rel_path.startswith('./'): rel_path = rel_path[2:]
            if rel_path == 'context_cli_runner.py': continue

            try:
                # 1MB limit per file
                f_size = os.path.getsize(file_path)
                if f_size > 1024 * 1024: continue

                with open(file_path, 'r', encoding='utf-8', errors='ignore') as f:
                    content = f.read()
                    # Basic binary check
                    if '\0' in content: continue 
                    
                    payload['files'].append({'path': rel_path, 'content': content})
                    file_count += 1
                    total_size += len(content)
            except:
                pass

    return payload, file_count, dir_count, total_size

def get_user_confirmation():
    """Forces interaction via /dev/tty so it works even inside curled bash scripts"""
    msg = f"\n{Colors.BOLD}💾 Save to 'context.txt'? (Y/n) > {Colors.NC}"
    try:
        # Open TTY directly for read/write
        with open('/dev/tty', 'r') as tty_in, open('/dev/tty', 'w') as tty_out:
            tty_out.write(msg)
            tty_out.flush()
            return tty_in.readline().strip().lower()
    except:
        # If no TTY (e.g., cron job), default to YES (Safe)
        return 'y'

def main():
    print(f"{Colors.CYAN}{Colors.BOLD}🧠 Context CLI{Colors.NC}")
    print(f"{Colors.CYAN}Scanning directory...{Colors.NC}")

    data, f_count, d_count, size = get_stats_and_payload()
    
    if f_count == 0:
        print(f"{Colors.RED}No valid files found.{Colors.NC}")
        sys.exit(1)

    est_tokens = int(size / 4)
    size_kb = size / 1024

    # --- SUMMARY ---
    print(f"\n{Colors.BOLD}📊 Codebase Summary:{Colors.NC}")
    print(f"   {Colors.BLUE}📁 Folders:{Colors.NC} {d_count}")
    print(f"   {Colors.BLUE}📄 Files:{Colors.NC}   {f_count}")
    print(f"   {Colors.BLUE}💾 Size:{Colors.NC}    {size_kb:.1f} KB")
    print(f"   {Colors.BLUE}🔢 Tokens:{Colors.NC}  ~{est_tokens:,}")
    print(f"")

    # --- UPLOAD ---
    print(f"{Colors.YELLOW}⚡ Fetching formatted context...{Colors.NC}", end='', flush=True)
    
    try:
        json_data = json.dumps(data).encode('utf-8')
        req = urllib.request.Request(WORKER_URL, data=json_data, method='POST')
        req.add_header('Content-Type', 'application/json')
        req.add_header('User-Agent', 'Context-CLI/2.0')

        with urllib.request.urlopen(req) as response:
            result_text = response.read().decode('utf-8')
            print(f"\r{Colors.GREEN}✅ Successfully processed!      {Colors.NC}")
    except Exception as e:
        print(f"\n{Colors.RED}Error connecting to worker: {e}{Colors.NC}")
        sys.exit(1)

    # --- INTERACTION ---
    choice = get_user_confirmation()

    if choice == '' or choice == 'y' or choice == 'yes':
        try:
            with open('context.txt', 'w', encoding='utf-8') as f:
                f.write(result_text)
            print(f"\n{Colors.GREEN}🎉 Saved to: {os.path.abspath('context.txt')}{Colors.NC}")
        except Exception as e:
            print(f"\n{Colors.RED}Error saving file: {e}{Colors.NC}")
    else:
        print(f"\n{Colors.YELLOW}📄 Outputting to terminal:{Colors.NC}\n")
        print(result_text)

if __name__ == "__main__":
    main()
EOF

# Execute the python script
python3 /tmp/context_cli_runner.py

# Cleanup
rm /tmp/context_cli_runner.py
