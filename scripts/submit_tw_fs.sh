#!/bin/bash

#SBATCH -c 128
#SBATCH --exclusive
#SBATCH -t 7-00:00:00
#SBATCH --job-name=tw_fs_single
#SBATCH --output=tw_fs_single_%j.out
#SBATCH --error=tw_fs_single_%j.err

#################################################
# Environment
#################################################

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

rm -f Update.csv Alg.csv

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=128
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

echo "=========================================="
echo " Single-run validation"
echo " Job ID    : ${SLURM_JOB_ID}"
echo " Hostname  : $(hostname)"
echo " Threads   : $OMP_NUM_THREADS"
echo " Started   : $(date)"
echo "=========================================="

TOTAL_START=$(date +%s)

#################################################
# Twitter
#################################################

echo
echo "=========================================="
echo " Twitter"
echo "=========================================="

rm -f Update.csv Alg.csv

START=$(date +%s)

./frontEnd \
    -d 0 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/tw.txt \
    -b 1 \
    -s cpamSetShared \
    -a bfsdyn \
    -t 128 \
    -n 61578415 \
    -i 2405026082

END=$(date +%s)

echo
echo "Twitter runtime: $((END-START)) seconds"

cp Update.csv tw_single_run_Update.csv
cp Alg.csv    tw_single_run_Alg.csv

#################################################
# Friendster
#################################################

echo
echo "=========================================="
echo " Friendster"
echo "=========================================="

rm -f Update.csv Alg.csv

START=$(date +%s)

./frontEnd \
    -d 0 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/fs.txt \
    -b 1 \
    -s cpamSetShared \
    -a bfsdyn \
    -t 128 \
    -n 124836180 \
    -i 3612134260

END=$(date +%s)

echo
echo "Friendster runtime: $((END-START)) seconds"

cp Update.csv fs_single_run_Update.csv
cp Alg.csv    fs_single_run_Alg.csv

#################################################
# Total time
#################################################

TOTAL_END=$(date +%s)

echo
echo "=========================================="
echo " Finished : $(date)"
echo " Total runtime: $((TOTAL_END-TOTAL_START)) seconds"
echo "=========================================="