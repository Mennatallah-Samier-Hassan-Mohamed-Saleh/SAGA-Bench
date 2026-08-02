#!/bin/bash

#SBATCH -C jubail
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00
#SBATCH --job-name=tw_cpam
#SBATCH --output=tw_cpam_%j.out
#SBATCH --error=tw_cpam_%j.err

# Twitter, CPAM only:
# 1 dataset x 7 batch sizes x 1 structure x 12 algorithms x 3 runs
# = 252 total invocations.

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS=${SLURM_CPUS_PER_TASK:-128}

export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

dataDir="/scratch/ms13779/datasets/SAGAdatasets"
sagaDir="$SLURM_SUBMIT_DIR"
resultsDir="${HOME}/SAGA-Bench/twitter_cpam_paper/job_${SLURM_JOB_ID:-manual}"

FAILURE_LOG="${resultsDir}/failures.log"
SKIP_LOG="${resultsDir}/skipped.log"

mkdir -p "$resultsDir"
: > "$FAILURE_LOG"
: > "$SKIP_LOG"

cd "$sagaDir" || {
    echo "ERROR: Cannot enter SAGA-Bench directory: $sagaDir" >&2
    exit 1
}

echo "Hostname        : $(hostname)"
echo "Job ID          : ${SLURM_JOB_ID:-unknown}"
echo "CPUs            : $NUM_THREADS"
echo "Working dir     : $PWD"
echo "OMP_NUM_THREADS : $OMP_NUM_THREADS"
echo "OMP_PROC_BIND   : $OMP_PROC_BIND"
echo "OMP_PLACES      : $OMP_PLACES"
echo

NUM_BATCHES=10
RUNS=3

BATCH_SIZES=(1 10 100 1000 10000 100000 1000000)

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

DATASETS=(
    "tw.txt 0 2405026092 61578415"
)

TOTAL_JOBS=0
FAILED_JOBS=0
SKIPPED_JOBS=0
PASSED_JOBS=0

EXPERIMENT_START=$(date +%s)

echo "=============================================="
echo " SAGA-Bench PIGO Twitter sweep - CPAM only"
echo " Started    : $(date)"
echo " Structures : ${#STRUCTURES[@]} (${STRUCTURES[*]})"
echo " Algorithms : ${#ALGORITHMS[@]}"
echo " Datasets   : ${#DATASETS[@]} (Twitter)"
echo " Batch sizes: ${BATCH_SIZES[*]}"
echo " Runs       : $RUNS"
echo " Batches    : $NUM_BATCHES dynamic batches per configuration"
echo " Threads    : $NUM_THREADS"
echo " Results    : $resultsDir"
echo "=============================================="

for ((run=1; run<=RUNS; run++)); do
    RUN_START=$(date +%s)

    echo
    echo "----------------------------------------------"
    echo " Starting Run $run / $RUNS - $(date)"
    echo "----------------------------------------------"

    for dataset_entry in "${DATASETS[@]}"; do
        read -r dataset directed total_edges num_vertices <<< "$dataset_entry"
        DATASET_PATH="${dataDir}/${dataset}"

        if [[ ! -f "$DATASET_PATH" ]]; then
            echo "WARNING: Dataset not found - skipping: $DATASET_PATH"
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
                    echo "./frontEnd -d $directed -w $weighted -f $DATASET_PATH -b $BATCH_SIZE -s $structure -a $algorithm -t $NUM_THREADS -n $num_vertices -i $INITIAL_BATCH"

                    ALGO_START=$(date +%s)

                    if ! ./frontEnd                         -d "$directed"                         -w "$weighted"                         -f "$DATASET_PATH"                         -b "$BATCH_SIZE"                         -s "$structure"                         -a "$algorithm"                         -t "$NUM_THREADS"                         -n "$num_vertices"                         -i "$INITIAL_BATCH"
                    then
                        ALGO_END=$(date +%s)
                        echo "WARNING: frontEnd failed - continuing to next job"
                        echo "$(date) | FAILED | Job ${SLURM_JOB_ID:-manual} | Run $run | $dataset | b=$BATCH_SIZE | $structure | $algorithm | $(( ALGO_END - ALGO_START ))s" >> "$FAILURE_LOG"
                        (( FAILED_JOBS++ )) || true
                        rm -f Alg*.csv Update*.csv
                        continue
                    fi

                    ALGO_END=$(date +%s)
                    echo "Completed in $(( ALGO_END - ALGO_START ))s"
                    (( PASSED_JOBS++ )) || true

                    RUN_TAG="job${SLURM_JOB_ID:-manual}_run${run}_${dataset}_b${BATCH_SIZE}_${structure}_${algorithm}"
                    DIRECTORY="${resultsDir}/${algorithm}/${structure}/${dataset}/b${BATCH_SIZE}/Run${run}"
                    mkdir -p "$DIRECTORY"

                    for f in Alg*.csv; do
                        [[ -f "$f" ]] && mv "$f" "${DIRECTORY}/${RUN_TAG}_$(basename "$f")"
                    done

                    for f in Update*.csv; do
                        [[ -f "$f" ]] && mv "$f" "${DIRECTORY}/${RUN_TAG}_$(basename "$f")"
                    done
                done

                STRUCT_END=$(date +%s)
                echo
                echo "  Structure $structure (b=$BATCH_SIZE) completed in $(( STRUCT_END - STRUCT_START ))s"
            done

            BATCH_END=$(date +%s)
            BATCH_TIME=$(( BATCH_END - BATCH_START ))
            echo
            echo "  Batch size $BATCH_SIZE finished in $(( BATCH_TIME / 60 ))m $(( BATCH_TIME % 60 ))s"
        done

        DATASET_END=$(date +%s)
        DATASET_TIME=$(( DATASET_END - DATASET_START ))
        echo
        echo "Dataset $dataset finished in $(( DATASET_TIME / 60 ))m $(( DATASET_TIME % 60 ))s"
    done

    RUN_END=$(date +%s)
    RUN_TIME=$(( RUN_END - RUN_START ))
    echo
    echo "Run $run completed in $(( RUN_TIME / 60 ))m $(( RUN_TIME % 60 ))s"
done

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
echo " Jobs skipped: $SKIPPED_JOBS"
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

