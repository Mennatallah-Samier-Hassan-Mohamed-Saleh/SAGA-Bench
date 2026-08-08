#!/bin/bash

#SBATCH --nodes=1
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --time=02:00:00
#SBATCH --job-name=shuffle_test
#SBATCH --output=parallel_shuffle_test_%j.out
#SBATCH --error=parallel_shuffle_test_%j.err

#################################################
# Environment
#################################################

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS=${SLURM_CPUS_PER_TASK:-128}

export OMP_DISPLAY_ENV=false
export OMP_DYNAMIC=false
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

#################################################
# Paths
#################################################

sagaDir="${SLURM_SUBMIT_DIR}"
dataDir="/scratch/ms13779/datasets/SAGAdatasets"

resultsDir="${sagaDir}/parallel_shuffle_test/job_${SLURM_JOB_ID:-manual}"
summaryFile="${resultsDir}/summary.tsv"

mkdir -p "$resultsDir"

cd "$sagaDir" || {
    echo "ERROR: Cannot enter $sagaDir" >&2
    exit 1
}

if [[ ! -x ./frontEnd ]]; then
    echo "ERROR: ./frontEnd is missing or not executable in $PWD" >&2
    exit 1
fi

#################################################
# Test configuration
#################################################

STRUCTURE="cpamSetShared"
ALGORITHM="bfsdyn"
BATCH_SIZE=1
NUM_BATCHES=10

# filename | directed | total edges | vertices | fixed source
DATASETS=(
    "soc-LiveJournal1.txt 1 68993773 4847571 961292"
    "com-orkut.ungraph.txt 0 117185083 3072441 614483"
)

#################################################
# Summary header
#################################################

printf "dataset\tsource\tload_s\tconversion_s\tshuffle_s\ttotal_s\tstatus\n" \
    > "$summaryFile"

TOTAL_START=$(date +%s)

echo "============================================================"
echo " Parallel-shuffle reduced validation"
echo "============================================================"
echo "Job ID       : ${SLURM_JOB_ID:-manual}"
echo "Hostname     : $(hostname)"
echo "Started      : $(date)"
echo "Working dir  : $PWD"
echo "Results dir  : $resultsDir"
echo "Threads      : $NUM_THREADS"
echo "Structure    : $STRUCTURE"
echo "Algorithm    : $ALGORITHM"
echo "Batch size   : $BATCH_SIZE"
echo "Dyn. batches : $NUM_BATCHES"
echo "============================================================"

#################################################
# Runs
#################################################

for dataset_entry in "${DATASETS[@]}"; do
    read -r dataset directed total_edges num_vertices source \
        <<< "$dataset_entry"

    datasetPath="${dataDir}/${dataset}"
    initialBatch=$(( total_edges - (BATCH_SIZE * NUM_BATCHES) ))

    datasetDir="${resultsDir}/${dataset}"
    mkdir -p "$datasetDir"

    runLog="${datasetDir}/run.log"

    echo
    echo "------------------------------------------------------------"
    echo "Dataset       : $dataset"
    echo "Directed      : $directed"
    echo "Total edges   : $total_edges"
    echo "Vertices      : $num_vertices"
    echo "Fixed source  : $source"
    echo "Initial batch : $initialBatch"
    echo "Dynamic work  : $NUM_BATCHES x $BATCH_SIZE"
    echo "------------------------------------------------------------"

    if [[ ! -f "$datasetPath" ]]; then
        echo "ERROR: Dataset not found: $datasetPath" | tee "$runLog"

        printf "%s\t%s\tNA\tNA\tNA\tNA\tMISSING\n" \
            "$dataset" "$source" >> "$summaryFile"

        continue
    fi

    rm -f Update.csv Alg.csv

    RUN_START=$(date +%s)

    echo "./frontEnd \
-d $directed \
-w 0 \
-f $datasetPath \
-b $BATCH_SIZE \
-s $STRUCTURE \
-a $ALGORITHM \
-t $NUM_THREADS \
-n $num_vertices \
-i $initialBatch \
-r $source"

    ./frontEnd \
        -d "$directed" \
        -w 0 \
        -f "$datasetPath" \
        -b "$BATCH_SIZE" \
        -s "$STRUCTURE" \
        -a "$ALGORITHM" \
        -t "$NUM_THREADS" \
        -n "$num_vertices" \
        -i "$initialBatch" \
        -r "$source" \
        2>&1 | tee "$runLog"

    frontendStatus=${PIPESTATUS[0]}

    RUN_END=$(date +%s)
    TOTAL_SECONDS=$((RUN_END - RUN_START))

    if [[ $frontendStatus -ne 0 ]]; then
        echo "ERROR: $dataset failed after ${TOTAL_SECONDS}s"

        printf "%s\t%s\tNA\tNA\tNA\t%s\tFAILED\n" \
            "$dataset" "$source" "$TOTAL_SECONDS" \
            >> "$summaryFile"

        rm -f Update.csv Alg.csv
        continue
    fi

    #################################################
    # Extract phase timings
    #################################################

    LOAD_TIME=$(
        awk '/Time to load graph:/ {
            print $5;
            exit
        }' "$runLog"
    )

    CONVERSION_TIME=$(
        awk '/Time to convert to edgelist:/ {
            print $6;
            exit
        }' "$runLog"
    )

    SHUFFLE_TIME=$(
        awk '
            /Time to parallel shuffle edges:/ {
                print $6;
                exit
            }

            /Time to shuffle edges:/ {
                print $6;
                exit
            }
        ' "$runLog"
    )

    LOAD_TIME=${LOAD_TIME:-NA}
    CONVERSION_TIME=${CONVERSION_TIME:-NA}
    SHUFFLE_TIME=${SHUFFLE_TIME:-NA}

    #################################################
    # Validate source and batch count
    #################################################

    if ! grep -q "Configured source: $source" "$runLog"; then
        echo "ERROR: Fixed source $source was not confirmed." >&2
        STATUS="SOURCE_ERROR"
    elif ! grep -q "Total batches processed: 11" "$runLog"; then
        echo "ERROR: Expected 11 total batches." >&2
        STATUS="BATCH_ERROR"
    else
        STATUS="PASS"
    fi

    #################################################
    # Save CSV output
    #################################################

    if [[ -f Update.csv ]]; then
        mv Update.csv \
            "${datasetDir}/${dataset}_parallel_shuffle_Update.csv"
    else
        echo "WARNING: Update.csv was not created." >&2
    fi

    if [[ -f Alg.csv ]]; then
        mv Alg.csv \
            "${datasetDir}/${dataset}_parallel_shuffle_Alg.csv"
    else
        echo "WARNING: Alg.csv was not created." >&2
    fi

    printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n" \
        "$dataset" \
        "$source" \
        "$LOAD_TIME" \
        "$CONVERSION_TIME" \
        "$SHUFFLE_TIME" \
        "$TOTAL_SECONDS" \
        "$STATUS" \
        >> "$summaryFile"

    echo
    echo "Results for $dataset"
    echo "  Source          : $source"
    echo "  Load time       : $LOAD_TIME s"
    echo "  Conversion time : $CONVERSION_TIME s"
    echo "  Shuffle time    : $SHUFFLE_TIME s"
    echo "  Total runtime   : $TOTAL_SECONDS s"
    echo "  Status          : $STATUS"
done

#################################################
# Final summary
#################################################

TOTAL_END=$(date +%s)
EXPERIMENT_SECONDS=$((TOTAL_END - TOTAL_START))

echo
echo "============================================================"
echo " TEST COMPLETE"
echo "============================================================"
echo "Finished      : $(date)"
echo "Elapsed       : $((EXPERIMENT_SECONDS / 3600))h $(((EXPERIMENT_SECONDS % 3600) / 60))m $((EXPERIMENT_SECONDS % 60))s"
echo "Results       : $resultsDir"
echo "Summary       : $summaryFile"
echo
column -t -s $'\t' "$summaryFile"
echo "============================================================"
