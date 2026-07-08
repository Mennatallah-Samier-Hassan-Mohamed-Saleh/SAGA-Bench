#!/bin/bash

#SBATCH -c 1
#SBATCH -t 24:00:00
#SBATCH --output=single_threaded_all_algorithms_test.out
#SBATCH --error=single_threaded_all_algorithms_test.err

set -uo pipefail
# NOTE: 'set -e' intentionally omitted — a failing frontEnd run must not
# kill the whole job. Failures are caught explicitly below, logged, and
# the script moves on to the next run.

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
rm -f Update.csv Alg.csv failures.log skipped.log successes.log

# Per-run wall-clock cap so a hung run (e.g. the prfromscratch/abslBtreeSet
# 14h hang) can never again stall the whole job. Adjust as needed.
TIMEOUT="30m"

FAIL_COUNT=0
SKIP_COUNT=0
TOTAL_COUNT=0
declare -a SUCCESS_RUNS=()
declare -a FAILED_RUNS=()
declare -a SKIPPED_RUNS=()

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=1

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

export sagaDir=$SLURM_SUBMIT_DIR
cd "$sagaDir" || exit
echo "Working directory: $PWD"

# ─────────────────────────────────────────────
# Runs to skip: "dataset,structure,algorithm"
# slashdot|abslBtreeSet|prfromscratch is known to hang indefinitely
# (observed stuck for 14h in a prior run) — skip it explicitly.
# ─────────────────────────────────────────────
declare -A SKIP_RUNS=(
    [slashdot,abslBtreeSet,prfromscratch]=1
)

# ─────────────────────────────────────────────
# Algorithms: value = weighted (0=unweighted, 1=weighted)
# ─────────────────────────────────────────────
declare -A ALGORITHMS=(
    [traverse]=0
    [prfromscratch]=0
    [prdyn]=0
    [ccfromscratch]=0
    [ccdyn]=0
    [mcfromscratch]=0
    [mcdyn]=0
    [bfsfromscratch]=0
    [bfsdyn]=0
    [ssspfromscratch]=1
    [ssspdyn]=1
    [sswpfromscratch]=1
    [sswpdyn]=1
)

# ─────────────────────────────────────────────
# Dataset registry
# Format: "filepath directed num_nodes total_edges batch_size num_batches"
# ─────────────────────────────────────────────
declare -A DATASETS=(
    [facebook]="$SCRATCH/datasets/SAGAdatasets/facebook.csv        0  4039   88234    1000  10"
    [slashdot]="$SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.txt        1  82168  948464   1000  10"
)

# ─────────────────────────────────────────────
# Structures under test
# ─────────────────────────────────────────────
STRUCTURES=(
    adList
    adListShared
    adListChunked
    degAwareRHH
    stinger
    abslBtreeSet
    abslBtreeSetShared
)

# ─────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────
for ds_name in facebook slashdot; do

    read -r filepath directed num_nodes total_edges batch_size num_batches \
        <<< "${DATASETS[$ds_name]}"

    INITIAL_BATCH=$(( total_edges - batch_size * num_batches ))
    if [[ $INITIAL_BATCH -lt 0 ]]; then INITIAL_BATCH=0; fi

    echo "=========================================="
    echo " Dataset: $ds_name"
    echo "=========================================="
    echo " File:          $filepath"
    echo " Directed:      $directed"
    echo " Nodes:         $num_nodes"
    echo " Total edges:   $total_edges"
    echo " Batch size:    $batch_size"
    echo " Num batches:   $num_batches"
    echo " Initial batch: $INITIAL_BATCH"
    echo " Threads:       $OMP_NUM_THREADS"
    echo "=========================================="
    echo ""

    for STRUCTURE in "${STRUCTURES[@]}"; do

        echo "------------------------------------------"
        echo " Structure: $STRUCTURE"
        echo "------------------------------------------"
        echo ""

        for algorithm in "${!ALGORITHMS[@]}"; do

            weighted=${ALGORITHMS[$algorithm]}
            run_id="$ds_name | $STRUCTURE | $algorithm"

            # ─── Skip check ───
            if [[ -n "${SKIP_RUNS[$ds_name,$STRUCTURE,$algorithm]+x}" ]]; then
                SKIP_COUNT=$((SKIP_COUNT + 1))
                SKIPPED_RUNS+=("$run_id")
                echo ">>> Skipping: $STRUCTURE | $algorithm (in skip list — known to hang)"
                echo "$ds_name,$STRUCTURE,$algorithm,weighted=$weighted" >> skipped.log
                echo ""
                continue
            fi

            echo ">>> Starting: $STRUCTURE | $algorithm | weighted=$weighted"

            rm -f Alg.csv Update.csv
            echo ">>> CMD: timeout $TIMEOUT ./frontEnd -d $directed -w $weighted -f $filepath -b $batch_size -s $STRUCTURE -a $algorithm -t $OMP_NUM_THREADS -i $INITIAL_BATCH -v 0"
            TOTAL_COUNT=$((TOTAL_COUNT + 1))

            if timeout "$TIMEOUT" ./frontEnd \
                -d "$directed"      \
                -w "$weighted"      \
                -f "$filepath"      \
                -b "$batch_size"    \
                -s "$STRUCTURE"     \
                -a "$algorithm"     \
                -t "$OMP_NUM_THREADS" \
                -i "$INITIAL_BATCH" \
                -v 1 \
                > "${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_single.out" \
                2> "${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_single.err"
            then
                echo "<<< Done: $STRUCTURE | $algorithm"
                SUCCESS_RUNS+=("$run_id")
                echo "$ds_name,$STRUCTURE,$algorithm,weighted=$weighted" >> successes.log
            else
                exit_code=$?
                FAIL_COUNT=$((FAIL_COUNT + 1))
                if [[ $exit_code -eq 124 ]]; then
                    reason="TIMEOUT (>$TIMEOUT)"
                else
                    reason="exit code $exit_code"
                fi
                FAILED_RUNS+=("$run_id ($reason)")
                echo "!!! FAILED: $ds_name | $STRUCTURE | $algorithm — $reason — see ${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_single.err"
                echo "$ds_name,$STRUCTURE,$algorithm,weighted=$weighted,$reason" >> failures.log
                echo "<<< Continuing to next run..."
            fi

            rm -f Alg.csv Update.csv

            echo ""

        done

        echo "------------------------------------------"
        echo " $ds_name — $STRUCTURE — all algorithms complete"
        echo "------------------------------------------"
        echo ""

    done

    echo "=========================================="
    echo " $ds_name — all structures & algorithms complete"
    echo "=========================================="
    echo ""

done

echo "=========================================="
echo " All datasets, structures, and tests complete!"
echo "=========================================="
echo " Total attempted: $TOTAL_COUNT"
echo " Succeeded:        ${#SUCCESS_RUNS[@]}"
echo " Failed:            $FAIL_COUNT"
echo " Skipped:           $SKIP_COUNT"
echo "=========================================="
echo ""
echo "----- SUCCESSFUL RUNS (${#SUCCESS_RUNS[@]}) -----"
if [[ ${#SUCCESS_RUNS[@]} -gt 0 ]]; then
    for r in "${SUCCESS_RUNS[@]}"; do echo "  OK      $r"; done
else
    echo "  (none)"
fi
echo ""
echo "----- FAILED RUNS (${#FAILED_RUNS[@]}) -----"
if [[ ${#FAILED_RUNS[@]} -gt 0 ]]; then
    for r in "${FAILED_RUNS[@]}"; do echo "  FAILED  $r"; done
    echo ""
    echo "  Full failure log (failures.log):"
    cat failures.log
else
    echo "  (none)"
fi
echo ""
echo "----- SKIPPED RUNS (${#SKIPPED_RUNS[@]}) -----"
if [[ ${#SKIPPED_RUNS[@]} -gt 0 ]]; then
    for r in "${SKIPPED_RUNS[@]}"; do echo "  SKIPPED $r"; done
else
    echo "  (none)"
fi
echo "=========================================="