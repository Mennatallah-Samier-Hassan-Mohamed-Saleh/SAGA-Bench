#!/bin/bash

#Clearing any previous csv files
rm Alg*.csv
rm Update*.csv 

#Needed Paths
dataDir=$SCRATCH/datasets/SAGAdatasets/
sagaDir=$SCRATCH/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

STRUCTURES=(degAwareRHH)
BatchSizes=(
  200000 250000 300000 375000 400000 500000 600000 750000 1000000 1500000 2000000 3000000
)
RUNS=3
NumThreads=128

# whether each algorithm is weighted or unweighted
declare -A ALGORITHMS 
ALGORITHMS=(              
         [bfsdyn]=0       
)

# Max num_nodes to initialize for each dataset
declare -A DATASETS
DATASETS=(
       [wiki-topcats.shuffle.t.w.csv]=1791489
)

cd $sagaDir
runs=${RUNS}
while [ $runs -gt 0 ]
do 
  for dataset in "${!DATASETS[@]}"; do  
    for structure in "${STRUCTURES[@]}"; do
      for algorithm in "${!ALGORITHMS[@]}"; do 
        for batchSize in "${!BatchSizes[@]}"; do 
          echo ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${BatchSizes[batchSize]} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}   
          ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${BatchSizes[batchSize]} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}  
          DIRECTORY=$HOME/SAGA-Bench/scalability/${algorithm}/${structure}/${dataset}/${BatchSizes[batchSize]}/Run${runs}      
          mkdir -p ${DIRECTORY}
          mv Alg*.csv ${DIRECTORY}/
          mv Update*.csv ${DIRECTORY}/
        done
      done    
    done  
  done 
runs=$(( $runs - 1 ))
done 
