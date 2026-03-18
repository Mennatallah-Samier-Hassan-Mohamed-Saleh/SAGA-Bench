#!/bin/bash

#Define the resource requirements here using #SBATCH

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 24:00:00
#SBATCH --output=submit_rmat.out
#SBATCH --error=submit_rmat.err

#Resource requiremenmt commands end here
source /share/apps/NYUAD5/miniconda/3-4.11.0/bin/activate
conda activate rmat_setup

#Needed Paths
dataDir=$SCRATCH/datasets/SAGAdatasets/
# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

#Generating the RMAT dataset
python ${sagaDir}/scripts/rmat_generator.py ${dataDir}/rmat.txt
#Shuffling the dataset: rmat.txt
bash ${sagaDir}/inputResource/shuffle.sh ${dataDir}/rmat.txt /scratch/ms13779/sortdump
#Adding weights(maximum weight of 1) and timestamps to the dataset:  
cd   ${sagaDir}/inputResource/
bash ./addWeightAndTime.sh ${dataDir}/rmat.shuffle.txt 3 1

echo "RMAT dataset has been generated successfully!"

