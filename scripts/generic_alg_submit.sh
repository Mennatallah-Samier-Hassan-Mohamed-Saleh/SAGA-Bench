#!/bin/bash

# =======================
# SLURM Resource Settings
# =======================
#SBATCH -c 1
#SBATCH -t 24:00:00
#SBATCH --output=submit.out
#SBATCH --error=submit.err

# =======================
# Command-line argument
# =======================
# Check if the algorithm argument is provided
if [ $# -lt 1 ]; then
  echo "Usage: sbatch $0 <algorithm_name>"
  exit 1
fi

ALG=$1
echo "Algorithm selected: $ALG"

# =======================
# Cleanup old logs
# =======================
rm -f submit.out submit.err *_${ALG}.log Update.csv Alg.csv

# =======================
# Environment setup
# =======================
export OMP_DISPLAY_ENV=true
export OMP_NUM_THREADS=1

module purge
module load gcc cmake perl python libGl libx11 fontconfig mesa

cd $SCRATCH/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

# =======================
# Test dataset
# =======================
echo "Starting $ALG tests on adList for test.csv"
./frontEnd -d 1 -w 1 -f ./test.csv -b 10 -s adList -n 40 -a $ALG -t 1 | tee -a test_adList_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on abslBtreeSet for test.csv"
./frontEnd -d 1 -w 1 -f ./test.csv -b 10 -s abslBtreeSet -n 40 -a $ALG -t 1 | tee -a test_abslBtreeSet_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on stinger for test.csv"
./frontEnd -d 1 -w 1 -f ./test.csv -b 10 -s stinger -n 40 -a $ALG -t 1 | tee -a test_stinger_${ALG}.log
rm -f Update.csv Alg.csv

# =======================
# Slashdot dataset
# =======================
echo "Starting $ALG tests on adList for slashdot dataset"
./frontEnd -d 1 -w 1 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s adList -n 82168 -a $ALG -t 1 | tee -a Slashdot_adList_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on abslBtreeSet for slashdot dataset"
./frontEnd -d 1 -w 1 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s abslBtreeSet -n 82168 -a $ALG -t 1 | tee -a Slashdot_abslBtreeSet_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on stinger for slashdot dataset"
./frontEnd -d 1 -w 1 -f $SCRATCH/datasets/SAGAdatasets/soc-Slashdot0902.shuffle.t.w.csv -b 16352 -s stinger -n 82168 -a $ALG -t 1 | tee -a Slashdot_stinger_${ALG}.log
rm -f Update.csv Alg.csv

# =======================
# Facebook dataset
# =======================
echo "Starting $ALG tests on adList for facebook dataset"
./frontEnd -d 0 -w 1 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s adList -n 4039 -a $ALG -t 1 | tee -a facebook_adList_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on abslBtreeSet for facebook dataset"
./frontEnd -d 0 -w 1 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s abslBtreeSet -n 4039 -a $ALG -t 1 | tee -a facebook_abslBtreeSet_${ALG}.log
rm -f Update.csv Alg.csv

echo "Starting $ALG tests on stinger for facebook dataset"
./frontEnd -d 0 -w 1 -f $SCRATCH/datasets/SAGAdatasets/facebook_combined.shuffle.t.w.csv -b 1522 -s stinger -n 4039 -a $ALG -t 1 | tee -a facebook_stinger_${ALG}.log
rm -f Update.csv Alg.csv

echo "All tests completed for algorithm: $ALG"
exit 0