#!/bin/bash

#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00
#SBATCH --output=paper_baseline_resume.out
#SBATCH --error=paper_baseline_resume.err

# ─────────────────────────────────────────────
# RESUME SCRIPT (1st resume — 428 / 540 runs completed before the
# original job hit the 7-day walltime)
# Picks up at:
#   dataset   = tw.shuffle.t.w.csv
#   structure = adListShared          (first structure for tw)
#   algorithm = ssspdyn               (4th algorithm; bfsdyn, ccdyn,
#                                       sswpdyn already completed for
#                                       tw/adListShared — ssspdyn itself
#                                       did NOT finish and is rerun)
#
# Everything before that (wiki-Talk, wiki-topcats, soc-LiveJournal1,
# com-orkut, rmat, co, er — all structures/algorithms) plus bfsdyn,
# ccdyn, sswpdyn for tw/adListShared is assumed DONE and skipped.
#
# After the resumed (dataset, structure) pair, the script falls back to
# running full structure/algorithm lists as normal — so the rest of
# adListShared, the remaining 4 structures of tw, and all of fs are run
# in full.
# ─────────────────────────────────────────────

# ─────────────────────────────────────────────
# Environment setup
# ─────────────────────────────────────────────
unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

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
resultsDir="${HOME}/SAGA-Bench/paper_baseline"        # same results dir as before — do NOT wipe it
FAILURE_LOG="${resultsDir}/failures_resume.log"
SKIP_LOG="${resultsDir}/skipped_resume.log"

mkdir -p "$resultsDir"
> "$FAILURE_LOG"
> "$SKIP_LOG"

cd "$sagaDir"

# Clean up any leftover partial output from the killed run
rm -f Alg*.csv Update*.csv

# ─────────────────────────────────────────────
# Debug info
# ─────────────────────────────────────────────
echo "Hostname : $(hostname)"
echo "Job ID   : ${SLURM_JOB_ID:-unknown}"
echo "CPUs     : $NUM_THREADS"
echo "RESUMING at dataset=tw.shuffle.t.w.csv structure=adListShared algorithm=ssspdyn"
echo

# ─────────────────────────────────────────────
# Parameters
# ─────────────────────────────────────────────
BATCH_SIZE=100000
NUM_BATCHES=10
RUNS=1

# ─────────────────────────────────────────────
# Full ordered lists (same as original script)
# ─────────────────────────────────────────────

STRUCTURES=(
    adListShared
    abslBtreeSetShared
    stinger
    adListChunked
    degAwareRHH
)

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
# Resume slicing
# ─────────────────────────────────────────────
# Index of tw.shuffle.t.w.csv in DATASETS (0-based) = 7
RESUME_DATASET_IDX=7
# Index of adListShared in STRUCTURES (0-based) = 0
RESUME_STRUCTURE_IDX=0
# Index of ssspdyn in ALGORITHMS (0-based) = 3
RESUME_ALGORITHM_IDX=3

DATASETS=("${DATASETS[@]:$RESUME_DATASET_IDX}")   # -> tw, fs

# Counters
TOTAL_JOBS=0
FAILED_JOBS=0
SKIPPED_JOBS=0
PASSED_JOBS=0

# ─────────────────────────────────────────────
# Experiment start
# ─────────────────────────────────────────────
EXPERIMENT_START=$(date +%s)

echo "=============================================="
echo " SAGA-Bench paper baseline — RESUME RUN"
echo " Started    : $(date)"
echo " Datasets   : ${#DATASETS[@]} (${DATASETS[@]%% *})"
echo " Runs       : $RUNS"
echo " Batch size : $BATCH_SIZE"
echo " Batches    : $NUM_BATCHES"
echo " Threads    : $NUM_THREADS"
echo " Results    : $resultsDir"
echo " Failure log: $FAILURE_LOG"
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

    first_dataset=true

    for dataset_entry in "${DATASETS[@]}"; do

        read -r dataset directed total_edges num_vertices <<< "$dataset_entry"

        INITIAL_BATCH=$(( total_edges - (BATCH_SIZE * NUM_BATCHES) ))
        if [[ $INITIAL_BATCH -lt 0 ]]; then INITIAL_BATCH=0; fi

        DATASET_PATH="${dataDir}/${dataset}"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo
            echo "WARNING: Dataset not found — skipping: $DATASET_PATH"
            echo "$(date) | MISSING DATASET | Run $run | $dataset" >> "$SKIP_LOG"
            (( SKIPPED_JOBS += ${#STRUCTURES[@]} * ${#ALGORITHMS[@]} )) || true
            first_dataset=false
            continue
        fi

        DATASET_START=$(date +%s)
        echo
        echo "Dataset      : $dataset"
        echo "Directed     : $directed"
        echo "Vertices     : $num_vertices"
        echo "Total edges  : $total_edges"
        echo "Initial size : $INITIAL_BATCH"
        echo "Batches      : $NUM_BATCHES x $BATCH_SIZE"

        # Only the very first (resumed) dataset gets a sliced structure list
        if $first_dataset; then
            STRUCT_LIST=("${STRUCTURES[@]:$RESUME_STRUCTURE_IDX}")
        else
            STRUCT_LIST=("${STRUCTURES[@]}")
        fi

        first_structure=true

        for structure in "${STRUCT_LIST[@]}"; do

            STRUCT_START=$(date +%s)

            # Only the very first structure of the very first (resumed)
            # dataset gets a sliced algorithm list
            if $first_dataset && $first_structure; then
                ALG_LIST=("${ALGORITHMS[@]:$RESUME_ALGORITHM_IDX}")
            else
                ALG_LIST=("${ALGORITHMS[@]}")
            fi

            for alg_entry in "${ALG_LIST[@]}"; do

                read -r algorithm weighted <<< "$alg_entry"

                (( TOTAL_JOBS++ )) || true

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
                    ALGO_END=$(date +%s)
                    echo
                    echo "WARNING: frontEnd failed — continuing to next job"
                    echo "$(date) | FAILED | Run $run | $dataset | $structure | $algorithm | $(( ALGO_END - ALGO_START ))s" >> "$FAILURE_LOG"
                    (( FAILED_JOBS++ )) || true
                    rm -f Alg*.csv Update*.csv
                    continue
                fi

                ALGO_END=$(date +%s)
                echo "Completed in $(( ALGO_END - ALGO_START ))s"
                (( PASSED_JOBS++ )) || true

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

            first_structure=false

        done  # structure

        DATASET_END=$(date +%s)
        DATASET_TIME=$(( DATASET_END - DATASET_START ))
        echo
        echo "Dataset $dataset finished in $(( DATASET_TIME / 60 ))m $(( DATASET_TIME % 60 ))s"

        first_dataset=false

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
echo " RESUME RUN COMPLETE"
echo " Total time  : $(( TOTAL / 3600 ))h $(( (TOTAL % 3600) / 60 ))m $(( TOTAL % 60 ))s"
echo " Finished    : $(date)"
echo " Results     : $resultsDir"
echo "----------------------------------------------"
echo " Jobs passed : $PASSED_JOBS / $TOTAL_JOBS"
echo " Jobs failed : $FAILED_JOBS / $TOTAL_JOBS"
echo " Jobs skipped: $SKIPPED_JOBS (missing datasets)"
echo "----------------------------------------------"

if [[ -s "$SKIP_LOG" ]]; then
    echo " SKIPPED DATASETS ($(wc -l < "$SKIP_LOG") entries):"
    cat "$SKIP_LOG"
    echo
fi

if [[ -s "$FAILURE_LOG" ]]; then
    echo " FAILURES ($(wc -l < "$FAILURE_LOG") entries):"
    cat "$FAILURE_LOG"
else
    echo " No failures recorded."
fi

echo "=============================================="
exit 0
