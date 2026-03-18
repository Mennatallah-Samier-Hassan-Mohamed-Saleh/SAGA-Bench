#!/bin/bash

#Define the resource requirements here using #SBATCH

#For requesting 128 CPUs
#SBATCH -c 128
#SBATCH --exclusive
#SBATCH --reservation=Thesis_test_Mennatallah
#Max wallTime for the job
#SBATCH -t 24:00:00
#SBATCH --output=submit.out
#SBATCH --error=submit.err

# As precaution, clear OMP stuff and remove any alg or update csv files in the folder
#unset OMP_DISPLAY_ENV OMP_NUM_THREADS OMP_PROC_BIND OMP_PLACES
rm submit.out
rm submit.err
rm Slashdot_stinger*
rm facebook_stinger*
rm test_stinger*
rm Update.csv
rm Alg.csv

#Setting up OMP environment variables
export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=128
export OMP_PROC_BIND=close
export OMP_PLACES={0}:128:1

#Resource requiremenmt commands end here
module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

# 3. Move into it
cd "$sagaDir" || exit
echo "Successfully moved to sagaDir: $PWD"

#Testing bfsdyn on stinger data structures for test.csv
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f ./test.csv -b 10 -s stinger -n 40 -a bfsdyn -t 128| tee -a test_stinger_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing bfsdyn on stinger data structures for slashdot dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s stinger -n 82168 -a bfsdyn -t 128 | tee -a Slashdot_stinger_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing bfsdyn on stinger data structures for facebook dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s stinger -n 4039 -a bfsdyn -t 128 | tee -a facebook_stinger_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done