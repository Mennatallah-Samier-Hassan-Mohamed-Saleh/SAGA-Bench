#!/bin/bash

#SBATCH -C jubail
#SBATCH --ntasks=1
#SBATCH --cpus-per-task=128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH --time=7-00:00:00
#SBATCH --job-name=tw_adlist_b100k
#SBATCH --output=tw_adlist_b100k_%j.out
#SBATCH --error=tw_adlist_b100k_%j.err

unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

export OMP_DISPLAY_ENV=false
export OMP_NUM_THREADS=128
export OMP_PROC_BIND=close
export OMP_PLACES=cores

sagaDir="$SLURM_SUBMIT_DIR"

cd "$sagaDir" || {
    echo "ERROR: Cannot enter $sagaDir"
    exit 1
}

if [[ ! -x ./frontEnd ]]; then
    echo "ERROR: ./frontEnd not found"
    exit 1
fi

rm -f Update.csv Alg.csv

START=$(date +%s)

./frontEnd \
    -d 0 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/tw.txt \
    -b 100000 \
    -s adListShared \
    -a bfsdyn \
    -t 128 \
    -n 61578415 \
    -i 2404026092 \
    -r 36501842

STATUS=$?

END=$(date +%s)

echo
echo "Runtime: $((END-START)) seconds"
echo "Exit status: $STATUS"

if (( STATUS == 0 )); then
    cp Update.csv tw_adListShared_b100000_bfsdyn_Update.csv
    cp Alg.csv    tw_adListShared_b100000_bfsdyn_Alg.csv
else
    echo "WARNING: frontEnd failed"
fi

exit 0
