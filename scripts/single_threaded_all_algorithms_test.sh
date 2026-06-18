#!/bin/bash

#SBATCH -c 1
#SBATCH -t 24:00:00
#SBATCH --output=single_threaded_all_algorithms_test.out
#SBATCH --error=single_threaded_all_algorithms_test.err

set -euo pipefail

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
rm -f Update.csv Alg.csv

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=1

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
    [slashdot]="$SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.clean.noself.txt        1  82168  948464   1000  10"
)

# ─────────────────────────────────────────────
# Structure under test
# ─────────────────────────────────────────────
STRUCTURE="abslBtreeSetShared"

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
    echo " Structure:     $STRUCTURE"
    echo " Directed:      $directed"
    echo " Nodes:         $num_nodes"
    echo " Total edges:   $total_edges"
    echo " Batch size:    $batch_size"
    echo " Num batches:   $num_batches"
    echo " Initial batch: $INITIAL_BATCH"
    echo " Threads:       $OMP_NUM_THREADS"
    echo "=========================================="
    echo ""

    for algorithm in "${!ALGORITHMS[@]}"; do

        weighted=${ALGORITHMS[$algorithm]}

        echo ">>> Starting: $algorithm | weighted=$weighted"

        rm -f Alg.csv Update.csv
        echo ">>> CMD: ./frontEnd -d $directed -w $weighted -f $filepath -b $batch_size -s $STRUCTURE -a $algorithm -t $OMP_NUM_THREADS -i $INITIAL_BATCH -v 0"
        if ! ./frontEnd \
            -d "$directed"      \
            -w "$weighted"      \
            -f "$filepath"      \
            -b "$batch_size"    \
            -s "$STRUCTURE"     \
            -a "$algorithm"     \
            -t "$OMP_NUM_THREADS" \
            -i "$INITIAL_BATCH" \
            -v 1 \
            > "${ds_name}_${algorithm}_b${batch_size}_single.out" \
            2> "${ds_name}_${algorithm}_b${batch_size}_single.err"
        then
            echo "ERROR: frontEnd failed — $ds_name | $algorithm"
            exit 1
        fi

        rm -f Alg.csv Update.csv

        echo "<<< Done: $algorithm"
        echo ""

    done

    echo "=========================================="
    echo " $ds_name — all algorithms complete"
    echo "=========================================="
    echo ""

done

echo "=========================================="
echo " All datasets and tests complete!"
echo "=========================================="