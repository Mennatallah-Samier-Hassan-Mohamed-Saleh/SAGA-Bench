#!/bin/bash

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 7-00:00:00
##SBATCH --output=single_run.out
##SBATCH --error=single_run.err

# As precaution, clear OMP stuff and remove any alg or update csv files in the folder
unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES
rm Update.csv
rm Alg.csv

#Resource requiremenmt commands end here
module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

#Setting up OMP environment variables
export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=128
export OMP_PROC_BIND=close
export OMP_PLACES={0}:128:1

# 1. Capture the directory where you submitted the job (SAGA-Bench)
# This replaces the BASH_SOURCE logic which fails in Slurm
export sagaDir=$SLURM_SUBMIT_DIR

# 2. Move to the directory first so the 'rm' and 'frontEnd' work correctly
cd "$sagaDir" || exit
echo "Successfully moved to sagaDir: $PWD"

#Running the front end with bfsdyn algorithm on fs dataset
./frontEnd -d 0 -w 0 -f /scratch/ms13779/datasets/SAGAdatasets/facebook.csv -b 1522 -s adListShared -n 4039 -a bfsdyn -t 128 
cp Update.csv single_run_Update.csv
cp Alg.csv single_run_Alg.csv
