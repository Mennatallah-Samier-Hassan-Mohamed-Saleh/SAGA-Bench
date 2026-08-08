#!/bin/bash

#SBATCH -C jubail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --time=7-00:00:00
#SBATCH --job-name=lj_source_961292
#SBATCH --output=lj_source_961292_%j.out
#SBATCH --error=lj_source_961292_%j.err

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
# Paths and fixed configuration
############################################################

DATA_DIR="/scratch/ms13779/datasets/SAGAdatasets"
SAGA_DIR="${SLURM_SUBMIT_DIR}"
JOB_ID="${SLURM_JOB_ID:-manual}"

DATASET="soc-LiveJournal1.txt"
DATASET_PATH="${DATA_DIR}/${DATASET}"

DIRECTED=1
TOTAL_EDGES=68993773
NUM_VERTICES=4847571
FIXED_SOURCE=961292

NUM_BATCHES=10
RUNS=1

RESULTS_DIR="${HOME}/SAGA-Bench/lj_source_961292_1run/job_${JOB_ID}"
FAILURE_LOG="${RESULTS_DIR}/failures.log"
SKIP_LOG="${RESULTS_DIR}/skipped.log"
SUMMARY_FILE="${RESULTS_DIR}/runtime_summary.tsv"
CONFIG_FILE="${RESULTS_DIR}/experiment_config.txt"
PROGRESS_LOG="${RESULTS_DIR}/progress.log"

mkdir -p "$RESULTS_DIR"

: > "$FAILURE_LOG"
: > "$SKIP_LOG"
: > "$PROGRESS_LOG"

printf \
"run\tdataset\tbatch_size\tstructure\talgorithm\tweighted\tsource\truntime_seconds\tstatus\n" \
> "$SUMMARY_FILE"

cd "$SAGA_DIR" || {
    echo "ERROR: Cannot enter SAGA-Bench directory: $SAGA_DIR" >&2
    exit 1
}

if [[ ! -x ./frontEnd ]]; then
    echo "ERROR: ./frontEnd is missing or not executable in $PWD" >&2
    exit 1
fi

if [[ ! -f "$DATASET_PATH" ]]; then
    echo "ERROR: Dataset not found: $DATASET_PATH" >&2
    exit 1
fi

############################################################
# Parameters
############################################################

BATCH_SIZES=(
    1
    10
    100
    1000
    10000
    100000
    1000000
)

STRUCTURES=(
    cpamSetShared
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

############################################################
# Counters
############################################################

TOTAL_JOBS=0
PASSED_JOBS=0
FAILED_JOBS=0
SKIPPED_JOBS=0

EXPERIMENT_START=$(date +%s)

############################################################
# Configuration record
############################################################

{
    echo "Job ID          : $JOB_ID"
    echo "Hostname        : $(hostname)"
    echo "Started         : $(date)"
    echo "Working dir     : $PWD"
    echo "Dataset         : $DATASET"
    echo "Dataset path    : $DATASET_PATH"
    echo "Directed        : $DIRECTED"
    echo "Vertices        : $NUM_VERTICES"
    echo "Edges           : $TOTAL_EDGES"
    echo "Fixed source    : $FIXED_SOURCE"
    echo "Threads         : $NUM_THREADS"
    echo "Runs            : $RUNS"
    echo "Dynamic batches : $NUM_BATCHES"
    echo "Batch sizes     : ${BATCH_SIZES[*]}"
    echo "Structure       : ${STRUCTURES[*]}"
    echo "Algorithms      : ${#ALGORITHMS[@]}"
    echo "Results dir     : $RESULTS_DIR"
} > "$CONFIG_FILE"

############################################################
# Header
############################################################

echo "============================================================"
echo " LiveJournal paper rerun with fixed source 961292"
echo "============================================================"
echo "Job ID           : $JOB_ID"
echo "Hostname         : $(hostname)"
echo "Started          : $(date)"
echo "Working dir      : $PWD"
echo "Dataset          : $DATASET"
echo "Directed         : $DIRECTED"
echo "Vertices         : $NUM_VERTICES"
echo "Edges            : $TOTAL_EDGES"
echo "Fixed source     : $FIXED_SOURCE"
echo "Threads          : $NUM_THREADS"
echo "Batch sizes      : ${BATCH_SIZES[*]}"
echo "Algorithms       : ${#ALGORITHMS[@]}"
echo "Expected jobs    : $(( \
    RUNS * \
    ${#BATCH_SIZES[@]} * \
    ${#STRUCTURES[@]} * \
    ${#ALGORITHMS[@]} \
))"
echo "Results          : $RESULTS_DIR"
echo "============================================================"

############################################################
# Main sweep
############################################################

for ((run=1; run<=RUNS; run++)); do

    RUN_START=$(date +%s)

    for BATCH_SIZE in "${BATCH_SIZES[@]}"; do

        DYNAMIC_EDGE_COUNT=$((BATCH_SIZE * NUM_BATCHES))
        INITIAL_BATCH=$((TOTAL_EDGES - DYNAMIC_EDGE_COUNT))

        if (( INITIAL_BATCH <= 0 )); then
            echo "WARNING: Invalid initial batch for b=$BATCH_SIZE"

            SKIPS=$(( \
                ${#STRUCTURES[@]} * \
                ${#ALGORITHMS[@]} \
            ))

            ((SKIPPED_JOBS += SKIPS)) || true

            echo \
"$(date) | INVALID INITIAL BATCH | Run=$run | b=$BATCH_SIZE" \
>> "$SKIP_LOG"

            continue
        fi

        echo
        echo "============================================================"
        echo " Batch size      : $BATCH_SIZE"
        echo " Initial batch   : $INITIAL_BATCH"
        echo " Dynamic batches : $NUM_BATCHES x $BATCH_SIZE"
        echo " Fixed source    : $FIXED_SOURCE"
        echo "============================================================"

        for structure in "${STRUCTURES[@]}"; do

            for alg_entry in "${ALGORITHMS[@]}"; do

                read -r algorithm weighted <<< "$alg_entry"

                ((TOTAL_JOBS++)) || true

                rm -f Alg*.csv Update*.csv

                echo
                echo "------------------------------------------------------------"
                echo "Run        : $run / $RUNS"
                echo "Dataset    : $DATASET"
                echo "Batch      : $BATCH_SIZE"
                echo "Structure  : $structure"
                echo "Algorithm  : $algorithm"
                echo "Weighted   : $weighted"
                echo "Source     : $FIXED_SOURCE"
                echo "------------------------------------------------------------"

                echo "./frontEnd \
-d $DIRECTED \
-w $weighted \
-f $DATASET_PATH \
-b $BATCH_SIZE \
-s $structure \
-a $algorithm \
-t $NUM_THREADS \
-n $NUM_VERTICES \
-i $INITIAL_BATCH \
-r $FIXED_SOURCE"

                ALGORITHM_START=$(date +%s)

                ./frontEnd \
                    -d "$DIRECTED" \
                    -w "$weighted" \
                    -f "$DATASET_PATH" \
                    -b "$BATCH_SIZE" \
                    -s "$structure" \
                    -a "$algorithm" \
                    -t "$NUM_THREADS" \
                    -n "$NUM_VERTICES" \
                    -i "$INITIAL_BATCH" \
                    -r "$FIXED_SOURCE"

                FRONTEND_STATUS=$?

                ALGORITHM_END=$(date +%s)
                ALGORITHM_RUNTIME=$(( \
                    ALGORITHM_END - ALGORITHM_START \
                ))

                if (( FRONTEND_STATUS != 0 )); then
                    echo
                    echo "WARNING: frontEnd failed; continuing."
                    echo "Exit status: $FRONTEND_STATUS"

                    echo \
"$(date) | FAILED | Job=$JOB_ID | Run=$run | Dataset=$DATASET | b=$BATCH_SIZE | Structure=$structure | Algorithm=$algorithm | Source=$FIXED_SOURCE | Exit=$FRONTEND_STATUS | Runtime=${ALGORITHM_RUNTIME}s" \
>> "$FAILURE_LOG"

                    printf \
"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tFAILED\n" \
                        "$run" \
                        "$DATASET" \
                        "$BATCH_SIZE" \
                        "$structure" \
                        "$algorithm" \
                        "$weighted" \
                        "$FIXED_SOURCE" \
                        "$ALGORITHM_RUNTIME" \
                        >> "$SUMMARY_FILE"

                    ((FAILED_JOBS++)) || true

                    rm -f Alg*.csv Update*.csv
                    continue
                fi

                echo "Completed in ${ALGORITHM_RUNTIME}s"

                ((PASSED_JOBS++)) || true

                printf \
"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tPASS\n" \
                    "$run" \
                    "$DATASET" \
                    "$BATCH_SIZE" \
                    "$structure" \
                    "$algorithm" \
                    "$weighted" \
                    "$FIXED_SOURCE" \
                    "$ALGORITHM_RUNTIME" \
                    >> "$SUMMARY_FILE"

                RUN_TAG="job${JOB_ID}_run${run}_${DATASET}_b${BATCH_SIZE}_${structure}_${algorithm}"

                DIRECTORY="${RESULTS_DIR}/${algorithm}/${structure}/${DATASET}/b${BATCH_SIZE}/Run${run}"

                mkdir -p "$DIRECTORY"

                for file in Alg*.csv; do
                    if [[ -f "$file" ]]; then
                        mv "$file" \
                            "${DIRECTORY}/${RUN_TAG}_$(basename "$file")"
                    fi
                done

                for file in Update*.csv; do
                    if [[ -f "$file" ]]; then
                        mv "$file" \
                            "${DIRECTORY}/${RUN_TAG}_$(basename "$file")"
                    fi
                done

                echo \
"$(date) | PASS | Run=$run | b=$BATCH_SIZE | $structure | $algorithm" \
>> "$PROGRESS_LOG"

            done
        done
    done

    RUN_END=$(date +%s)
    RUN_RUNTIME=$((RUN_END - RUN_START))

    echo
    echo "Run $run completed in:"
    echo "$((RUN_RUNTIME / 3600))h $(((RUN_RUNTIME % 3600) / 60))m $((RUN_RUNTIME % 60))s"

done

############################################################
# Final summary
############################################################

EXPERIMENT_END=$(date +%s)
TOTAL_RUNTIME=$((EXPERIMENT_END - EXPERIMENT_START))

echo
echo "============================================================"
echo " LIVEJOURNAL SOURCE-961292 RUN COMPLETE"
echo "============================================================"
echo "Finished       : $(date)"
echo "Total runtime  : $((TOTAL_RUNTIME / 3600))h $(((TOTAL_RUNTIME % 3600) / 60))m $((TOTAL_RUNTIME % 60))s"
echo "Total jobs     : $TOTAL_JOBS"
echo "Passed         : $PASSED_JOBS"
echo "Failed         : $FAILED_JOBS"
echo "Skipped        : $SKIPPED_JOBS"
echo "Results        : $RESULTS_DIR"
echo "Summary        : $SUMMARY_FILE"
echo "Failure log    : $FAILURE_LOG"
echo "Progress log   : $PROGRESS_LOG"
echo "============================================================"

if [[ -s "$FAILURE_LOG" ]]; then
    echo
    echo "Failed configurations:"
    cat "$FAILURE_LOG"
else
    echo
    echo "No failures recorded."
fi

exit 0