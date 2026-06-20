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

# All directories to ignore/skip
IGNORE_DIRS = {
    # Version control
    ".git", ".svn", ".hg",
    
    # Python
    "__pycache__", ".pytest_cache", ".mypy_cache", ".tox", ".coverage",
    "venv", ".venv", "env", ".env", "virtualenv", ".virtualenv",
    "dist", "build", "lib", "lib64", "include", "bin", "scripts",
    "pip-wheel-metadata", "pip-wheel-cache", "pip-cache", "pip-log",
    "egg-info", "dist-info",
    
    # JavaScript/Node.js
    "node_modules", "bower_components", "jspm_packages",
    ".npm", ".yarn", ".pnpm-store",
    "dist", "build", ".next", "out",
    
    # Java
    "target", "classes", "bin", "out", "lib", "libs",
    
    # C/C++
    "Debug", "Release", "MinSizeRel", "RelWithDebInfo",
    "CMakeFiles", "cmake-build-debug", "cmake-build-release",
    
    # PHP
    "vendor", "composer", "cache", "logs",
    
    # Ruby
    "vendor/bundle", ".bundle", "tmp",
    
    # Golang
    "pkg", "vendor", "bin",
    
    # Rust
    "target", "debug", "release",
    
    # Dart/Flutter
    ".dart_tool", "build", "pubspec.lock",
    
    # IDEs
    ".idea", ".vscode", ".vs", ".settings", "nbproject",
    
    # OS
    ".DS_Store", "Thumbs.db", "desktop.ini",
    
    # Misc
    "logs", "log", "tmp", "temp", ".tmp", ".temp",
    ".cache", "cache", "caches",
    "backup", "backups", ".backup",
    "coverage", "htmlcov",
    "reports", "test-reports",
    "generated", "gen", "deps", "dependencies",
    ".terraform", "terraform.tfstate", ".serverless",
}

# All file extensions to ignore/skip
IGNORE_EXTS = {
    # Python bytecode
    ".pyc", ".pyo", ".pyd", ".so", ".dll", ".dylib",
    
    # Cache files
    ".cache", ".cached", ".tmp", ".temp", ".swp", ".swo",
    
    # Font files (all formats)
    ".ttf", ".otf", ".woff", ".woff2", ".eot", ".fon",
    ".fnt", ".bdf", ".pcf", ".psf", ".sfd", ".ufo",
    
    # Images
    ".png", ".jpg", ".jpeg", ".gif", ".bmp", ".tiff", ".tif",
    ".webp", ".ico", ".svg", ".icns", ".psd", ".xcf",
    
    # Audio/Video
    ".mp3", ".mp4", ".wav", ".avi", ".mov", ".mkv", ".flac",
    ".ogg", ".m4a", ".aac", ".wma", ".webm", ".mpeg",
    
    # Archives
    ".zip", ".tar", ".gz", ".bz2", ".xz", ".7z", ".rar",
    ".zst", ".lz4", ".lzo", ".lzma", ".z", ".Z", ".tgz",
    
    # Documents
    ".pdf", ".doc", ".docx", ".xls", ".xlsx", ".ppt", ".pptx",
    ".odt", ".ods", ".odp", ".epub", ".mobi", ".azw",
    
    # Executables
    ".exe", ".msi", ".dmg", ".pkg", ".deb", ".rpm",
    ".app", ".bat", ".cmd", ".com", ".sh", ".bash",
    
    # Database
    ".db", ".sqlite", ".sqlite3", ".db3", ".mdb", ".accdb",
    ".sqlite-journal", ".sqlite-wal", ".shm",
    
    # Lock files
    ".lock", ".lockb", ".lockfile", "package-lock.json",
    "yarn.lock", "composer.lock", "Gemfile.lock",
    "poetry.lock", "Cargo.lock", "Pipfile.lock",
    
    # Logs
    ".log", ".logs", ".out", ".err", ".error",
    
    # Binary
    ".bin", ".dat", ".data", ".dump", ".dmp", ".core",
    ".o", ".obj", ".lib", ".a", ".def", ".map",
    
    # Config env
    ".env", ".envrc", ".env.local", ".env.production", ".env.development",
    
    # Docker
    ".dockerignore", ".docker",
    
    # Session/temp files
    ".session", ".session-journal", ".session-joundala", ".cache",
    
    # IDE specific
    ".iml", ".ipr", ".iws", ".classpath", ".project",
    ".suo", ".user", ".sln", ".csproj", ".fsproj",
    
    # Generated files
    ".min.js", ".min.css", ".bundle.js", ".bundle.css",
    ".chunk.js", ".chunk.css", ".chunk.map",
    ".map", ".js.map", ".css.map",
    
    # Font file extension patterns
    "*.ttf", "*.otf", "*.woff", "*.woff2", "*.eot", "*.fon", "*.fnt",
}

MAX_FILE_SIZE = 1024 * 1024  # 1MB

def system_info():
    return [
        f"{platform.system()} {platform.release()}",
        f"Python {sys.version.split()[0]}",
        f"CPU {os.cpu_count()}",
        f"PWD {os.getcwd()}"
    ]

def read_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return True, f.read()
    except:
        try:
            with open(path, "r", encoding="utf-8", errors="ignore") as f:
                return True, f.read()
        except:
            return False, ""

def is_binary_content(content):
    """Check if content appears to be binary"""
    if not content:
        return False
    # Check if file contains null bytes or high percentage of non-printable chars
    sample = content[:1024]
    null_count = sample.count('\x00')
    if null_count > 0:
        return True
    # Check for unusual character distribution
    printable = sum(32 <= ord(c) <= 126 or c in '\n\r\t' for c in sample)
    if len(sample) > 0 and printable / len(sample) < 0.7:
        return True
    return False

def is_huge_json(path, content):
    if not path.endswith(".json"):
        return False
    return len(content.splitlines()) > 100

def should_ignore_path(path):
    """Check if path should be ignored based on patterns"""
    path_lower = path.lower()
    
    # Check for font files by extension
    if any(path_lower.endswith(ext) for ext in ['.ttf', '.otf', '.woff', '.woff2', '.eot', '.fon', '.fnt', '.bdf', '.pcf', '.psf', '.sfd', '.ufo']):
        return True
    
    # Check for byte files
    if any(path_lower.endswith(ext) for ext in ['.pyc', '.pyo', '.pyd', '.so', '.dll', '.dylib']):
        return True
    
    # Check for cache files
    if any(path_lower.endswith(ext) for ext in ['.cache', '.cached', '.tmp', '.temp', '.swp', '.swo']):
        return True
    
    # Check for venv patterns
    venv_patterns = ['venv', '.venv', 'env', '.env', 'virtualenv', '.virtualenv']
    for pattern in venv_patterns:
        if pattern in path.split(os.sep):
            return True
    
    return False

files = []
paths = []

for root, dirs, fs in os.walk("."):
    # Filter directories
    dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
    
    for f in fs:
        # Skip specific files
        if f in {".env", "package-lock.json", "yarn.lock", "composer.lock"}:
            continue
        
        # Skip by extension
        if any(f.lower().endswith(ext) for ext in IGNORE_EXTS):
            continue
        
        path = os.path.join(root, f)
        
        # Additional path-based checks
        if should_ignore_path(path):
            continue
        
        # Check file size
        try:
            if os.path.getsize(path) > MAX_FILE_SIZE:
                continue
        except:
            continue
        
        # Try to read file
        ok, content = read_file(path)
        if not ok:
            continue
        
        # Check if content is binary
        if is_binary_content(content):
            continue
        
        # Skip huge JSON files
        if is_huge_json(path, content):
            continue
        
        files.append({"path": path, "content": content})
        paths.append(path)

# Build output
out = []
out.append("SYSTEM")
out.extend(system_info())
out.append("FILES")

for f in files:
    out.append("=" * 40)
    out.append(f["path"])
    out.append(f["content"])

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"DONE {len(files)}")
EOF

if [ ! -f "$OUTPUT_FILE" ]; then
    print_error "Failed to generate output file"
    exit 1
fi

FILE_SIZE=$(du -h "$OUTPUT_FILE" | cut -f1)
print_success "Generated $OUTPUT_FILE (Size: $FILE_SIZE, Files: $(grep -c "^==" "$OUTPUT_FILE" 2>/dev/null || echo "0"))"
