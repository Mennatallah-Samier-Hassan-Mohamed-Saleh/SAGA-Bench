#!/bin/bash

#SBATCH -C jubail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --time=7-00:00:00
#SBATCH --job-name=cpam_all_1run
#SBATCH --output=cpam_all_1run_%j.out
#SBATCH --error=cpam_all_1run_%j.err

set -u
set -o pipefail

# ============================================================
# CPAM paper sweep
#
# 8 datasets
# x 7 batch sizes
# x 1 structure
# x 12 algorithms
# x 1 run
# = 672 frontEnd invocations
#
# Dataset order: smallest to largest by edge count.
#
# Submit from the SAGA-Bench project root so that:
#   SLURM_SUBMIT_DIR = directory containing ./frontEnd
# ============================================================

############################################################
# Environment
############################################################

unset OMP_DISPLAY_ENV
unset OMP_NUM_THREADS
unset OMP_PROC_BIND
unset OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS="${SLURM_CPUS_PER_TASK:-128}"

export OMP_DISPLAY_ENV=false
export OMP_DYNAMIC=false
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

############################################################
# Paths
############################################################

DATA_DIR="/scratch/ms13779/datasets/SAGAdatasets"
SAGA_DIR="${SLURM_SUBMIT_DIR}"
JOB_ID="${SLURM_JOB_ID:-manual}"

RESULTS_DIR="${HOME}/SAGA-Bench/cpam_all_datasets_1run/job_${JOB_ID}"

FAILURE_LOG="${RESULTS_DIR}/failures.log"
SKIP_LOG="${RESULTS_DIR}/skipped.log"
SUMMARY_FILE="${RESULTS_DIR}/runtime_summary.tsv"
CONFIG_FILE="${RESULTS_DIR}/experiment_config.txt"

mkdir -p "$RESULTS_DIR"

: > "$FAILURE_LOG"
: > "$SKIP_LOG"

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

############################################################
# Experiment parameters
############################################################

NUM_BATCHES=10
RUNS=1

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

# Format:
# "algorithm weighted"
#
# weighted:
#   0 = unweighted
#   1 = weighted
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

# Format:
# "filename directed total_edges num_vertices fixed_source"
#
# Ordered from smallest to largest by edge count.
#
# IMPORTANT:
# These filenames assume the original text files use the names below.
# The preflight check will report any filename that does not exist.
DATASETS=(
    "wiki-Talk.txt             1 5021410    2394385   405878"
    "wiki-topcats.txt          1 28511807   1791489   358128"
    "soc-LiveJournal1.txt      1 68993773   4847571   967794"
    "com-orkut.ungraph.txt     0 117185083  3072441   614044"
    "rmat.txt                  1 500000000  32118308  6406224"
    "er.txt                    0 1000009380 10000000  2001011"
    "tw.txt                    0 2405026092 61578415  36501842"
    "fs.txt                    0 3612134270 124836180 13206677"
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
# Record experiment configuration
############################################################

{
    echo "Job ID          : $JOB_ID"
    echo "Hostname        : $(hostname)"
    echo "Started         : $(date)"
    echo "Working dir     : $PWD"
    echo "Binary          : $PWD/frontEnd"
    echo "Data dir        : $DATA_DIR"
    echo "Results dir     : $RESULTS_DIR"
    echo "Threads         : $NUM_THREADS"
    echo "OMP_PROC_BIND   : $OMP_PROC_BIND"
    echo "OMP_PLACES      : $OMP_PLACES"
    echo "Runs            : $RUNS"
    echo "Dynamic batches : $NUM_BATCHES"
    echo "Batch sizes     : ${BATCH_SIZES[*]}"
    echo "Structures      : ${STRUCTURES[*]}"
    echo "Algorithms      : ${#ALGORITHMS[@]}"
    echo "Datasets        : ${#DATASETS[@]}"
    echo
    echo "Dataset configuration:"
    printf "%s\n" "${DATASETS[@]}"
} > "$CONFIG_FILE"

############################################################
# Preflight dataset check
############################################################

echo "============================================================"
echo " Dataset preflight check"
echo "============================================================"

MISSING_DATASETS=0

for dataset_entry in "${DATASETS[@]}"; do
    read -r dataset directed total_edges num_vertices source \
        <<< "$dataset_entry"

    dataset_path="${DATA_DIR}/${dataset}"

    if [[ -f "$dataset_path" ]]; then
        printf \
            "FOUND   %-28s directed=%s vertices=%s edges=%s source=%s\n" \
            "$dataset" \
            "$directed" \
            "$num_vertices" \
            "$total_edges" \
            "$source"
    else
        printf "MISSING %s\n" "$dataset_path"
        ((MISSING_DATASETS++)) || true
    fi
done

echo "============================================================"

if (( MISSING_DATASETS > 0 )); then
    echo
    echo "ERROR: $MISSING_DATASETS configured dataset file(s) are missing."
    echo
    echo "Available text files under $DATA_DIR:"
    find "$DATA_DIR" \
        -maxdepth 1 \
        -type f \
        -name '*.txt' \
        -printf '%f\n' \
        | sort
    echo
    echo "Correct the filenames in DATASETS before running the sweep."
    exit 1
fi

############################################################
# Header
############################################################

echo
echo "============================================================"
echo " CPAM all-dataset paper sweep"
echo "============================================================"
echo "Job ID           : $JOB_ID"
echo "Hostname         : $(hostname)"
echo "Started          : $(date)"
echo "Working dir      : $PWD"
echo "Threads          : $NUM_THREADS"
echo "Datasets         : ${#DATASETS[@]}"
echo "Batch sizes      : ${BATCH_SIZES[*]}"
echo "Structures       : ${STRUCTURES[*]}"
echo "Algorithms       : ${#ALGORITHMS[@]}"
echo "Runs             : $RUNS"
echo "Dynamic batches  : $NUM_BATCHES"
echo "Expected jobs    : $(( \
    ${#DATASETS[@]} * \
    ${#BATCH_SIZES[@]} * \
    ${#STRUCTURES[@]} * \
    ${#ALGORITHMS[@]} * \
    RUNS \
))"
echo "Results          : $RESULTS_DIR"
echo "Summary          : $SUMMARY_FILE"
echo "============================================================"

############################################################
# Main sweep
############################################################

for ((run=1; run<=RUNS; run++)); do

    RUN_START=$(date +%s)

    echo
    echo "############################################################"
    echo " Starting run $run / $RUNS"
    echo " Time: $(date)"
    echo "############################################################"

    for dataset_entry in "${DATASETS[@]}"; do

        read -r dataset directed total_edges num_vertices source \
            <<< "$dataset_entry"

        DATASET_PATH="${DATA_DIR}/${dataset}"
        DATASET_START=$(date +%s)

        echo
        echo "============================================================"
        echo " Dataset      : $dataset"
        echo " Directed     : $directed"
        echo " Vertices     : $num_vertices"
        echo " Edges        : $total_edges"
        echo " Fixed source : $source"
        echo " File         : $DATASET_PATH"
        echo "============================================================"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo "WARNING: Dataset disappeared after preflight: $DATASET_PATH"

            echo \
                "$(date) | MISSING DATASET | Run $run | $dataset" \
                >> "$SKIP_LOG"

            DATASET_SKIPS=$(( \
                ${#BATCH_SIZES[@]} * \
                ${#STRUCTURES[@]} * \
                ${#ALGORITHMS[@]} \
            ))

            ((SKIPPED_JOBS += DATASET_SKIPS)) || true
            continue
        fi

        for BATCH_SIZE in "${BATCH_SIZES[@]}"; do

            DYNAMIC_EDGE_COUNT=$((BATCH_SIZE * NUM_BATCHES))
            INITIAL_BATCH=$((total_edges - DYNAMIC_EDGE_COUNT))

            if (( INITIAL_BATCH <= 0 )); then
                echo
                echo "WARNING: Invalid initial batch."
                echo "Dataset       : $dataset"
                echo "Batch size    : $BATCH_SIZE"
                echo "Total edges   : $total_edges"
                echo "Dynamic edges : $DYNAMIC_EDGE_COUNT"

                BATCH_SKIPS=$(( \
                    ${#STRUCTURES[@]} * \
                    ${#ALGORITHMS[@]} \
                ))

                ((SKIPPED_JOBS += BATCH_SKIPS)) || true

                echo \
                    "$(date) | INVALID INITIAL BATCH | Run $run | $dataset | b=$BATCH_SIZE" \
                    >> "$SKIP_LOG"

                continue
            fi

            BATCH_START=$(date +%s)

            echo
            echo "  ----------------------------------------------------------"
            echo "  Batch size      : $BATCH_SIZE"
            echo "  Initial batch   : $INITIAL_BATCH"
            echo "  Dynamic batches : $NUM_BATCHES x $BATCH_SIZE"
            echo "  Fixed source    : $source"
            echo "  ----------------------------------------------------------"

            for structure in "${STRUCTURES[@]}"; do

                STRUCTURE_START=$(date +%s)

                for alg_entry in "${ALGORITHMS[@]}"; do

                    read -r algorithm weighted <<< "$alg_entry"

                    ((TOTAL_JOBS++)) || true

                    rm -f Alg*.csv Update*.csv

                    echo
                    echo "------------------------------------------------------------"
                    echo "Run        : $run / $RUNS"
                    echo "Dataset    : $dataset"
                    echo "Batch      : $BATCH_SIZE"
                    echo "Structure  : $structure"
                    echo "Algorithm  : $algorithm"
                    echo "Weighted   : $weighted"
                    echo "Source     : $source"
                    echo "------------------------------------------------------------"

                    echo "./frontEnd \
-d $directed \
-w $weighted \
-f $DATASET_PATH \
-b $BATCH_SIZE \
-s $structure \
-a $algorithm \
-t $NUM_THREADS \
-n $num_vertices \
-i $INITIAL_BATCH \
-r $source"

                    ALGORITHM_START=$(date +%s)

                    ./frontEnd \
                        -d "$directed" \
                        -w "$weighted" \
                        -f "$DATASET_PATH" \
                        -b "$BATCH_SIZE" \
                        -s "$structure" \
                        -a "$algorithm" \
                        -t "$NUM_THREADS" \
                        -n "$num_vertices" \
                        -i "$INITIAL_BATCH" \
                        -r "$source"

                    FRONTEND_STATUS=$?

                    ALGORITHM_END=$(date +%s)
                    ALGORITHM_RUNTIME=$(( \
                        ALGORITHM_END - ALGORITHM_START \
                    ))

                    if (( FRONTEND_STATUS != 0 )); then
                        echo
                        echo "WARNING: frontEnd failed."
                        echo "Exit status: $FRONTEND_STATUS"

                        echo \
                            "$(date) | FAILED | Job $JOB_ID | Run $run | $dataset | b=$BATCH_SIZE | $structure | $algorithm | source=$source | exit=$FRONTEND_STATUS | ${ALGORITHM_RUNTIME}s" \
                            >> "$FAILURE_LOG"

                        printf \
"%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\tFAILED\n" \
                            "$run" \
                            "$dataset" \
                            "$BATCH_SIZE" \
                            "$structure" \
                            "$algorithm" \
                            "$weighted" \
                            "$source" \
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
                        "$dataset" \
                        "$BATCH_SIZE" \
                        "$structure" \
                        "$algorithm" \
                        "$weighted" \
                        "$source" \
                        "$ALGORITHM_RUNTIME" \
                        >> "$SUMMARY_FILE"

                    RUN_TAG="job${JOB_ID}_run${run}_${dataset}_b${BATCH_SIZE}_${structure}_${algorithm}"

                    DIRECTORY="${RESULTS_DIR}/${algorithm}/${structure}/${dataset}/b${BATCH_SIZE}/Run${run}"

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

                done

                STRUCTURE_END=$(date +%s)
                STRUCTURE_RUNTIME=$(( \
                    STRUCTURE_END - STRUCTURE_START \
                ))

                echo
                echo "  Structure $structure completed for:"
                echo "    Dataset : $dataset"
                echo "    Batch   : $BATCH_SIZE"
                echo "    Runtime : $((STRUCTURE_RUNTIME / 60))m $((STRUCTURE_RUNTIME % 60))s"

            done

            BATCH_END=$(date +%s)
            BATCH_RUNTIME=$((BATCH_END - BATCH_START))

            echo
            echo "  Batch size $BATCH_SIZE completed in:"
            echo "    $((BATCH_RUNTIME / 60))m $((BATCH_RUNTIME % 60))s"

        done

        DATASET_END=$(date +%s)
        DATASET_RUNTIME=$((DATASET_END - DATASET_START))

        echo
        echo "============================================================"
        echo " Dataset complete: $dataset"
        echo " Runtime: $((DATASET_RUNTIME / 3600))h $(((DATASET_RUNTIME % 3600) / 60))m $((DATASET_RUNTIME % 60))s"
        echo "============================================================"

    done

    RUN_END=$(date +%s)
    RUN_RUNTIME=$((RUN_END - RUN_START))

    echo
    echo "############################################################"
    echo " Run $run complete"
    echo " Runtime: $((RUN_RUNTIME / 3600))h $(((RUN_RUNTIME % 3600) / 60))m $((RUN_RUNTIME % 60))s"
    echo "############################################################"

done

############################################################
# Final summary
############################################################

EXPERIMENT_END=$(date +%s)
TOTAL_RUNTIME=$((EXPERIMENT_END - EXPERIMENT_START))

echo
echo "============================================================"
echo " ALL DATASET RUNS COMPLETE"
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
echo "Skip log       : $SKIP_LOG"
echo "============================================================"

if [[ -s "$SKIP_LOG" ]]; then
    echo
    echo "Skipped configurations:"
    cat "$SKIP_LOG"
fi

if [[ -s "$FAILURE_LOG" ]]; then
    echo
    echo "Failed configurations:"
    cat "$FAILURE_LOG"
else
    echo
    echo "No failures recorded."
fi

exit 0