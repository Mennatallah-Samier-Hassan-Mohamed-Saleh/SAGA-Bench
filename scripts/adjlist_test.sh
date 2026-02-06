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
rm Slashdot_adList*
rm facebook_adList*
rm test_adList*
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

cd $SCRATCH/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

#Testing ccfromscratch on adList data structures for test.csv
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f ./test.csv -b 10 -s adList -n 40 -a ccfromscratch -t 1 | tee -a test_adList_scratch_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing ccfromscratch on adList data structures for slashdot dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s adList -n 82168 -a ccfromscratch -t 1 | tee -a Slashdot_adList_scratch_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing ccfromscratch on adList data structures for facebook dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s adList -n 4039 -a ccfromscratch -t 1 | tee -a facebook_adList_scratch_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing ccdyn on adList data structures for test.csv
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f ./test.csv -b 10 -t 24 -s adList -n 40 -a ccdyn -t 1 | tee -a test_adList_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing ccdyn on adList data structures for slashdot dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 1 -w 0 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s adList -n 82168 -a ccdyn -t 1 | tee -a Slashdot_adList_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done

#Testing ccdyn on adList data structures for facebook dataset
for (( i=1; i<=5; i++ )); do
    ./frontEnd -d 0 -w 0 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s adList -n 4039 -a ccdyn -t 1 | tee -a facebook_adList_dyn_$i.log
    rm Update.csv
    rm Alg.csv
done