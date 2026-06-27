#!/bin/bash
# This script compares the outputs of dynamic and from-scratch runs for all algorithms on the Facebook dataset.
# It assumes that the output files are named in the format:
#   - Dynamic: facebook_ALGOdyn_b1000.out
#   - From-scratch: facebook_ALGOfromscratch_b1000.out
# The comparison focuses on the lines starting from "Update batch: 10" to the end of the file.
# The differences are saved in files named diff_ALGO.txt for each algorithm.

for algo in bfs cc mc pr sssp sswp; do
    dyn="facebook_${algo}dyn_b1000.out"
    scratch="facebook_${algo}fromscratch_b1000.out"
    
    diff <(sed -n '/Update batch: 10/,$p' "$dyn") \
         <(sed -n '/Update batch: 10/,$p' "$scratch") \
         > "diff_${algo}.txt"
    
    echo "Done: diff_${algo}.txt"
done