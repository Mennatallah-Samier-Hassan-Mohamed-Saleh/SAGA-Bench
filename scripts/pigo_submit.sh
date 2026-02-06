#!/bin/bash

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 7-00:00:00
##SBATCH --output=single_fs_run_pigo.out
##SBATCH --error=single_fs_run_pigo.err

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

cd /scratch/ms13779/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

#Running the front end with bfsdyn algorithm on fs dataset
./frontEnd -d 1 -w 0 -f /scratch/ms13779/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench/include/fs.csv -b 1 -s adListChunked -n 124836180 -a bfsdyn -t 128 -i 3612134260 
cp Update.csv fs_single_run_Update.csv
cp Alg.csv fs_single_run_Alg.csv
