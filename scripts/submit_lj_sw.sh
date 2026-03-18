#!/bin/bash

#Define the resource requirements here using #SBATCH

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 7-00:00:00
#SBATCH --output=submit_lj_sw.out
#SBATCH --error=submit_lj_sw.err

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

# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

bash $sagaDir/scripts/lj_logarithmic_fixed_batch_number.sh
