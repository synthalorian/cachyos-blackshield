#!/usr/bin/env python3
"""Deterministic fastfetch logo/info layout checker.

Runs `fastfetch --pipe false`, strips ANSI, and reports per-row:
  art_end   = last non-space column of the logo region
  textcol   = column where the info text begins
  gap       = textcol - art_end (the "moat" around the logo)
Plus the minimum gap across all rows and the longest line (wrap risk).

Usage: fastfetch-layout-check.py [min_gap]   (default warn threshold: 3)
Exit 1 if any gap < threshold, so it can gate config changes.
"""
import re
import subprocess
import sys

THRESH = int(sys.argv[1]) if len(sys.argv) > 1 else 3

raw = subprocess.run(["fastfetch", "--pipe", "false"],
                     capture_output=True, text=True).stdout
plain = re.sub(r"\x1b\[[0-9;]*m", "", raw)
lines = plain.splitlines()

KEY = re.compile(r"(  [A-Z]+ ▪|^\S+@\S+|▪▪▪▪)")  # info keys, user@host title, separator
worst, longest = 10**9, 0
print(f"{'row':>3} {'art_end':>7} {'textcol':>7} {'gap':>4}")
for i, l in enumerate(lines, 1):
    longest = max(longest, len(l))
    m = KEY.search(l)
    if not m:
        continue
    art_end = len(l[:m.start()].rstrip())
    gap = m.start() - art_end
    worst = min(worst, gap)
    flag = "  <-- TIGHT" if gap < THRESH else ""
    print(f"{i:>3} {art_end:>7} {m.start():>7} {gap:>4}{flag}")

print(f"\nmin gap: {worst if worst < 10**9 else '-'} (threshold {THRESH})")
print(f"longest line: {longest} cols (wrap risk if window narrower)")
sys.exit(0 if worst >= THRESH else 1)
