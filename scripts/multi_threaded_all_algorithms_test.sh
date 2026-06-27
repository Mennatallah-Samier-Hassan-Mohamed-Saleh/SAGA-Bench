#!/bin/bash

#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00
#SBATCH --output=multi_threaded_all_algorithms_test.out
#SBATCH --error=multi_threaded_all_algorithms_test.err

set -euo pipefail

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES
rm -f Update.csv Alg.csv

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS=${SLURM_CPUS_PER_TASK:-128}

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

export sagaDir=$SLURM_SUBMIT_DIR
cd "$sagaDir" || exit

echo "Hostname       : $(hostname)"
echo "Job ID         : ${SLURM_JOB_ID:-unknown}"
echo "Working dir    : $PWD"
echo "Threads        : $NUM_THREADS"
echo ""

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
    [facebook]="$SCRATCH/datasets/SAGAdatasets/facebook.csv   0  4039   88234   1000  10"
    [slashdot]="$SCRATCH/datasets/SAGAdatasets/slashdot.csv   1  82168  948464  1000  10"
)

# ─────────────────────────────────────────────
# Structure under test
# ─────────────────────────────────────────────
STRUCTURE="adlist"

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
    echo " Threads:       $NUM_THREADS"
    echo "=========================================="
    echo ""

    for algorithm in "${!ALGORITHMS[@]}"; do

        weighted=${ALGORITHMS[$algorithm]}

        echo ">>> Starting: $algorithm | weighted=$weighted"

        rm -f Alg.csv Update.csv

        if ! ./frontEnd \
            -d "$directed"      \
            -w "$weighted"      \
            -f "$filepath"      \
            -b "$batch_size"    \
            -s "$STRUCTURE"     \
            -n "$num_nodes"     \
            -a "$algorithm"     \
            -t "$NUM_THREADS"   \
            -i "$INITIAL_BATCH" \
            -v 1 \
            > "${ds_name}_${algorithm}_b${batch_size}_mt${NUM_THREADS}.out" \
            2> "${ds_name}_${algorithm}_b${batch_size}_mt${NUM_THREADS}.err"
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