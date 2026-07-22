#!/bin/bash

#SBATCH -C jubail
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00
#SBATCH --output=pigo_3runs_logbatch_er.out
#SBATCH --error=pigo_3runs_logbatch_er.err

# ─────────────────────────────────────────────
# PIGO sweep — 3 sequential full runs, logarithmic batch-size sweep
# (1 to 1,000,000, x10 per step), restricted structure set
# (degAwareRHH and adListChunked skipped), and restricted to the
# 5 mid-to-large datasets — starts at LiveJournal, stops at er.
# wiki-Talk, wiki-topcats, tw, and fs are all excluded.
#
# Run order: for a given run, ALL (dataset, batch size, structure,
# algorithm) combinations complete before the next run starts
# (the "run" loop is the outermost loop).
#
# 5 datasets x 7 batch sizes x 3 structures x 12 algorithms x 3 runs
# = 3,780 total invocations.
#
# Submit this FROM the PIGO branch directory:
#   /scratch/ms13779/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench
# so that $SLURM_SUBMIT_DIR resolves to it and ./frontEnd is the
# PIGO-enabled binary.
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
sagaDir="$SLURM_SUBMIT_DIR"                                    # PIGO branch dir — submit from there
resultsDir="${HOME}/SAGA-Bench/pigo_3runs_logbatch_er"           # distinct from other result dirs
FAILURE_LOG="${resultsDir}/failures.log"
SKIP_LOG="${resultsDir}/skipped.log"

mkdir -p "$resultsDir"
> "$FAILURE_LOG"
> "$SKIP_LOG"

cd "$sagaDir" || exit

# ─────────────────────────────────────────────
# Debug info
# ─────────────────────────────────────────────
echo "Hostname : $(hostname)"
echo "Job ID   : ${SLURM_JOB_ID:-unknown}"
echo "CPUs     : $NUM_THREADS"
echo "Working dir (PIGO branch): $PWD"
echo

# ─────────────────────────────────────────────
# Parameters
# ─────────────────────────────────────────────
NUM_BATCHES=10
RUNS=3

# Logarithmic batch-size sweep: 1, 10, 100, 1000, ..., 1000000
BATCH_SIZES=(1 10 100 1000 10000 100000 1000000)

# ─────────────────────────────────────────────
# Structures under test — degAwareRHH and adListChunked skipped
# ─────────────────────────────────────────────
STRUCTURES=(
    adListShared
    abslBtreeSetShared
    stinger
)

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

# Format: "filename directed total_edges num_vertices"
# Starts at LiveJournal, stops at er — wiki-Talk, wiki-topcats, tw, and fs
# are all intentionally excluded.
DATASETS=(
    "soc-LiveJournal1.txt                   1  68993773   4847571"
    "com-orkut.ungraph.txt                  0  117185083  3072441"
    "rmat.txt                               1  500000000  32118308"
    "co.txt                                 0  234370166  3072627"
    "er.txt                                 0  1000009380 10000000"
)

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
echo " SAGA-Bench PIGO sweep (3 runs, log batch sizes, restricted set)"
echo " Started    : $(date)"
echo " Structures : ${#STRUCTURES[@]}  (${STRUCTURES[*]})"
echo " Algorithms : ${#ALGORITHMS[@]}"
echo " Datasets   : ${#DATASETS[@]}  (LiveJournal .. er, no wiki-Talk/wiki-topcats/tw/fs)"
echo " Batch sizes: ${BATCH_SIZES[*]}"
echo " Runs       : $RUNS  (each run completes fully before the next starts)"
echo " Batches per (dataset,batch size): $NUM_BATCHES"
echo " Threads    : $NUM_THREADS"
echo " Results    : $resultsDir"
echo " Failure log: $FAILURE_LOG"
echo "=============================================="

# ─────────────────────────────────────────────
# Main loop
# run is outermost -> every combination for run N completes before run N+1 begins
# ─────────────────────────────────────────────
for ((run=1; run<=RUNS; run++)); do

    RUN_START=$(date +%s)
    echo
    echo "────────────────────────────────────────────"
    echo " Starting Run $run / $RUNS — $(date)"
    echo "────────────────────────────────────────────"

    for dataset_entry in "${DATASETS[@]}"; do

        read -r dataset directed total_edges num_vertices <<< "$dataset_entry"

        DATASET_PATH="${dataDir}/${dataset}"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo
            echo "WARNING: Dataset not found — skipping: $DATASET_PATH"
            echo "$(date) | MISSING DATASET | Run $run | $dataset" >> "$SKIP_LOG"
            (( SKIPPED_JOBS += ${#BATCH_SIZES[@]} * ${#STRUCTURES[@]} * ${#ALGORITHMS[@]} )) || true
            continue
        fi

        DATASET_START=$(date +%s)
        echo
        echo "Dataset      : $dataset"
        echo "Directed     : $directed"
        echo "Vertices     : $num_vertices"
        echo "Total edges  : $total_edges"

        for BATCH_SIZE in "${BATCH_SIZES[@]}"; do

            INITIAL_BATCH=$(( total_edges - (BATCH_SIZE * NUM_BATCHES) ))
            if [[ $INITIAL_BATCH -lt 0 ]]; then INITIAL_BATCH=0; fi

            BATCH_START=$(date +%s)
            echo
            echo "  ------------------------------------------"
            echo "  Batch size   : $BATCH_SIZE"
            echo "  Initial size : $INITIAL_BATCH"
            echo "  Batches      : $NUM_BATCHES x $BATCH_SIZE"
            echo "  ------------------------------------------"

            for structure in "${STRUCTURES[@]}"; do

                STRUCT_START=$(date +%s)

                for alg_entry in "${ALGORITHMS[@]}"; do

                    read -r algorithm weighted <<< "$alg_entry"

                    (( TOTAL_JOBS++ )) || true

                    rm -f Alg*.csv Update*.csv

                    echo
                    echo "[Run $run] b=$BATCH_SIZE | $structure | $algorithm | weighted=$weighted"
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
                        echo "$(date) | FAILED | Run $run | $dataset | b=$BATCH_SIZE | $structure | $algorithm | $(( ALGO_END - ALGO_START ))s" >> "$FAILURE_LOG"
                        (( FAILED_JOBS++ )) || true
                        rm -f Alg*.csv Update*.csv
                        continue
                    fi

                    ALGO_END=$(date +%s)
                    echo "Completed in $(( ALGO_END - ALGO_START ))s"
                    (( PASSED_JOBS++ )) || true

                    RUN_TAG="run${run}_${dataset}_b${BATCH_SIZE}_${structure}_${algorithm}"
                    DIRECTORY="${resultsDir}/${algorithm}/${structure}/${dataset}/b${BATCH_SIZE}/Run${run}"
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
                echo "  Structure $structure (b=$BATCH_SIZE) completed in $(( STRUCT_END - STRUCT_START ))s"

            done  # structure

            BATCH_END=$(date +%s)
            BATCH_TIME=$(( BATCH_END - BATCH_START ))
            echo
            echo "  Batch size $BATCH_SIZE finished in $(( BATCH_TIME / 60 ))m $(( BATCH_TIME % 60 ))s"

        done  # batch size

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