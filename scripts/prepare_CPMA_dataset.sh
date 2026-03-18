#!/bin/bash

#Needed Paths
dataDir=$SCRATCH/datasets/SAGAdatasets/
# 1. Find the directory where THIS script lives
SCRIPT_DIR=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)

# 2. Get the absolute path of the parent (SAGA-Bench)
# This goes up one level from 'scripts/'
export sagaDir=$(realpath "$SCRIPT_DIR/..")

#Defining datasets
DATASETS=(fs)

for dataset in "${DATASETS[@]}"; do  
    cd ${dataDir}
    echo "Working on dataset: ${dataset}"
    echo "----------------------------------------"
    echo "Shuffling the dataset: ${dataset}.txt"
    bash ${sagaDir}/inputResource/shuffle.sh $dataDir/${dataset}.txt /scratch/ms13779/sortdump
    echo "Adding weights(maximum weight of 1) and timestamps to the dataset: ${dataset}.txt"  
    cd   ${sagaDir}/inputResource/
    bash ./addWeightAndTime.sh ${dataDir}/${dataset}.shuffle.txt 3 1
    echo " "
done
echo "All datasets have been processed successfully!"
