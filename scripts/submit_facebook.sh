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

bash $SCRATCH/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench/scripts/prepare_Facebook_dataset.sh
