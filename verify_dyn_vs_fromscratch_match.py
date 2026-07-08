#!/usr/bin/env python3
"""
Verify that each "*dyn" and "*fromscratch" algorithm pair produced identical
per-node results, for every (dataset, structure) combination, by stripping
out lines that are *expected* to differ (timings, headers naming the
algorithm/mode) and diffing what's left.

Usage:
    python3 verify_dyn_vs_fromscratch_match.py [results_dir] [--show-diff N]

results_dir defaults to the current directory and is searched (non-recursively)
for files named like:
    <dataset>_<structure>_<algorithm>_b<batch>_single.out

--show-diff N: for mismatches, print up to N differing line-pairs (default 5).
"""

import sys
import re
from pathlib import Path
from collections import defaultdict

STRUCTURES = [
    "abslBtreeSetShared",
    "abslBtreeSet",
    "adListShared",
    "adListChunked",
    "adList",
    "degAwareRHH",
    "stinger",
]

# Lines expected to differ between dyn/fromscratch runs — stripped before
# comparing. Everything else (per-node results, "Updated Batch: N", final
# "numNodes:.. numEdges:.." summary, etc.) is kept and must match exactly.
NOISE_PATTERNS = [
    r"^Time to load graph:.*",
    r"^Time to convert to edgelist:.*",
    r"^Time to shuffle edges:.*",
    r"^Algorithm:.*",
    r"^Running dynamic .*",
    r"^Running .*from scratch.*",
    r"^Source \d+.*",
    r".*Iteration \d+.*",
]
NOISE_RE = [re.compile(p) for p in NOISE_PATTERNS]


def is_noise(line: str) -> bool:
    return any(r.match(line) for r in NOISE_RE)


def parse_filename(path: Path):
    name = path.name
    m = re.match(r"^(.*)_b\d+_single\.out$", name)
    if not m:
        return None
    stem = m.group(1)

    structure = next((s for s in STRUCTURES if f"_{s}_" in stem), None)
    if structure is None:
        return None

    dataset, rest = stem.split(f"_{structure}_", 1)
    algorithm = rest
    return dataset, structure, algorithm


def algo_family_and_variant(algorithm: str):
    if algorithm.endswith("fromscratch"):
        return algorithm[: -len("fromscratch")], "fromscratch"
    if algorithm.endswith("dyn"):
        return algorithm[: -len("dyn")], "dyn"
    return None, None


def load_stripped_lines(path: Path):
    lines = []
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if not is_noise(line):
                lines.append(line)
    return lines


def main():
    results_dir = Path(sys.argv[1]) if len(sys.argv) > 1 and not sys.argv[1].startswith("--") else Path(".")
    show_diff = 5
    if "--show-diff" in sys.argv:
        idx = sys.argv.index("--show-diff")
        show_diff = int(sys.argv[idx + 1])

    if not results_dir.is_dir():
        print(f"ERROR: directory not found: {results_dir}")
        sys.exit(1)

    # pairs[(dataset, structure, family)][variant] = Path
    pairs = defaultdict(dict)

    for path in sorted(results_dir.glob("*_single.out")):
        parsed = parse_filename(path)
        if parsed is None:
            continue
        dataset, structure, algorithm = parsed
        family, variant = algo_family_and_variant(algorithm)
        if family is None:
            continue  # e.g. "traverse" — no dyn/fromscratch pair
        pairs[(dataset, structure, family)][variant] = path

    if not pairs:
        print("No matching *_single.out files found. Check the directory path.")
        sys.exit(1)

    n_match, n_mismatch, n_incomplete = 0, 0, 0
    mismatches = []

    current_ds = None
    for (dataset, structure, family), variants in sorted(pairs.items()):
        if dataset != current_ds:
            current_ds = dataset
            print(f"\n=== Dataset: {dataset} ===")

        dyn_path = variants.get("dyn")
        fs_path = variants.get("fromscratch")

        if dyn_path is None or fs_path is None:
            missing = "fromscratch" if dyn_path else "dyn"
            print(f"  [{structure:20s}] {family:6s}  INCOMPLETE — missing {missing} output file")
            n_incomplete += 1
            continue

        dyn_lines = load_stripped_lines(dyn_path)
        fs_lines = load_stripped_lines(fs_path)

        if dyn_lines == fs_lines:
            print(f"  [{structure:20s}] {family:6s}  MATCH  ({len(dyn_lines)} comparable lines)")
            n_match += 1
        else:
            print(f"  [{structure:20s}] {family:6s}  MISMATCH  "
                  f"(dyn={len(dyn_lines)} lines, fromscratch={len(fs_lines)} lines)")
            n_mismatch += 1
            mismatches.append((dataset, structure, family, dyn_lines, fs_lines, dyn_path, fs_path))

    print("\n" + "=" * 60)
    print(f"Summary: {n_match} match, {n_mismatch} mismatch, {n_incomplete} incomplete "
          f"(total pairs found: {n_match + n_mismatch + n_incomplete})")
    print("=" * 60)

    if mismatches:
        print(f"\nShowing up to {show_diff} differing line(s) per mismatch:\n")
        for dataset, structure, family, dyn_lines, fs_lines, dyn_path, fs_path in mismatches:
            print(f"--- {dataset} | {structure} | {family} ---")
            print(f"    dyn file:         {dyn_path.name}")
            print(f"    fromscratch file: {fs_path.name}")
            shown = 0
            max_len = max(len(dyn_lines), len(fs_lines))
            for i in range(max_len):
                d = dyn_lines[i] if i < len(dyn_lines) else "<no line>"
                s = fs_lines[i] if i < len(fs_lines) else "<no line>"
                if d != s:
                    print(f"    line {i}: dyn=\"{d}\"  !=  fromscratch=\"{s}\"")
                    shown += 1
                    if shown >= show_diff:
                        print("    ...")
                        break
            print()


if __name__ == "__main__":
    main()
