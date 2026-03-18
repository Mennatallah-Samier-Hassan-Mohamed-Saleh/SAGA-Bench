#!/bin/bash

#Define the resource requirements here using #SBATCH

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 24:00:00
#SBATCH --output=submit_dataset.out
#SBATCH --error=submit_dataset.err

#Resource requiremenmt commands end here
module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

bash $sagaDir/scripts/prepare_Facebook_dataset.sh
