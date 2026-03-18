#!/bin/bash

#Clearing any previous csv files
rm Alg*.csv
rm Update*.csv 

#Needed Paths
dataDir=$SCRATCH/datasets/SAGAdatasets/


STRUCTURES=(adListChunked adListShared stinger abslBtreeSetShared)
NumberBatches=10
#Define the batch sizes to be used as a logaraithmic scale
# The first batch size is 1, the second is 10, the third is 100, and so on.
# The last batch size is 10 million
# The batch sizes are used to test the scalability of the algorithms
BatchSizes=(
  1 10 100 1000 10000 100000 1000000
)
# The total number of edges in the wiki-topcast dataset
TotalEdges=1000009380
RUNS=6
NumThreads=128

# whether each algorithm is weighted or unweighted
declare -A ALGORITHMS 
ALGORITHMS=(              
         [bfsdyn]=0       
)

# Max num_nodes to initialize for each dataset
declare -A DATASETS
DATASETS=(
        [er.shuffle.t.w.csv]=10000000
)

# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export PROJECT_ROOT=$(realpath "$SCRIPT_DIR/..")

# 3. Move into it
cd "$PROJECT_ROOT" || exit
echo "Successfully moved to PROJECT_ROOT: $PWD"
runs=${RUNS}
while [ $runs -gt 0 ]
do 
  for dataset in "${!DATASETS[@]}"; do  
    for structure in "${STRUCTURES[@]}"; do
      for algorithm in "${!ALGORITHMS[@]}"; do 
        for batchSize in "${!BatchSizes[@]}"; do 
          InitialBatchSize=$(($TotalEdges - 10 * ${BatchSizes[batchSize]}))
          echo "Running with initial batch size: $InitialBatchSize"
          echo ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${BatchSizes[batchSize]} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads} -i $InitialBatchSize
          ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${BatchSizes[batchSize]} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}  -i $InitialBatchSize
          DIRECTORY=$HOME/SAGA-Bench/Logarithmin-scalability-fixed-bathes/${algorithm}/${structure}/${dataset}/${BatchSizes[batchSize]}/Run${runs}      
          mkdir -p ${DIRECTORY}
          mv Alg*.csv ${DIRECTORY}/
          mv Update*.csv ${DIRECTORY}/
        done
      done    
    done  
  done 
runs=$(( $runs - 1 ))
done 