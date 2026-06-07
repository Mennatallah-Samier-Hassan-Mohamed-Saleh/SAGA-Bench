#!/bin/bash

#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00
#SBATCH --output=paper_baseline.out
#SBATCH --error=paper_baseline.err

set -euo pipefail

# ─────────────────────────────────────────────
# Guards
# ─────────────────────────────────────────────
: "${SCRATCH:?ERROR: SCRATCH is not set — is SLURM loaded?}"

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

# Dynamic assignment from SLURM allocation, fallback to 128
NUM_THREADS=${SLURM_CPUS_PER_TASK:-128}

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# ─────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────
dataDir="/scratch/ms13779/datasets/SAGAdatasets"
sagaDir="${SCRATCH}/Masters_thesis/Thesis/SAGA-Bench"
resultsDir="${HOME}/SAGA-Bench/paper_baseline"

cd "$sagaDir"

if [[ ! -x "./frontEnd" ]]; then
    echo "ERROR: frontEnd executable not found or not executable in $sagaDir"
    exit 1
fi

# ─────────────────────────────────────────────
# Debug info
# ─────────────────────────────────────────────
echo "Hostname : $(hostname)"
echo "Job ID   : ${SLURM_JOB_ID:-unknown}"
echo "CPUs     : $NUM_THREADS"
echo

# ─────────────────────────────────────────────
# Parameters
# ─────────────────────────────────────────────
BATCH_SIZE=100000
NUM_BATCHES=10
RUNS=3

# ─────────────────────────────────────────────
# Execution order — fastest to slowest
# ─────────────────────────────────────────────

# Data structures: fastest to slowest
STRUCTURES=(
    adListShared
    abslBtreeSetShared
    stinger
    adListChunked
    degAwareRHH
)

# Algorithms: incremental first (faster), then fromscratch (slower)
# weighted flag: 0=unweighted, 1=weighted
# Format: "name weighted"
ALGORITHMS=(
    "bfsdyn          0"
    "ccdyn           0"
    "sswpdyn         1"
    "ssspdyn         1"
    "prdyn           0"
    "mcdyn           0"
    "bfsfromscratch  0"
    "ccfromscratch   0"
    "sswpfromscratch 1"
    "ssspfromscratch 1"
    "prfromscratch   0"
    "mcfromscratch   0"
)

# Datasets: smallest to largest (fastest to slowest)
# Format: "filename directed total_edges num_vertices"
DATASETS=(
    "wiki-Talk.shuffle.t.w.csv              1  5021410    2394385"
    "wiki-topcats.shuffle.t.w.csv           1  28511807   1791489"
    "soc-LiveJournal1.shuffle.t.w.csv       1  68993773   4847571"
    "com-orkut.ungraph.shuffle.t.w.csv      0  117185083  3072441"
    "rmat.shuffle.t.w.csv                   1  500000000  32118308"
    "co.shuffle.t.w.csv                     0  234370166  3072627"
    "er.shuffle.t.w.csv                     0  1000009380 10000000"
    "tw.shuffle.t.w.csv                     0  2405026092 61578415"
    "fs.shuffle.t.w.csv                     0  3612134270 124836180"
)

# ─────────────────────────────────────────────
# Experiment start
# ─────────────────────────────────────────────
EXPERIMENT_START=$(date +%s)

echo "=============================================="
echo " SAGA-Bench paper baseline"
echo " Started    : $(date)"
echo " Structures : ${#STRUCTURES[@]}"
echo " Algorithms : ${#ALGORITHMS[@]}"
echo " Datasets   : ${#DATASETS[@]}"
echo " Runs       : $RUNS"
echo " Batch size : $BATCH_SIZE"
echo " Batches    : $NUM_BATCHES"
echo " Threads    : $NUM_THREADS"
echo " Results    : $resultsDir"
echo "=============================================="

# ─────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────
for ((run=1; run<=RUNS; run++)); do

    RUN_START=$(date +%s)
    echo
    echo "────────────────────────────────────────────"
    echo " Starting Run $run / $RUNS — $(date)"
    echo "────────────────────────────────────────────"

    for dataset_entry in "${DATASETS[@]}"; do

        # Parse dataset fields
        read -r dataset directed total_edges num_vertices <<< "$dataset_entry"

        INITIAL_BATCH=$(( total_edges - (BATCH_SIZE * NUM_BATCHES) ))
        if [[ $INITIAL_BATCH -lt 0 ]]; then INITIAL_BATCH=0; fi

        DATASET_PATH="${dataDir}/${dataset}"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo "ERROR: Dataset not found:"
            echo "  $DATASET_PATH"
            exit 1
        fi

        DATASET_START=$(date +%s)
        echo
        echo "Dataset      : $dataset"
        echo "Directed     : $directed"
        echo "Vertices     : $num_vertices"
        echo "Total edges  : $total_edges"
        echo "Initial size : $INITIAL_BATCH"
        echo "Batches      : $NUM_BATCHES x $BATCH_SIZE"

        for structure in "${STRUCTURES[@]}"; do

            STRUCT_START=$(date +%s)

            for alg_entry in "${ALGORITHMS[@]}"; do

                # Parse algorithm name and weighted flag
                read -r algorithm weighted <<< "$alg_entry"

                rm -f Alg*.csv Update*.csv

                echo
                echo "[Run $run] $structure | $algorithm | weighted=$weighted"
                echo "./frontEnd \
-d $directed \
-w $weighted \
-f $DATASET_PATH \
-b $BATCH_SIZE \
-s $structure \
-a $algorithm \
-t $NUM_THREADS \
-n $num_vertices \
-i $INITIAL_BATCH"

                ALGO_START=$(date +%s)

                if ! ./frontEnd \
                    -d "$directed"      \
                    -w "$weighted"      \
                    -f "$DATASET_PATH"  \
                    -b "$BATCH_SIZE"    \
                    -s "$structure"     \
                    -a "$algorithm"     \
                    -t "$NUM_THREADS"   \
                    -n "$num_vertices"  \
                    -i "$INITIAL_BATCH"
                then
                    echo
                    echo "ERROR: frontEnd failed"
                    echo "  Dataset   : $dataset"
                    echo "  Structure : $structure"
                    echo "  Algorithm : $algorithm"
                    exit 1
                fi

                ALGO_END=$(date +%s)
                echo "Completed in $(( ALGO_END - ALGO_START ))s"

                # Move output CSVs into labelled directory
                RUN_TAG="run${run}_${dataset}_${structure}_${algorithm}"
                DIRECTORY="${resultsDir}/${algorithm}/${structure}/${dataset}/Run${run}"
                mkdir -p "$DIRECTORY"

                for f in Alg*.csv; do
                    [[ -f "$f" ]] && mv "$f" "${DIRECTORY}/${RUN_TAG}_$(basename "$f")"
                done
                for f in Update*.csv; do
                    [[ -f "$f" ]] && mv "$f" "${DIRECTORY}/${RUN_TAG}_$(basename "$f")"
                done

            done  # algorithm

            STRUCT_END=$(date +%s)
            echo
            echo "Structure $structure completed in $(( STRUCT_END - STRUCT_START ))s"

        done  # structure

        DATASET_END=$(date +%s)
        DATASET_TIME=$(( DATASET_END - DATASET_START ))
        echo
        echo "Dataset $dataset finished in $(( DATASET_TIME / 60 ))m $(( DATASET_TIME % 60 ))s"

    done  # dataset

    RUN_END=$(date +%s)
    RUN_TIME=$(( RUN_END - RUN_START ))
    echo
    echo "Run $run completed in $(( RUN_TIME / 60 ))m $(( RUN_TIME % 60 ))s"

done  # run

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
EXPERIMENT_END=$(date +%s)
TOTAL=$(( EXPERIMENT_END - EXPERIMENT_START ))

echo
echo "=============================================="
echo " ALL RUNS COMPLETE"
echo " Total time : $(( TOTAL / 3600 ))h $(( (TOTAL % 3600) / 60 ))m $(( TOTAL % 60 ))s"
echo " Finished   : $(date)"
echo " Results    : $resultsDir"
echo "=============================================="