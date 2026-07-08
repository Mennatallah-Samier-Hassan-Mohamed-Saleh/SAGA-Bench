#!/usr/bin/env python3
"""
Quantify the numeric difference between PageRank ("prdyn" vs "prfromscratch")
outputs for every (dataset, structure) pair, instead of just eyeballing a
line-level diff.

For each pair, this parses every "Node N : has PR valueX" line, groups them
into batches (each batch = the block of per-node output printed after one
update-and-run cycle), and compares dyn vs fromscratch batch-by-batch.

Reports, per (dataset, structure), and per batch:
    - max / mean absolute difference
    - max / mean relative difference (|diff| / |fromscratch_value|)
    - how many nodes exceed configurable abs/rel thresholds

Usage:
    python3 analyze_pr_differences.py [results_dir] [--abs-thresh X] [--rel-thresh Y]

Defaults: results_dir=".", abs-thresh=1e-4, rel-thresh=0.01 (1%)
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

NODE_LINE_RE = re.compile(r"^Node (\d+) : has PR value(.+)$")
BATCH_START_RE = re.compile(r"^(Running dynamic PR|Running PR from scratch)")


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
    return dataset, structure, rest  # rest = algorithm, e.g. "prdyn"


def parse_batches(path: Path):
    """Return list of dicts {node_id: pr_value} — one dict per batch."""
    batches = []
    current = None
    with open(path, errors="replace") as f:
        for line in f:
            line = line.rstrip("\n")
            if BATCH_START_RE.match(line):
                if current is not None:
                    batches.append(current)
                current = {}
                continue
            m = NODE_LINE_RE.match(line)
            if m and current is not None:
                node_id = int(m.group(1))
                try:
                    val = float(m.group(2))
                except ValueError:
                    continue
                current[node_id] = val
    if current:
        batches.append(current)
    return batches


def compare_batches(dyn_batches, fs_batches, abs_thresh, rel_thresh):
    """Return per-batch stats list and overall aggregate stats."""
    per_batch = []
    all_abs_diffs = []
    all_rel_diffs = []

    n_batches = min(len(dyn_batches), len(fs_batches))
    for b in range(n_batches):
        dyn_vals = dyn_batches[b]
        fs_vals = fs_batches[b]
        common_nodes = set(dyn_vals) & set(fs_vals)

        abs_diffs = []
        rel_diffs = []
        exceed_count = 0
        for n in common_nodes:
            dv, fv = dyn_vals[n], fs_vals[n]
            ad = abs(dv - fv)
            rd = ad / abs(fv) if fv != 0 else (0.0 if ad == 0 else float("inf"))
            abs_diffs.append(ad)
            rel_diffs.append(rd)
            if ad > abs_thresh and rd > rel_thresh:
                exceed_count += 1

        if abs_diffs:
            per_batch.append({
                "batch": b,
                "n_nodes_compared": len(common_nodes),
                "max_abs": max(abs_diffs),
                "mean_abs": sum(abs_diffs) / len(abs_diffs),
                "max_rel": max(rel_diffs),
                "mean_rel": sum(rel_diffs) / len(rel_diffs),
                "n_exceeding_both_thresholds": exceed_count,
            })
            all_abs_diffs.extend(abs_diffs)
            all_rel_diffs.extend(rel_diffs)

    overall = None
    if all_abs_diffs:
        overall = {
            "max_abs": max(all_abs_diffs),
            "mean_abs": sum(all_abs_diffs) / len(all_abs_diffs),
            "max_rel": max(all_rel_diffs),
            "mean_rel": sum(all_rel_diffs) / len(all_rel_diffs),
        }
    return per_batch, overall


def main():
    args = sys.argv[1:]
    results_dir = Path(".")
    abs_thresh = 1e-4
    rel_thresh = 0.01

    positional = [a for a in args if not a.startswith("--")]
    if positional:
        results_dir = Path(positional[0])
    if "--abs-thresh" in args:
        abs_thresh = float(args[args.index("--abs-thresh") + 1])
    if "--rel-thresh" in args:
        rel_thresh = float(args[args.index("--rel-thresh") + 1])

    if not results_dir.is_dir():
        print(f"ERROR: directory not found: {results_dir}")
        sys.exit(1)

    # pairs[(dataset, structure)][variant] = Path
    pairs = defaultdict(dict)
    for path in sorted(results_dir.glob("*_single.out")):
        parsed = parse_filename(path)
        if parsed is None:
            continue
        dataset, structure, algorithm = parsed
        if algorithm == "prdyn":
            pairs[(dataset, structure)]["dyn"] = path
        elif algorithm == "prfromscratch":
            pairs[(dataset, structure)]["fromscratch"] = path

    if not pairs:
        print("No prdyn/prfromscratch output files found.")
        sys.exit(1)

    print(f"Thresholds: abs > {abs_thresh}  AND  rel > {rel_thresh*100:.1f}%  "
          f"(a node must exceed BOTH to be flagged as 'exceeding')\n")

    current_ds = None
    for (dataset, structure), variants in sorted(pairs.items()):
        if dataset != current_ds:
            current_ds = dataset
            print(f"\n=== Dataset: {dataset} ===")

        dyn_path = variants.get("dyn")
        fs_path = variants.get("fromscratch")
        if dyn_path is None or fs_path is None:
            print(f"  [{structure:20s}]  INCOMPLETE — missing a file")
            continue

        dyn_batches = parse_batches(dyn_path)
        fs_batches = parse_batches(fs_path)

        if not dyn_batches or not fs_batches:
            print(f"  [{structure:20s}]  Could not parse PR values from one or both files")
            continue

        per_batch, overall = compare_batches(dyn_batches, fs_batches, abs_thresh, rel_thresh)

        if overall is None:
            print(f"  [{structure:20s}]  No comparable node values found")
            continue

        print(f"  [{structure:20s}]  batches compared: {len(per_batch)}   "
              f"max_abs_diff={overall['max_abs']:.3e}   mean_abs_diff={overall['mean_abs']:.3e}   "
              f"max_rel_diff={overall['max_rel']*100:.3f}%   mean_rel_diff={overall['mean_rel']*100:.3f}%")

        flagged_batches = [b for b in per_batch if b["n_exceeding_both_thresholds"] > 0]
        if flagged_batches:
            print(f"      ⚠ {len(flagged_batches)} batch(es) have nodes exceeding BOTH thresholds:")
            for b in flagged_batches[:3]:
                print(f"        batch {b['batch']}: {b['n_exceeding_both_thresholds']} / "
                      f"{b['n_nodes_compared']} nodes exceed abs>{abs_thresh} and rel>{rel_thresh*100:.1f}%  "
                      f"(max_abs={b['max_abs']:.3e}, max_rel={b['max_rel']*100:.3f}%)")
            if len(flagged_batches) > 3:
                print(f"        ... and {len(flagged_batches) - 3} more batch(es)")


if __name__ == "__main__":
    main()
