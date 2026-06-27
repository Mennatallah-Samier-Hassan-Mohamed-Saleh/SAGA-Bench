#!/bin/bash

#Define the resource requirements here using #SBATCH
#For requesting 128 CPUs
#SBATCH -c 1
##SBATCH --exclusive
##SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 24:00:00
#SBATCH --output=submit.out
#SBATCH --error=submit.err

# As precaution, clear OMP stuff and remove any alg or update csv files in the folder
#unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES
rm Update.csv
rm Alg.csv

#Setting up OMP environment variables
export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=1
#export OMP_PROC_BIND=close
#export OMP_PLACES={0}:128:1

#Resource requiremenmt commands end here
module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

#1. Capture the directory where you submitted the job (SAGA-Bench)
# This replaces the BASH_SOURCE logic which fails in Slurm
export sagaDir=$SLURM_SUBMIT_DIR

# 2. Move to the directory first so the 'rm' and 'frontEnd' work correctly
cd "$sagaDir" || exit
echo "Successfully moved to sagaDir: $PWD"

./frontEnd -d 1 -w 0 -f /scratch/ms13779/datasets/SAGAdatasets/soc-Slashdot0902.txt -b 1000 -s abslBtreeSetShared -a bfsfromscratch -t 1 -v 0 -i 938464

#TOTAL_EDGES=$(wc -l < /scratch/ms13779/datasets/SAGAdatasets/soc-Slashdot0902.clean.noself.txt)
#INITIAL_BATCH=$((TOTAL_EDGES - 1000 * 10))

#./frontEnd -d 1 -w 0 \
#  -f /scratch/ms13779/datasets/SAGAdatasets/soc-Slashdot0902.clean.noself.txt \
#  -b 1000 \
#  -s abslBtreeSetShared \
#  -a bfsfromscratch \
#  -t 1 \
#  -v 0 \
#  -i "$INITIAL_BATCH"
