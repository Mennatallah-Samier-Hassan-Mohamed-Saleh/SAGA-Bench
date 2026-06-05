#!/bin/bash

#Define the resource requirements here using #SBATCH
#For requesting 1 CPU
#SBATCH -c 1
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
#export OMP_PLACES={0}:16:1

#Resource requiremenmt commands end here
module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

#1. Capture the directory where you submitted the job (SAGA-Bench)
# This replaces the BASH_SOURCE logic which fails in Slurm
export sagaDir=$SLURM_SUBMIT_DIR

# 2. Move to the directory first so the 'rm' and 'frontEnd' work correctly
cd "$sagaDir" || exit
echo "Successfully moved to sagaDir: $PWD"

#Testing traverse on different data structures for Facebook dataset
echo "Starting traverse tests on degAwareRHH for facebook dataset"
./frontEnd -d 0 -w 1 -l 3 -u 100 -f $SCRATCH/datasets/SAGAdatasets/facebook.csv -b 88234 -s abslBtreeSetShared -a traverse -t 1

