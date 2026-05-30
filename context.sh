#!/bin/bash

WORKER_URL="https://make-files-readable-for-ai.milaadfarzian.workers.dev/"

if ! command -v python3 >/dev/null; then
    echo "Error: python3 is required but not installed."
    exit 1
fi

python3 -c "
import os
import json
import sys
import urllib.request
import platform
import subprocess

WORKER_URL='${WORKER_URL}'
OUTPUT_FILE='context.txt'

class Colors:
    CYAN='\033[0;36m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    RED='\033[0;31m'
    BLUE='\033[0;34m'
    BOLD='\033[1m'
    NC='\033[0m'

IGNORE_DIRS={'.git','node_modules','__pycache__','venv','.venv','env','.env','dist','build','coverage','.idea','.vscode','target','vendor','.next','out','.nuxt','bin','obj','.cargo','.github'}

IGNORE_EXTS={'.pyc','.pyo','.pyd','.db','.sqlite','.png','.jpg','.jpeg','.gif','.ico','.svg','.zip','.tar','.gz','.pdf','.exe','.dll','package-lock.json','yarn.lock','bun.lockb','pnpm-lock.yaml','context.txt'}

def get_system_info():
    info=[]
    info.append(f'Operating System: {platform.system()} {platform.release()}')
    info.append(f'OS Version: {platform.version()}')
    info.append(f'Python Version: {sys.version.split()[0]}')
    info.append(f'Python Executable: {sys.executable}')
    info.append(f'CPU Cores: {os.cpu_count()}')

    try:
        if platform.system()=='Linux':
            with open('/proc/cpuinfo','r') as f:
                for l in f:
                    if 'model name' in l:
                        info.append(f'CPU Model: {l.split(\":\")[1].strip()}')
                        break
        elif platform.system()=='Darwin':
            r=subprocess.run(['sysctl','-n','machdep.cpu.brand_string'],capture_output=True,text=True)
            if r.returncode==0:
                info.append(f'CPU Model: {r.stdout.strip()}')
    except:
        pass

    try:
        if platform.system()=='Linux':
            with open('/proc/meminfo','r') as f:
                for l in f:
                    if 'MemTotal' in l:
                        gb=int(l.split()[1])/(1024*1024)
                        info.append(f'Total RAM: {gb:.2f} GB')
                        break
        elif platform.system()=='Darwin':
            r=subprocess.run(['sysctl','-n','hw.memsize'],capture_output=True,text=True)
            if r.returncode==0:
                gb=int(r.stdout.strip())/(1024**3)
                info.append(f'Total RAM: {gb:.2f} GB')
        elif platform.system()=='Windows':
            r=subprocess.run(['wmic','ComputerSystem','get','TotalPhysicalMemory'],capture_output=True,text=True)
            lines=r.stdout.strip().split('\\n')
            if len(lines)>1:
                gb=int(lines[1].strip())/(1024**3)
                info.append(f'Total RAM: {gb:.2f} GB')
    except:
        pass

    return info

def main():
    print(f'{Colors.CYAN}{Colors.BOLD}🧠 Context CLI{Colors.NC}')
    print(f'{Colors.CYAN}Scanning directory...{Colors.NC}')

    payload={'files':[]}
    file_count=0
    dir_count=0
    total_size=0

    for root,dirs,files in os.walk('.'):
        dirs[:]=[d for d in dirs if d not in IGNORE_DIRS]
        dir_count+=len(dirs)

        for file in files:
            if any(file.endswith(ext) for ext in IGNORE_EXTS):
                continue

            file_path=os.path.join(root,file)
            abs_path=os.path.abspath(file_path)
            rel_path=os.path.relpath(file_path,'.')

            if rel_path.startswith('./'):
                rel_path=rel_path[2:]

            if rel_path==OUTPUT_FILE:
                continue

            try:
                if os.path.getsize(file_path)>1024*1024:
                    continue

                with open(file_path,'r',encoding='utf-8',errors='ignore') as f:
                    content=f.read()

                    if '\\0' in content:
                        continue

                    payload['files'].append({
                        'path':rel_path,
                        'absolute_path':abs_path,
                        'content':content
                    })

                    file_count+=1
                    total_size+=len(content)
            except:
                pass

    if file_count==0:
        print(f'{Colors.RED}No valid files found.{Colors.NC}')
        sys.exit(1)

    est_tokens=int(total_size/4)
    size_kb=total_size/1024

    print(f'\\n{Colors.BOLD}📊 Codebase Summary:{Colors.NC}')
    print(f'   {Colors.BLUE}📁 Folders:{Colors.NC} {dir_count}')
    print(f'   {Colors.BLUE}📄 Files:{Colors.NC}   {file_count}')
    print(f'   {Colors.BLUE}💾 Size:{Colors.NC}    {size_kb:.1f} KB')
    print(f'   {Colors.BLUE}🔢 Tokens:{Colors.NC}  ~{est_tokens:,}')
    print('')

    print(f'{Colors.YELLOW}⚡ Fetching formatted context...{Colors.NC}', end='', flush=True)

    try:
        json_data=json.dumps(payload).encode('utf-8')
        req=urllib.request.Request(WORKER_URL,data=json_data,method='POST')
        req.add_header('Content-Type','application/json')
        req.add_header('User-Agent','Context-CLI/3.0')

        with urllib.request.urlopen(req) as response:
            result_text=response.read().decode('utf-8')

            system_info=get_system_info()

            header='='*80+'\\nSYSTEM INFORMATION\\n'+'='*80+'\\n'
            header+='\\n'.join(system_info)+'\\n'+'='*80+'\\n\\n'

            with open(OUTPUT_FILE,'w',encoding='utf-8') as f:
                f.write(header)
                f.write(result_text)

            print(f'\\r{Colors.GREEN}✅ Done! Saved to: {Colors.BOLD}{OUTPUT_FILE}{Colors.NC}      ')
            print(f'{Colors.CYAN}   Path: {os.path.abspath(OUTPUT_FILE)}{Colors.NC}')

    except Exception as e:
        print(f'\\n{Colors.RED}Error: {e}{Colors.NC}')
        sys.exit(1)

if __name__=='__main__':
    main()
"
