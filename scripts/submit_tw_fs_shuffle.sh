#!/bin/bash
#SBATCH -C jubail
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH -t 7-00:00:00
#SBATCH --job-name=tw_fs_shuffle
#SBATCH --output=tw_fs_shuffle_%j.out
#SBATCH --error=tw_fs_shuffle_%j.err

#################################################
# Environment
#################################################

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

NUM_THREADS=${SLURM_CPUS_PER_TASK:-128}

export OMP_DISPLAY_ENV=true
export OMP_DYNAMIC=false
export OMP_NUM_THREADS="$NUM_THREADS"
export OMP_PROC_BIND=close
export OMP_PLACES=cores

sagaDir="${SLURM_SUBMIT_DIR}"

cd "$sagaDir" || {
    echo "ERROR: Cannot enter SAGA-Bench directory: $sagaDir" >&2
    exit 1
}

if [[ ! -x ./frontEnd ]]; then
    echo "ERROR: ./frontEnd is missing or not executable in $PWD" >&2
    exit 1
fi

RESULTS_DIR="${sagaDir}/parallel_shuffle_results/job_${SLURM_JOB_ID:-manual}"
mkdir -p "$RESULTS_DIR"

rm -f Update.csv Alg.csv

echo "=========================================="
echo " Twitter + Friendster shuffle validation"
echo " Job ID      : ${SLURM_JOB_ID:-manual}"
echo " Hostname    : $(hostname)"
echo " Threads     : $NUM_THREADS"
echo " Started     : $(date)"
echo " Results dir : $RESULTS_DIR"
echo "=========================================="

TOTAL_START=$(date +%s)

#################################################
# Twitter
#################################################

echo
echo "=========================================="
echo " Twitter"
echo " Fixed source : 36501842"
echo "=========================================="

rm -f Update.csv Alg.csv

TW_START=$(date +%s)

if ./frontEnd \
    -d 0 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/tw.txt \
    -b 1 \
    -s cpamSetShared \
    -a bfsdyn \
    -t "$NUM_THREADS" \
    -n 61578415 \
    -i 2405026082 \
    -r 36501842
then
    TW_END=$(date +%s)
    TW_RUNTIME=$((TW_END - TW_START))

    echo
    echo "Twitter runtime: ${TW_RUNTIME} seconds"

    if [[ -f Update.csv ]]; then
        mv Update.csv \
            "${RESULTS_DIR}/tw_parallel_shuffle_Update.csv"
    else
        echo "WARNING: Twitter Update.csv was not created." >&2
    fi

    if [[ -f Alg.csv ]]; then
        mv Alg.csv \
            "${RESULTS_DIR}/tw_parallel_shuffle_Alg.csv"
    else
        echo "WARNING: Twitter Alg.csv was not created." >&2
    fi
else
    TW_END=$(date +%s)
    TW_RUNTIME=$((TW_END - TW_START))

    echo "ERROR: Twitter failed after ${TW_RUNTIME} seconds." >&2
    exit 1
fi

#################################################
# Friendster
#################################################

echo
echo "=========================================="
echo " Friendster"
echo " Fixed source : 13206677"
echo "=========================================="

rm -f Update.csv Alg.csv

FS_START=$(date +%s)

if ./frontEnd \
    -d 0 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/fs.txt \
    -b 1 \
    -s cpamSetShared \
    -a bfsdyn \
    -t "$NUM_THREADS" \
    -n 124836180 \
    -i 3612134260 \
    -r 13206677
then
    FS_END=$(date +%s)
    FS_RUNTIME=$((FS_END - FS_START))

    echo
    echo "Friendster runtime: ${FS_RUNTIME} seconds"

    if [[ -f Update.csv ]]; then
        mv Update.csv \
            "${RESULTS_DIR}/fs_parallel_shuffle_Update.csv"
    else
        echo "WARNING: Friendster Update.csv was not created." >&2
    fi

    if [[ -f Alg.csv ]]; then
        mv Alg.csv \
            "${RESULTS_DIR}/fs_parallel_shuffle_Alg.csv"
    else
        echo "WARNING: Friendster Alg.csv was not created." >&2
    fi
else
    FS_END=$(date +%s)
    FS_RUNTIME=$((FS_END - FS_START))

    echo "ERROR: Friendster failed after ${FS_RUNTIME} seconds." >&2
    exit 1
fi

#################################################
# Summary
#################################################

TOTAL_END=$(date +%s)
TOTAL_RUNTIME=$((TOTAL_END - TOTAL_START))

{
    echo -e "dataset\tsource\truntime_seconds"
    echo -e "Twitter\t36501842\t${TW_RUNTIME}"
    echo -e "Friendster\t13206677\t${FS_RUNTIME}"
    echo -e "Combined\tNA\t${TOTAL_RUNTIME}"
} > "${RESULTS_DIR}/runtime_summary.tsv"

echo
echo "=========================================="
echo " Finished           : $(date)"
echo " Twitter runtime    : ${TW_RUNTIME} seconds"
echo " Friendster runtime : ${FS_RUNTIME} seconds"
echo " Total runtime      : ${TOTAL_RUNTIME} seconds"
echo " Results            : $RESULTS_DIR"
echo "=========================================="