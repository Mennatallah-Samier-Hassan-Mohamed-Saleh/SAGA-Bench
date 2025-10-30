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
rm submit.out
rm submit.err
rm Slashdot_adList.log
rm Slashdot_abslBtreeSet.log
rm Slashdot_stinger.log
rm facebook_adList.log
rm facebook_abslBtreeSet.log
rm facebook_stinger.log
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

cd $SCRATCH/Masters_thesis/Thesis/SAGA-Bench

#Testing bfsdyn on different data structures for slashdot dataset
echo "Starting bfsdyn tests on adList for slashdot dataset"
./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s adList -n 82168 -a bfsdyn -t 1 | tee -a Slashdot_adList.log
rm Update.csv
rm Alg.csv
echo "Starting bfsdyn tests on abslBtreeSet for slashdot dataset"
./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s abslBtreeSet -n 82168 -a bfsdyn -t 1 | tee -a Slashdot_abslBtreeSet.log
rm Update.csv
rm Alg.csv
echo "Starting bfsdyn tests on stinger for slashdot dataset"
./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s stinger -n 82168 -a bfsdyn -t 1 | tee -a Slashdot_stinger.log

#Testing bfsdyn on different data structures for Facebook dataset
echo "Starting bfsdyn tests on adList for facebook dataset"
./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s adList -n 4039 -a bfsdyn -t 1 | tee -a facebook_adList.log
rm Update.csv
rm Alg.csv
echo "Starting bfsdyn tests on abslBtreeSet for facebook dataset"
./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s abslBtreeSet -n 4039 -a bfsdyn -t 1 | tee -a facebook_abslBtreeSet.log
rm Update.csv
rm Alg.csv
echo "Starting bfsdyn tests on stinger for facebook dataset"
./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s stinger -n 4039 -a bfsdyn -t 1 | tee -a facebook_stinger.log
