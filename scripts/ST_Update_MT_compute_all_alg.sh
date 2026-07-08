#!/bin/bash

#SBATCH -c 128
#SBATCH -t 7-00:00:00
#SBATCH --output=ST_Update_MT_compute_all_alg.test.out
#SBATCH --error=ST_Update_MT_compute_all_alg.err

set -uo pipefail
# NOTE: 'set -e' intentionally omitted — a failing frontEnd run must not
# kill the whole job. Failures are caught explicitly below, logged, and
# the script moves on to the next run.

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
rm -f Update.csv Alg.csv failures.log

FAIL_COUNT=0
TOTAL_COUNT=0

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=128

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

export sagaDir=$SLURM_SUBMIT_DIR
cd "$sagaDir" || exit
echo "Working directory: $PWD"

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
    abslBtreeSet
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

            echo ">>> Starting: $STRUCTURE | $algorithm | weighted=$weighted"

            rm -f Alg.csv Update.csv
            echo ">>> CMD: ./frontEnd -d $directed -w $weighted -f $filepath -b $batch_size -s $STRUCTURE -a $algorithm -t $OMP_NUM_THREADS -i $INITIAL_BATCH -v 0"
            TOTAL_COUNT=$((TOTAL_COUNT + 1))

            if ./frontEnd \
                -d "$directed"      \
                -w "$weighted"      \
                -f "$filepath"      \
                -b "$batch_size"    \
                -s "$STRUCTURE"     \
                -a "$algorithm"     \
                -t "$OMP_NUM_THREADS" \
                -i "$INITIAL_BATCH" \
                -v 1 \
                > "${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_SU_MC.out" \
                2> "${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_SU_MC.err"
            then
                echo "<<< Done: $STRUCTURE | $algorithm"
            else
                FAIL_COUNT=$((FAIL_COUNT + 1))
                echo "!!! FAILED: $ds_name | $STRUCTURE | $algorithm — see ${ds_name}_${STRUCTURE}_${algorithm}_b${batch_size}_SU_MC.err"
                echo "$ds_name,$STRUCTURE,$algorithm,weighted=$weighted" >> failures.log
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
echo " Total runs:  $TOTAL_COUNT"
echo " Failed runs: $FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 ]]; then
    echo " See failures.log for the list of failed (dataset, structure, algorithm) combos:"
    cat failures.log
fi
echo "=========================================="
