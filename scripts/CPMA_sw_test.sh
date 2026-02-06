#!/bin/bash
#Clearing any previous csv files
rm Alg*.csv
rm Update*.csv 

#Needed Paths
dataDir=/scratch/ms13779/datasets/SAGAdatasets/
sagaDir=$SCRATCH/Masters_thesis/Thesis/Integrate_PIGO_SAGA-Bench/SAGA-Bench

# Define the data structures to be used and other parameters
STRUCTURES=(adList adListChunked adListShared degAwareRHH stinger abslBtreeSet abslBtreeSetShared)
batchSize=8000000 
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
       [lj.shuffle.t.w.csv]=4847571       
       [co.shuffle.t.w.csv]=3072627       
       [er.shuffle.t.w.csv]=10000000
       [tw.shuffle.t.w.csv]=61578415
       [fs.shuffle.t.w.csv]=124836180
)

cd $sagaDir
runs=${RUNS}
while [ $runs -gt 0 ]
do 
  for dataset in "${!DATASETS[@]}"; do  
    for structure in "${STRUCTURES[@]}"; do
      for algorithm in "${!ALGORITHMS[@]}"; do 
        # if-else to make sure orkut runs in undirected mode 
        if [ "$dataset" == "com-orkut.ungraph.shuffle.t.w.csv" ]; 
        then
         echo ./frontEnd -d 0 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${batchSize} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}   
         ./frontEnd -d 0 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${batchSize} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}   
        else 
         echo ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${batchSize} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}   
        ./frontEnd -d 1 -w ${ALGORITHMS[$algorithm]} -f ${dataDir}$dataset -b ${batchSize} -s $structure -n ${DATASETS[$dataset]} -a $algorithm -t ${NumThreads}
        fi        
        # make right directory and move the two generated files into it  
        DIRECTORY=$HOME/SAGA-Bench/baseline/${algorithm}/${structure}/${dataset}/Run${runs}      
        mkdir -p ${DIRECTORY}
        mv Alg*.csv ${DIRECTORY}/
        mv Update*.csv ${DIRECTORY}/
      done    
    done  
  done 
runs=$(( $runs - 1 ))
done 