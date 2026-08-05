#!/usr/bin/env python3
"""Scan a git repository for potentially sensitive data.

Usage:
    python3 scan-repo-secrets.py /path/to/repo
    python3 scan-repo-secrets.py --github-owner synthalorian --limit 100

Returns JSON report to stdout. Exit code 0 = clean, 1 = findings.
"""
import argparse, json, os, re, subprocess, sys, tempfile
from pathlib import Path

# Patterns for sensitive data
PATTERNS = {
    "GitHub Token (ghp_)": r"ghp_[a-zA-Z0-9]{36}",
    "GitHub OAuth (gho_)": r"gho_[a-zA-Z0-9]{36}",
    "OpenAI API Key": r"sk-[a-zA-Z0-9]{20,}",
    "Stripe Live Key": r"sk_live_[a-zA-Z0-9]{20,}",
    "Stripe Test Key": r"sk_test_[a-zA-Z0-9]{20,}",
    "AWS Access Key": r"AKIA[0-9A-Z]{16}",
    "AWS Secret Key": r"aws_secret_access_key\s*[=:]\s*['\"]?[a-zA-Z0-9/+=]{40}['\"]?",
    "Firebase API Key": r"AIza[0-9A-Za-z_-]{35}",
    "Slack Token": r"xox[baprs]-[0-9]{10,13}-[0-9]{10,13}[a-zA-Z0-9-]*",
    "Discord Token": r"[MN][A-Za-z\d]{23}\.[\w-]{6}\.[\w-]{27}",
    "Private Key": r"-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----",
    "Generic Secret": r"(password|secret|passwd)\s*[=:]\s*['\"][^'\"\n]{8,}['\"]",
    "Bearer Token": r"bearer\s+[a-zA-Z0-9_-]+\.[a-zA-Z0-9_-]+",
    "API Key": r"api[_-]?key\s*[=:]\s*['\"][a-zA-Z0-9]{16,}['\"]",
}

SECRET_FILES = [
    ".env", ".env.local", ".env.production", ".env.development",
    ".pem", ".key", "id_rsa", "id_dsa", "id_ecdsa", "id_ed25519",
    "credentials.json", "service_account.json", "google-services.json"
]

SKIP_DIRS = {".git", "node_modules", "vendor", "target", "build", "dist", ".dart_tool"}


def scan_directory(repo_dir: Path):
    findings = []
    for root, dirs, files in os.walk(repo_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for file in files:
            filepath = Path(root) / file
            try:
                content = filepath.read_text(errors="ignore")
            except Exception:
                continue
            rel_path = filepath.relative_to(repo_dir)
            for pattern_name, pattern in PATTERNS.items():
                for match in re.finditer(pattern, content, re.IGNORECASE):
                    line_num = content[:match.start()].count("\n") + 1
                    snippet = content[max(0, match.start()-20):min(len(content), match.end()+20)]
                    findings.append({
                        "file": str(rel_path),
                        "line": line_num,
                        "type": pattern_name,
                        "match": match.group(),
                        "snippet": snippet.replace("\n", " ")
                    })
            for secret_file in SECRET_FILES:
                if file.endswith(secret_file) or file == secret_file:
                    try:
                        file_content = filepath.read_text(errors="ignore").strip()
                    except Exception:
                        file_content = "[binary or unreadable]"
                    findings.append({
                        "file": str(rel_path),
                        "line": 1,
                        "type": "Secret File",
                        "match": file,
                        "snippet": file_content[:100].replace("\n", " ")
                    })
                    break
    return findings


def scan_github_repos(owner: str, limit: int = 100):
    result = subprocess.run(
        ["gh", "repo", "list", owner, "--visibility", "public", "--limit", str(limit), "--json", "name"],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        print(f"Error listing repos: {result.stderr}", file=sys.stderr)
        sys.exit(1)
    repos = [r["name"] for r in json.loads(result.stdout)]
    all_findings = []
    tmpdir = tempfile.mkdtemp(prefix="gh_audit_")
    for repo in repos:
        repo_dir = Path(tmpdir) / repo
        clone_result = subprocess.run(
            ["git", "clone", "--depth", "1", f"https://github.com/{owner}/{repo}.git", str(repo_dir)],
            capture_output=True, text=True
        )
        if clone_result.returncode != 0:
            continue
        findings = scan_directory(repo_dir)
        for f in findings:
            f["repo"] = repo
        all_findings.extend(findings)
        subprocess.run(["rm", "-rf", str(repo_dir)])
    subprocess.run(["rm", "-rf", tmpdir])
    return all_findings


def main():
    parser = argparse.ArgumentParser(description="Scan repo(s) for sensitive data")
    parser.add_argument("path", nargs="?", help="Path to local git repository")
    parser.add_argument("--github-owner", help="GitHub owner to scan all public repos")
    parser.add_argument("--limit", type=int, default=100, help="Max repos to scan (default 100)")
    parser.add_argument("--json-out", help="Write JSON report to file")
    args = parser.parse_args()

    if args.github_owner:
        findings = scan_github_repos(args.github_owner, args.limit)
    elif args.path:
        findings = scan_directory(Path(args.path))
    else:
        parser.print_help()
        sys.exit(1)

    report = {"findings": findings, "count": len(findings)}
    print(json.dumps(report, indent=2))
    if args.json_out:
        with open(args.json_out, "w") as f:
            json.dump(report, f, indent=2)
    sys.exit(1 if findings else 0)


if __name__ == "__main__":
    main()
