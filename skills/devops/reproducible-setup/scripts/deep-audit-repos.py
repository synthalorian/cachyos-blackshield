#!/usr/bin/env python3
"""Deep audit all public GitHub repos for personal config and sensitive data.

Usage:
    python3 deep-audit-repos.py OWNER

Produces JSON report. Pipe through jq or save to file for filtering.
"""
import argparse, json, os, re, subprocess, sys, tempfile, shutil
from pathlib import Path

# Patterns for sensitive data
PATH_PATTERNS = [
    r'\.claw', r'\.claude', r'\.hermes', r'\.config/',
    r'\.ssh/', r'\.gnupg/', r'\.aws/', r'\.kube/',
    r'\.docker/', r'\.npmrc', r'\.pypirc', r'\.netrc',
    r'id_rsa', r'id_ed25519', r'id_ecdsa',
    r'\.pem', r'\.key', r'\.p12', r'\.pfx',
    r'credentials\.json', r'service_account\.json',
    r'google-services\.json', r'GoogleService-Info\.plist',
    r'\.env\.', r'\.env$', r'local\.properties',
    r'keystore\.jks', r'\.keystore',
    r'play-store-credentials\.json',
    r'secret\.json', r'secrets\.json',
    r'tokens\.json', r'auth\.json',
]

CONTENT_PATTERNS = {
    "Home Path": r'/home/[^\s"\'\']+',
    "Email": r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}',
    "GitHub Token": r'gh[pousr]_[a-zA-Z0-9]{36}',
    "OpenAI Key": r'sk-[a-zA-Z0-9]{20,}',
    "Stripe Key": r'sk_(live|test)_[a-zA-Z0-9]{20,}',
    "AWS Key": r'AKIA[0-9A-Z]{16}',
    "Firebase Key": r'AIza[0-9A-Za-z_-]{35}',
    "Slack Token": r'xox[baprs]-[0-9]{10,13}-[0-9]{10,13}',
    "Discord Token": r'[MN][A-Za-z\d]{23}\.[\w-]{6}\.[\w-]{27}',
    "Private Key": r'-----BEGIN (RSA |DSA |EC |OPENSSH )?PRIVATE KEY-----',
    "Bearer Token": r'[Bb]earer\s+[a-zA-Z0-9_\-\.]+',
    "URL with Password": r'https?://[^:]+:[^@]+@[^\s"\'\']+',
}

NOISE_PATTERNS = [
    # Lock files
    r'Cargo\.lock$', r'Gemfile\.lock$', r'package-lock\.json$',
    r'yarn\.lock$', r'Podfile\.lock$',
    # Generated manifests
    r'runner\.exe\.manifest$',
    # Binary/media
    r'\.(png|jpg|jpeg|gif|webp|ico|svg|mp3|wav|ogg|mp4|pdf|zip|tar|gz|exe|dll|so|ttf|otf)$',
    # Standard generated files
    r'\.flutter-plugins-dependencies$',
    r'flutter_export_environment\.sh$',
    r'Flutter-Generated\.xcconfig$',
    r'Generated\.xcconfig$',
    r'CMakeLists\.txt$',
    r'gradlew\.bat$',
    # Build artifacts
    r'node_modules/', r'build/', r'dist/', r'\.dart_tool/',
    r'target/', r'vendor/',
    # Bible data (false positive "bearer")
    r'assets/bible_data/',
    # Standard docs
    r'\.env\.example$',
    r'pre-deploy\.sample$',
    r'CODE_AUDIT_ORIGINAL\.md$',
]

SKIP_DIRS = {".git", "node_modules", "vendor", "target", "build", "dist",
             ".dart_tool", "ios/Pods", "android/.gradle", "android/app/.cxx"}


def is_noise(filepath):
    for pat in NOISE_PATTERNS:
        if re.search(pat, filepath):
            return True
    return False


def is_false_positive(pattern_name, match, snippet):
    fps = [
        ("Email", "example.com"), ("Email", "@example."),
        ("Email", "noreply"), ("Email", "no-reply"),
        ("Home Path", "/home/synth/projects/"),  # Public project paths
        ("Bearer Token", "bearer of"),  # Bible text
        ("Bearer Token", "bearer and"),
        ("Bearer Token", "bearer said"),
        ("Bearer Token", "bearer slew"),
        ("Bearer Token", "bearer made"),
        ("Bearer Token", "bearer were"),
        ("Bearer Token", "bearer would"),
        ("Bearer Token", "bearer saw"),
        ("Bearer Token", "bearer to"),
        ("Bearer Token", "bearer after"),
        ("Bearer Token", "bearer killed"),
        ("Bearer Token", "bearer struck"),
        ("Bearer Token", "bearer went"),
        ("Bearer Token", "bearer refused"),
        ("Bearer Token", "bearer following"),
        ("Bearer Token", "bearer came"),
        ("Bearer Token", "bearer walking"),
        ("Bearer Token", "bearer reveals"),
        ("Bearer Token", "bearer faints."),
        ("Bearer Token", "bearer fainteth."),
        ("Bearer Token", "bearer revealeth"),
        ("Bearer Token", "bearer are"),
        ("Bearer Token", "bearer for"),
        ("Bearer Token", "bearer with"),
        ("Bearer Token", "bearer in"),
        ("Bearer Token", "bearer unto"),
        ("Bearer Token", "bearer first"),
        ("Bearer Token", "bearer upon"),
        ("Bearer Token", "bearer be"),
        ("Bearer Token", "bearer whereof"),
        ("Bearer Token", "bearer before"),
        ("Bearer Token", "bearer wherewith"),
        ("Bearer Token", "bearer stopped"),
        ("Bearer Token", "bearer office"),
        ("Bearer Token", "bearer again"),
        ("Bearer Token", "bearer wrought"),
        ("Bearer Token", "bearer smote"),
        ("Bearer Token", "bearer separateth"),
        ("Bearer Token", "bearer strife"),
        ("Bearer Token", "bearer doth"),
        ("Bearer Token", "bearer faileth"),
        ("Bearer Token", "bearer like"),
        ("Bearer Token", "bearer returned"),
        ("Bearer Token", "bearer is"),
        ("Bearer Token", "bearer this"),
        ("Bearer Token", "bearer to"),
    ]
    for p, fp in fps:
        if p in pattern_name and fp in match:
            return True
    if "YOUR_" in match or ("<" in match and ">" in match):
        return True
    return False


def scan_repo(repo_name, owner, tmpdir):
    repo_dir = Path(tmpdir) / repo_name
    result = subprocess.run(
        ["git", "clone", "--depth", "1", f"https://github.com/{owner}/{repo_name}.git", str(repo_dir)],
        capture_output=True, text=True
    )
    if result.returncode != 0:
        return None

    findings = []
    for root, dirs, files in os.walk(repo_dir):
        dirs[:] = [d for d in dirs if d not in SKIP_DIRS]
        for file in files:
            filepath = Path(root) / file
            rel_path = filepath.relative_to(repo_dir)
            path_str = str(rel_path)

            if is_noise(path_str):
                continue

            # Check path patterns
            for pattern in PATH_PATTERNS:
                if re.search(pattern, path_str, re.IGNORECASE):
                    findings.append({
                        "repo": repo_name, "file": path_str, "line": 0,
                        "type": f"SENSITIVE PATH: {pattern}",
                        "match": path_str, "snippet": ""
                    })

            # Check content
            try:
                content = filepath.read_text(errors="ignore")
            except:
                continue

            for pattern_name, pattern in CONTENT_PATTERNS.items():
                for match in re.finditer(pattern, content):
                    line_num = content[:match.start()].count("\n") + 1
                    snippet = content[max(0, match.start()-30):min(len(content), match.end()+30)]
                    if is_false_positive(pattern_name, match.group(), snippet):
                        continue
                    findings.append({
                        "repo": repo_name, "file": path_str, "line": line_num,
                        "type": pattern_name, "match": match.group(),
                        "snippet": snippet.replace("\n", " ")
                    })

    shutil.rmtree(repo_dir, ignore_errors=True)
    return findings


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("owner", help="GitHub owner/username")
    parser.add_argument("--limit", type=int, default=100)
    parser.add_argument("--json-out", help="Write JSON report to file")
    args = parser.parse_args()

    result = subprocess.run(
        ["gh", "repo", "list", args.owner, "--visibility", "public", "--limit", str(args.limit), "--json", "name"],
        capture_output=True, text=True
    )
    repos = [r["name"] for r in json.loads(result.stdout)]

    tmpdir = tempfile.mkdtemp(prefix="deep_audit_")
    all_findings = []

    for repo in repos:
        print(f"Scanning: {repo}", file=sys.stderr)
        findings = scan_repo(repo, args.owner, tmpdir)
        if findings:
            all_findings.extend(findings)

    shutil.rmtree(tmpdir, ignore_errors=True)

    report = {"findings": all_findings, "count": len(all_findings), "repos_scanned": len(repos)}
    print(json.dumps(report, indent=2))
    if args.json_out:
        with open(args.json_out, "w") as f:
            json.dump(report, f, indent=2)


if __name__ == "__main__":
    main()
