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

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=128
export OMP_PROC_BIND=close
export OMP_PLACES=cores

# ─────────────────────────────────────────────
# Paths
# ─────────────────────────────────────────────
dataDir="/scratch/ms13779/datasets/SAGAdatasets/"
sagaDir="${SCRATCH}/Masters_thesis/Thesis/SAGA-Bench"
resultsDir="${HOME}/SAGA-Bench/paper_baseline"

cd "$sagaDir"

if [[ ! -x "./frontEnd" ]]; then
    echo "ERROR: frontEnd executable not found or not executable in $sagaDir"
    exit 1
fi

# ─────────────────────────────────────────────
# Parameters
# ─────────────────────────────────────────────
STRUCTURES=(adList adListChunked adListShared degAwareRHH stinger abslBtreeSet abslBtreeSetShared)
BATCH_SIZE=100000
NUM_BATCHES=10
RUNS=3
NUM_THREADS=128

# ─────────────────────────────────────────────
# Algorithms: value = weighted flag (0=unweighted, 1=weighted)
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
# Dataset metadata: "DIRECTED TOTAL_EDGES NUM_VERTICES"
# DIRECTED:     1 = directed, 0 = undirected
# INITIAL_BATCH = TOTAL_EDGES - BATCH_SIZE * NUM_BATCHES  (computed at runtime)
# ─────────────────────────────────────────────
declare -A DATASET_META=(
    [wiki-Talk.shuffle.t.w.csv]="1 5021410    2394385"
    [wiki-topcats.shuffle.t.w.csv]="1 28511807  1791489"
    [soc-LiveJournal1.shuffle.t.w.csv]="1 68993773  4847571"
    [com-orkut.ungraph.shuffle.t.w.csv]="0 117185083 3072441"
    [co.shuffle.t.w.csv]="0 234370166               3072627"
    [rmat.shuffle.t.w.csv]="1 500000000             32118308"
    [er.shuffle.t.w.csv]="0 1000009380              10000000"
    [tw.shuffle.t.w.csv]="0 2405026092              61578415"
    [fs.shuffle.t.w.csv]="0 3612134270             124836180"
)

# ─────────────────────────────────────────────
# Sorted keys for reproducibility across runs
# ─────────────────────────────────────────────
DATASETS_SORTED=$(printf "%s\n"  "${!DATASET_META[@]}" | sort)
ALGORITHMS_SORTED=$(printf "%s\n" "${!ALGORITHMS[@]}"  | sort)

# ─────────────────────────────────────────────
# Experiment start
# ─────────────────────────────────────────────
EXPERIMENT_START=$(date +%s)

echo "=============================================="
echo " SAGA-Bench paper baseline — $(date)"
echo " Structures : ${#STRUCTURES[@]}"
echo " Algorithms : ${#ALGORITHMS[@]}"
echo " Datasets   : ${#DATASET_META[@]}"
echo " Runs       : $RUNS"
echo " Batch size : $BATCH_SIZE"
echo " Num batches: $NUM_BATCHES"
echo " Threads    : $NUM_THREADS"
echo " Results    : $resultsDir"
echo "=============================================="

# ─────────────────────────────────────────────
# Main loop
# ─────────────────────────────────────────────
for run in $(seq 1 $RUNS); do

    RUN_START=$(date +%s)
    echo ""
    echo "────────────────────────────────────────────"
    echo " Starting Run $run / $RUNS — $(date)"
    echo "────────────────────────────────────────────"

    for dataset in $DATASETS_SORTED; do

        # Parse dataset metadata
        meta=(${DATASET_META[$dataset]})
        DIRECTED=${meta[0]}
        TOTAL_EDGES=${meta[1]}
        NUM_VERTICES=${meta[2]}
        INITIAL_BATCH=$(( TOTAL_EDGES - BATCH_SIZE * NUM_BATCHES ))
        if (( INITIAL_BATCH < 0 )); then
            INITIAL_BATCH=0
        fi

        DATASET_PATH="${dataDir}${dataset}"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo "ERROR: Dataset not found: $DATASET_PATH"
            exit 1
        fi

        DATASET_START=$(date +%s)
        echo ""
        echo "  ── Dataset     : $dataset"
        echo "     directed    = $DIRECTED"
        echo "     vertices    = $NUM_VERTICES"
        echo "     total edges = $TOTAL_EDGES"
        echo "     initial     = $INITIAL_BATCH"
        echo "     batches     = $NUM_BATCHES x $BATCH_SIZE"

        for structure in "${STRUCTURES[@]}"; do

            STRUCT_START=$(date +%s)

            for algorithm in $ALGORITHMS_SORTED; do

                WEIGHTED=${ALGORITHMS[$algorithm]}

                # Clean up any leftover CSVs from a previous (possibly crashed) run
                rm -f Alg*.csv Update*.csv

                echo "     [Run $run] $structure | $algorithm | weighted=$WEIGHTED"
                echo "./frontEnd -d $DIRECTED -w $WEIGHTED -f $DATASET_PATH \
                -b $BATCH_SIZE -s $structure -a $algorithm \
                -t $NUM_THREADS -n $NUM_VERTICES -i $INITIAL_BATCH"
                
                ALGO_START=$(date +%s)
                ./frontEnd \
                    -d "$DIRECTED"      \
                    -w "$WEIGHTED"      \
                    -f "$DATASET_PATH"  \
                    -b "$BATCH_SIZE"    \
                    -s "$structure"     \
                    -a "$algorithm"     \
                    -t "$NUM_THREADS"   \
                    -n "$NUM_VERTICES"  \
                    -i "$INITIAL_BATCH"

                STATUS=$?
                if [[ $STATUS -ne 0 ]]; then
                    echo "ERROR: frontEnd failed (exit $STATUS) — $structure | $algorithm | $dataset"
                    exit 1
                fi

                ALGO_END=$(date +%s)
                echo "       -> Done in $(( ALGO_END - ALGO_START ))s"

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
            echo "     Structure $structure done in $(( STRUCT_END - STRUCT_START ))s"

        done  # structure

        DATASET_END=$(date +%s)
        DATASET_TIME=$(( DATASET_END - DATASET_START ))
        echo "  Dataset $dataset — Run $run complete in $(( DATASET_TIME / 60 ))m $(( DATASET_TIME % 60 ))s"

    done  # dataset

    RUN_END=$(date +%s)
    RUN_TIME=$(( RUN_END - RUN_START ))
    echo ""
    echo "  Run $run / $RUNS finished in $(( RUN_TIME / 60 ))m $(( RUN_TIME % 60 ))s — $(date)"

done  # run

# ─────────────────────────────────────────────
# Summary
# ─────────────────────────────────────────────
EXPERIMENT_END=$(date +%s)
TOTAL=$(( EXPERIMENT_END - EXPERIMENT_START ))

echo ""
echo "=============================================="
echo " ALL RUNS COMPLETE"
echo " Total time : $(( TOTAL / 3600 ))h $(( (TOTAL % 3600) / 60 ))m $(( TOTAL % 60 ))s"
echo " Finished   : $(date)"
echo " Results in : $resultsDir"
echo "=============================================="