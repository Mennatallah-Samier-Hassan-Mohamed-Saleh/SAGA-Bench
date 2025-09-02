#!/bin/bash

#Needed Paths
dataDir=$SCRATCH/datasets/SAGAdatasets/
sagaDir=$SCRATCH/Masters_thesis/Thesis/SAGA-Bench

#Defining datasets
DATASETS=(soc-LiveJournal1       
com-orkut.ungraph
wiki-topcats
wiki-Talk
)

for dataset in "${DATASETS[@]}"; do  
    cd ${dataDir}
    echo "Working on dataset: ${dataset}"
    echo "----------------------------------------"
    echo "Downloading the dataset: ${dataset}.txt.gz"
    if [[ "${dataset}" == "com-orkut.ungraph" ]];
    then
      echo " Downloading dataset from https://snap.stanford.edu/data/bigdata/communities/${dataset}.txt.gz"
      wget https://snap.stanford.edu/data/bigdata/communities/${dataset}.txt.gz
    else 
      echo " Downloading dataset from https://snap.stanford.edu/data/${dataset}.txt.gz"
      wget https://snap.stanford.edu/data/${dataset}.txt.gz
    fi
    echo "Decompressing the dataset: ${dataset}.txt.gz"
    gunzip ${dataset}.txt.gz
    echo "Shuffling the dataset: ${dataset}.txt"
    bash ${sagaDir}/inputResource/shuffle.sh $dataDir/${dataset}.txt /scratch/ms13779/sortdump
    echo "Adding weights(maximum weight of 1) and timestamps to the dataset: ${dataset}.txt"  
    cd   ${sagaDir}/inputResource/
    bash ./addWeightAndTime.sh ${dataDir}/${dataset}.txt 3 1
    echo " "
done
echo "All datasets have been processed successfully!"
