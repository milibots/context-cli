#!/bin/bash

# Configuration
WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

# Check for Python
if ! command -v python3 &gt; /dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

# Run the Python logic directly
python3 -c "
import os
import json
import sys
import urllib.request
import platform
import subprocess

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

def get_system_info():
    \"\"\"Get detailed system information\"\"\"
    info = []
    
    # OS Details
    info.append(f\"Operating System: {platform.system()} {platform.release()}\")
    info.append(f\"OS Version: {platform.version()}\")
    
    # Python Version
    info.append(f\"Python Version: {sys.version.split()[0]}\")
    info.append(f\"Python Executable: {sys.executable}\")
    
    # CPU Info
    try:
        cpu_count = os.cpu_count()
        info.append(f\"CPU Cores: {cpu_count}\")
        
        # Try to get CPU model (Linux/Mac)
        if platform.system() == 'Linux':
            with open('/proc/cpuinfo', 'r') as f:
                for line in f:
                    if 'model name' in line:
                        cpu_model = line.split(':')[1].strip()
                        info.append(f\"CPU Model: {cpu_model}\")
                        break
        elif platform.system() == 'Darwin':  # macOS
            result = subprocess.run(['sysctl', '-n', 'machdep.cpu.brand_string'], capture_output=True, text=True)
            if result.returncode == 0:
                info.append(f\"CPU Model: {result.stdout.strip()}\")
    except:
        pass
    
    # RAM Info
    try:
        if platform.system() == 'Linux':
            with open('/proc/meminfo', 'r') as f:
                for line in f:
                    if 'MemTotal' in line:
                        mem_kb = int(line.split()[1])
                        mem_gb = mem_kb / (1024 * 1024)
                        info.append(f\"Total RAM: {mem_gb:.2f} GB\")
                        break
        elif platform.system() == 'Darwin':  # macOS
            result = subprocess.run(['sysctl', '-n', 'hw.memsize'], capture_output=True, text=True)
            if result.returncode == 0:
                mem_bytes = int(result.stdout.strip())
                mem_gb = mem_bytes / (1024**3)
                info.append(f\"Total RAM: {mem_gb:.2f} GB\")
        elif platform.system() == 'Windows':
            result = subprocess.run(['wmic', 'ComputerSystem', 'get', 'TotalPhysicalMemory'], capture_output=True, text=True)
            if result.returncode == 0:
                lines = result.stdout.strip().split('\n')
                if len(lines) > 1:
                    mem_bytes = int(lines[1].strip())
                    mem_gb = mem_bytes / (1024**3)
                    info.append(f\"Total RAM: {mem_gb:.2f} GB\")
    except:
        pass
    
    return info

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
            
            # Get system info
            system_info = get_system_info()
            
            # Create header with system info
            header = \"=\" * 80 + \"\\n\"
            header += \"SYSTEM INFORMATION\\n\"
            header += \"=\" * 80 + \"\\n\"
            for info_line in system_info:
                header += f\"{info_line}\\n\"
            header += \"=\" * 80 + \"\\n\\n\"
            
            # 4. WRITE TO FILE with system info at the top
            with open(OUTPUT_FILE, 'w', encoding='utf-8') as f:
                f.write(header)
                f.write(result_text)
            
            print(f'\r{Colors.GREEN}✅ Done! Saved to: {Colors.BOLD}{OUTPUT_FILE}{Colors.NC}      ')
            print(f'{Colors.CYAN}   Path: {os.path.abspath(OUTPUT_FILE)}{Colors.NC}')

    except Exception as e:
        print(f'\n{Colors.RED}Error: {e}{Colors.NC}')
        sys.exit(1)

if __name__ == '__main__':
    main()
"
