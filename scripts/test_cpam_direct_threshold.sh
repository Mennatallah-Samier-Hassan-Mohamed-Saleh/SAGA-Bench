#!/bin/bash

#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --time=01:00:00
#SBATCH --job-name=cpam_direct_threshold
#SBATCH --output=cpam_direct_threshold_%j.out
#SBATCH --error=cpam_direct_threshold_%j.err

set -u
set -o pipefail

############################################################
# Environment
############################################################

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS="${SLURM_CPUS_PER_TASK:-128}"

export OMP_DISPLAY_ENV=false
export OMP_DYNAMIC=false
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

############################################################
# Project paths
############################################################

SAGA_DIR="${SLURM_SUBMIT_DIR}"
DATA_DIR="/scratch/ms13779/datasets/SAGAdatasets"

cd "$SAGA_DIR" || {
    echo "ERROR: Cannot enter SAGA-Bench directory: $SAGA_DIR" >&2
    exit 1
}

if [[ ! -x ./frontEnd ]]; then
    echo "ERROR: ./frontEnd is missing or not executable in $PWD" >&2
    exit 1
fi

CPAM_HEADER="src/dynamic/cpamSetShared.h"

if [[ ! -f "$CPAM_HEADER" ]]; then
    echo "ERROR: Cannot find $CPAM_HEADER" >&2
    exit 1
fi

############################################################
# Detect the compiled direct-path threshold
############################################################

DIRECT_THRESHOLD=$(
    grep -E \
        'static constexpr std::size_t TINY_BATCH_THRESHOLD[[:space:]]*=' \
        "$CPAM_HEADER" |
    head -n 1 |
    sed -E 's/.*=[[:space:]]*([0-9]+).*/\1/'
)

if [[ -z "$DIRECT_THRESHOLD" ]]; then
    echo "ERROR: Could not detect TINY_BATCH_THRESHOLD." >&2
    exit 1
fi

############################################################
# Test configuration
############################################################

STRUCTURE="cpamSetShared"
ALGORITHM="bfsdyn"
RUNS=1
NUM_DYNAMIC_BATCHES=10

BATCH_SIZES=(
    100
    1000
    10000
    100000
)

# Orkut configuration
DATASET="com-orkut.ungraph.txt"
DIRECTED=0
WEIGHTED=0
TOTAL_EDGES=117185083
NUM_VERTICES=3072441
SOURCE=614483

DATASET_PATH="${DATA_DIR}/${DATASET}"

if [[ ! -f "$DATASET_PATH" ]]; then
    echo "ERROR: Dataset not found: $DATASET_PATH" >&2
    exit 1
fi

############################################################
# Results directory
############################################################

JOB_ID="${SLURM_JOB_ID:-manual}"

RESULTS_DIR="${SAGA_DIR}/cpam_direct_threshold_test/threshold_${DIRECT_THRESHOLD}/job_${JOB_ID}"
SUMMARY_FILE="${RESULTS_DIR}/summary.tsv"
FAILURE_LOG="${RESULTS_DIR}/failures.log"

mkdir -p "$RESULTS_DIR"

: > "$FAILURE_LOG"

printf \
"threshold\tdataset\tbatch\trun\tpath_expected\tinitial_update_s\tremaining_update_avg_s\tinitial_compute_s\tremaining_compute_avg_s\ttotal_runtime_s\tstatus\n" \
> "$SUMMARY_FILE"

############################################################
# Header
############################################################

EXPERIMENT_START=$(date +%s)

echo "============================================================"
echo " CPAM direct-path threshold reduced test"
echo "============================================================"
echo "Job ID             : $JOB_ID"
echo "Hostname           : $(hostname)"
echo "Started            : $(date)"
echo "Working directory  : $PWD"
echo "Results directory  : $RESULTS_DIR"
echo "Threads            : $NUM_THREADS"
echo "Dataset            : $DATASET"
echo "Fixed source       : $SOURCE"
echo "Direct threshold   : $DIRECT_THRESHOLD"
echo "Batch sizes        : ${BATCH_SIZES[*]}"
echo "Dynamic batches    : $NUM_DYNAMIC_BATCHES"
echo "Runs               : $RUNS"
echo "============================================================"

PASSED=0
FAILED=0
TOTAL_CONFIGS=0

############################################################
# Run experiment
############################################################

for ((run=1; run<=RUNS; run++)); do
    for batch_size in "${BATCH_SIZES[@]}"; do
        ((TOTAL_CONFIGS++)) || true

        dynamic_edges=$((batch_size * NUM_DYNAMIC_BATCHES))
        initial_batch=$((TOTAL_EDGES - dynamic_edges))

        if (( initial_batch <= 0 )); then
            echo "ERROR: Invalid initial batch for b=$batch_size" >&2
            ((FAILED++)) || true
            continue
        fi

        if (( batch_size <= DIRECT_THRESHOLD )); then
            expected_path="direct"
        else
            expected_path="sparse"
        fi

        RUN_DIR="${RESULTS_DIR}/${DATASET}/b${batch_size}/Run${run}"
        RUN_LOG="${RUN_DIR}/run.log"

        mkdir -p "$RUN_DIR"

        rm -f Update.csv Alg.csv

        echo
        echo "------------------------------------------------------------"
        echo "Run                 : $run / $RUNS"
        echo "Dataset             : $DATASET"
        echo "Batch size          : $batch_size"
        echo "Initial batch       : $initial_batch"
        echo "Direct threshold    : $DIRECT_THRESHOLD"
        echo "Expected update path: $expected_path"
        echo "Fixed source        : $SOURCE"
        echo "------------------------------------------------------------"

        echo "./frontEnd \
-d $DIRECTED \
-w $WEIGHTED \
-f $DATASET_PATH \
-b $batch_size \
-s $STRUCTURE \
-a $ALGORITHM \
-t $NUM_THREADS \
-n $NUM_VERTICES \
-i $initial_batch \
-r $SOURCE"

        RUN_START=$(date +%s)

        ./frontEnd \
            -d "$DIRECTED" \
            -w "$WEIGHTED" \
            -f "$DATASET_PATH" \
            -b "$batch_size" \
            -s "$STRUCTURE" \
            -a "$ALGORITHM" \
            -t "$NUM_THREADS" \
            -n "$NUM_VERTICES" \
            -i "$initial_batch" \
            -r "$SOURCE" \
            2>&1 | tee "$RUN_LOG"

        FRONTEND_STATUS=${PIPESTATUS[0]}

        RUN_END=$(date +%s)
        TOTAL_RUNTIME=$((RUN_END - RUN_START))

        if (( FRONTEND_STATUS != 0 )); then
            echo "ERROR: frontEnd failed for b=$batch_size" >&2

            printf \
"%s\t%s\t%s\t%s\t%s\tNA\tNA\tNA\tNA\t%s\tFAILED\n" \
                "$DIRECT_THRESHOLD" \
                "$DATASET" \
                "$batch_size" \
                "$run" \
                "$expected_path" \
                "$TOTAL_RUNTIME" \
                >> "$SUMMARY_FILE"

            echo "$(date) | b=$batch_size | Run=$run | exit=$FRONTEND_STATUS" \
                >> "$FAILURE_LOG"

            rm -f Update.csv Alg.csv
            ((FAILED++)) || true
            continue
        fi

        ####################################################
        # Correctness checks
        ####################################################

        STATUS="PASS"

        if ! grep -q "Configured source: $SOURCE" "$RUN_LOG"; then
            echo "ERROR: Fixed source was not confirmed." >&2
            STATUS="SOURCE_ERROR"
        fi

        if ! grep -q "Total batches processed: 11" "$RUN_LOG"; then
            echo "ERROR: Expected 11 batches." >&2
            STATUS="BATCH_ERROR"
        fi

        if [[ ! -f Update.csv ]]; then
            echo "ERROR: Update.csv was not generated." >&2
            STATUS="NO_UPDATE_CSV"
        fi

        if [[ ! -f Alg.csv ]]; then
            echo "ERROR: Alg.csv was not generated." >&2
            STATUS="NO_ALG_CSV"
        fi

        ####################################################
        # Extract timing results
        ####################################################

        INITIAL_UPDATE="NA"
        REMAINING_UPDATE_AVG="NA"
        INITIAL_COMPUTE="NA"
        REMAINING_COMPUTE_AVG="NA"

        if [[ -f Update.csv ]]; then
            INITIAL_UPDATE=$(head -n 1 Update.csv)

            REMAINING_UPDATE_AVG=$(
                tail -n +2 Update.csv |
                awk '
                {
                    sum += $1
                    count++
                }
                END {
                    if (count > 0)
                        printf "%.9f", sum / count
                    else
                        printf "NA"
                }'
            )

            mv Update.csv \
                "${RUN_DIR}/threshold${DIRECT_THRESHOLD}_${DATASET}_b${batch_size}_run${run}_Update.csv"
        fi

        if [[ -f Alg.csv ]]; then
            INITIAL_COMPUTE=$(head -n 1 Alg.csv)

            REMAINING_COMPUTE_AVG=$(
                tail -n +2 Alg.csv |
                awk '
                {
                    sum += $1
                    count++
                }
                END {
                    if (count > 0)
                        printf "%.9f", sum / count
                    else
                        printf "NA"
                }'
            )

            mv Alg.csv \
                "${RUN_DIR}/threshold${DIRECT_THRESHOLD}_${DATASET}_b${batch_size}_run${run}_Alg.csv"
        fi

        printf \
"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
            "$DIRECT_THRESHOLD" \
            "$DATASET" \
            "$batch_size" \
            "$run" \
            "$expected_path" \
            "$INITIAL_UPDATE" \
            "$REMAINING_UPDATE_AVG" \
            "$INITIAL_COMPUTE" \
            "$REMAINING_COMPUTE_AVG" \
            "$TOTAL_RUNTIME" \
            "$STATUS" \
            >> "$SUMMARY_FILE"

        echo
        echo "Result"
        echo "  Initial update        : $INITIAL_UPDATE s"
        echo "  Remaining update avg  : $REMAINING_UPDATE_AVG s"
        echo "  Initial compute       : $INITIAL_COMPUTE s"
        echo "  Remaining compute avg : $REMAINING_COMPUTE_AVG s"
        echo "  Total runtime         : $TOTAL_RUNTIME s"
        echo "  Status                : $STATUS"

        if [[ "$STATUS" == "PASS" ]]; then
            ((PASSED++)) || true
        else
            ((FAILED++)) || true
            echo "$(date) | b=$batch_size | Run=$run | $STATUS" \
                >> "$FAILURE_LOG"
        fi
    done
done

############################################################
# Final output
############################################################

EXPERIMENT_END=$(date +%s)
EXPERIMENT_RUNTIME=$((EXPERIMENT_END - EXPERIMENT_START))

echo
echo "============================================================"
echo " REDUCED TEST COMPLETE"
echo "============================================================"
echo "Finished       : $(date)"
echo "Elapsed        : $((EXPERIMENT_RUNTIME / 3600))h $(((EXPERIMENT_RUNTIME % 3600) / 60))m $((EXPERIMENT_RUNTIME % 60))s"
echo "Threshold      : $DIRECT_THRESHOLD"
echo "Passed         : $PASSED / $TOTAL_CONFIGS"
echo "Failed         : $FAILED / $TOTAL_CONFIGS"
echo "Results        : $RESULTS_DIR"
echo "Summary        : $SUMMARY_FILE"
echo "============================================================"
echo
column -t -s $'\t' "$SUMMARY_FILE"

if [[ -s "$FAILURE_LOG" ]]; then
    echo
    echo "Failures:"
    cat "$FAILURE_LOG"
fi

exit 0
