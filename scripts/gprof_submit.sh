#!/bin/bash

###########################
# SLURM Job Settings
###########################

#SBATCH -c 1                                # Use 1 CPU for gprof
#SBATCH --exclusive                         # Exclusive node allocation
#SBATCH --reservation=Thesis_test_Mennatallah
#SBATCH -t 7-00:00:00                        # Max walltime
#SBATCH --mem=480G                          # Request 480 GB memory
#SBATCH --output=gprof_run_%j.out           # Standard output
#SBATCH --error=gprof_run_%j.err            # Error output

###########################
# Cleanup / Environment
###########################

# Clear OpenMP environment to prevent multi-threaded execution
unset OMP_DISPLAY_ENV
export OMP_NUM_THREADS=1
unset OMP_PROC_BIND
unset OMP_PLACES

# Remove old output files
rm -f Update.csv Alg.csv
rm -f gmon.out

# Load required modules
module purge
module load gcc/9.2.0 cmake perl python libGl libx11 fontconfig mesa openmpi/4.1.1rc1

###########################
# Navigate to project
###########################
cd /scratch/ms13779/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

###########################
# Run BFS dynamic with gprof
###########################

# Make sure frontEnd is compiled with -pg (gprof)
# gprof requires single-threaded execution
./frontEnd \
    -d 1 \
    -w 0 \
    -f /scratch/ms13779/datasets/SAGAdatasets/er.csv \
    -b 1000000 \
    -s abslBtreeSetShared \
    -n 10000000 \
    -a bfsdyn \
    -t 1 \
    -i 990009380

###########################
# Generate gprof report
###########################

gprof frontEnd gmon.out > profile.txt
echo "gprof profile saved to profile.txt"
