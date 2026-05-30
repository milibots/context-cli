#!/bin/bash

OUTPUT_FILE="context.txt"

if ! command -v python3 >/dev/null; then
    echo "Error: python3 is required"
    exit 1
fi

python3 - <<'EOF'
import os
import sys
import platform

OUTPUT_FILE = "context.txt"

IGNORE_DIRS = {
    ".git", "node_modules", "__pycache__", "venv", ".venv", "env", ".env",
    "dist", "build", ".idea", ".vscode", ".next", "out", "bin", "obj", ".github"
}

IGNORE_EXTS = {
    ".pyc", ".pyo", ".pyd", ".db", ".sqlite", ".png", ".jpg", ".jpeg", ".gif",
    ".ico", ".svg", ".zip", ".tar", ".gz", ".pdf", ".exe", ".dll", "context.txt"
}

def system_info():
    return [
        f"OS: {platform.system()} {platform.release()}",
        f"Version: {platform.version()}",
        f"Python: {sys.version.split()[0]}",
        f"Executable: {sys.executable}",
        f"Cores: {os.cpu_count()}"
    ]

def generate_tree(paths):
    tree = {}
    for path in paths:
        parts = path.split("/")
        cur = tree
        for i, p in enumerate(parts):
            if p not in cur:
                cur[p] = {} if i < len(parts) - 1 else None
            cur = cur[p] if cur[p] is not None else {}
    
    def render(node, prefix=""):
        out = ""
        if not node:
            return out
        keys = sorted(node.keys())
        for i, k in enumerate(keys):
            last = i == len(keys) - 1
            out += prefix + ("└── " if last else "├── ") + k + "\n"
            if node[k] is not None:
                out += render(node[k], prefix + ("    " if last else "│   "))
        return out
    return render(tree)

files = []
paths = []

for root, dirs, fs in os.walk("."):
    dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]

    for f in fs:
        if any(f.endswith(ext) for ext in IGNORE_EXTS):
            continue

        path = os.path.join(root, f)
        abs_path = os.path.abspath(path)
        rel_path = os.path.relpath(path, ".")

        try:
            if os.path.getsize(path) > 1024 * 1024:
                continue

            with open(path, "r", encoding="utf-8", errors="ignore") as x:
                content = x.read()

            files.append({
                "path": rel_path,
                "absolute_path": abs_path,
                "content": content
            })
            paths.append(rel_path)
        except:
            pass

out = []
out.append("=" * 80)
out.append("SYSTEM INFORMATION")
out.append("=" * 80)
out.extend(system_info())
out.append("=" * 80)
out.append("")
out.append("# File Tree")
out.append("")
out.append(generate_tree(paths))
out.append("")
out.append("# File Contents")
out.append("")

for f in files:
    out.append("=" * 80)
    out.append(f"Path: {f['absolute_path']}")
    out.append("=" * 80)
    out.append(f["content"])
    out.append("")

with open(OUTPUT_FILE, "w", encoding="utf-8") as f:
    f.write("\n".join(out))

print(f"Done: {os.path.abspath(OUTPUT_FILE)}")
EOF
