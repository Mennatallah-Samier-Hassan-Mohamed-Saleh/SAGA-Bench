#!/bin/bash
#Clearing any previous csv files
rm Alg*.csv
rm Update*.csv 

#Needed Paths
dataDir=/scratch/ms13779/datasets/SAGAdatasets/


# Define the data structures to be used and other parameters
STRUCTURES=(adListChunked adListShared degAwareRHH stinger)
batchSize=500000 
RUNS=30
NumThreads=128

# whether each algorithm is weighted or unweighted
declare -A ALGORITHMS 
ALGORITHMS=(         
         [ccdyn]=0         
         [ccfromscratch]=0 
         [prdyn]=0
         [prfromscratch]=0         
         [bfsdyn]=0
         [bfsfromscratch]=0 
         [mcdyn]=0 
         [mcfromscratch]=0
         [sswpdyn]=1
         [sswpfromscratch]=1
         [ssspdyn]=1
         [ssspfromscratch]=1         
)

# Max num_nodes to initialize for each dataset
declare -A DATASETS
DATASETS=(
       [soc-LiveJournal1.shuffle.t.w.csv]=4847571       
       [com-orkut.ungraph.shuffle.t.w.csv]=3072441       
       [rmat.shuffle.t.w.csv]=33554432
       [wiki-topcats.shuffle.t.w.csv]=1791489
       [wiki-Talk.shuffle.t.w.csv]=2394385
)

# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

# 3. Move into it
cd "$sagaDir" || exit
echo "Successfully moved to sagaDir: $PWD"
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