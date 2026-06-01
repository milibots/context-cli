#!/bin/bash

print_error() {
    echo "❌ Error: $1" >&2
}

print_success() {
    echo "✅ $1"
}

print_info() {
    echo "ℹ️  $1"
}

print_warning() {
    echo "⚠️  Warning: $1" >&2
}

print_info "Checking dependencies..."

if ! command -v python3 >/dev/null 2>&1; then
    print_error "python3 is required but not installed."
    exit 1
fi

if ! command -v curl >/dev/null 2>&1; then
    print_error "curl is required but not installed."
    exit 1
fi

PYTHON_VERSION=$(python3 -c 'import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")')

if ! python3 -c "import sys; exit(0 if sys.version_info >= (3, 6) else 1)"; then
    print_error "Python 3.6+ required. Found $PYTHON_VERSION"
    exit 1
fi

print_success "Dependencies OK"

RANDOM_NAME=$(LC_ALL=C tr -dc 'a-zA-Z0-9' </dev/urandom 2>/dev/null | head -c 10)
if [ -z "$RANDOM_NAME" ]; then
    RANDOM_NAME=$(date +%s | sha256sum | base64 | head -c 10 | tr -d '/+' | tr '+' 'a' | tr '/' 'A')
fi

OUTPUT_FILE="${RANDOM_NAME}.txt"

print_info "Generating $OUTPUT_FILE..."

python3 - "$OUTPUT_FILE" <<'EOF'
import os
import sys
import platform

OUTPUT_FILE = sys.argv[1]

IGNORE_DIRS = {
    ".git","node_modules","__pycache__","venv",".venv","env",".env",
    "dist","build",".idea",".vscode",".next","out","bin","obj",".github",
    ".pytest_cache",".mypy_cache",".tox","htmlcov",".coverage"
}

IGNORE_EXTS = {
    ".pyc",".pyo",".pyd",".png",".jpg",".jpeg",".gif",".ico",".svg",
    ".zip",".tar",".gz",".pdf",".exe",".dll",".so",".dylib",".bin",
    ".dat",".log",".lock",".context.txt",OUTPUT_FILE,
    ".session",".session-journal",".session-joundala",".db",".sqlite",".env"
}

MAX_FILE_SIZE = 1024 * 1024

def system_info():
    return [
        f"{platform.system()} {platform.release()}",
        f"Python {sys.version.split()[0]}",
        f"CPU {os.cpu_count()}",
        f"PWD {os.getcwd()}"
    ]

def read_file(path):
    try:
        with open(path,"r",encoding="utf-8") as f:
            return True,f.read()
    except:
        try:
            with open(path,"r",encoding="utf-8",errors="ignore") as f:
                return True,f.read()
        except:
            return False,""

def is_huge_json(path, content):
    if not path.endswith(".json"):
        return False
    return len(content.splitlines()) > 100

files=[]
paths=[]

for root,dirs,fs in os.walk("."):
    dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

    for f in fs:
        if f in {".env"}:
            continue

        if any(f.endswith(ext) for ext in IGNORE_EXTS):
            continue

        path=os.path.join(root,f)

        try:
            if os.path.getsize(path) > MAX_FILE_SIZE:
                continue
        except:
            continue

        ok,content=read_file(path)
        if not ok:
            continue

        if is_huge_json(path,content):
            continue

        files.append({"path":path,"content":content})
        paths.append(path)

out=[]
out.append("SYSTEM")
out.extend(system_info())
out.append("FILES")

for f in files:
    out.append("="*40)
    out.append(f["path"])
    out.append(f["content"])

with open(OUTPUT_FILE,"w",encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"DONE {len(files)}")
EOF

if [ ! -f "$OUTPUT_FILE" ]; then
    print_error "Failed"
    exit 1
fi

FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
print_info "Uploading..."

RESPONSE=$(curl -s -X POST \
  -F "file=@${OUTPUT_FILE}" \
  -F "bucket=default" \
  https://files.imeow.ir/upload)

SUCCESS=$(python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('success',False))" <<< "$RESPONSE")

if [ "$SUCCESS" = "True" ] || [ "$SUCCESS" = "true" ]; then
    URL=$(python3 -c "import sys,json; print(json.loads(sys.stdin.read()).get('download_url',''))" <<< "$RESPONSE")
    echo "OK https://files.imeow.ir$URL"
else
    echo "FAILED $RESPONSE"
    exit 1
fi
