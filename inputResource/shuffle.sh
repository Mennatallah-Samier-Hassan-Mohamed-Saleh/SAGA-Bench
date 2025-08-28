#!/bin/bash

: '
This tool is based on the suggestion for shuffling edges in the Cassovary vs. GraphJet Github
repository (https://github.com/lintool/Cassovary-vs-GraphJet). It takes a graph edgelist in 
plain-text format (.txt) and shuffles them randomly. This tool is needed because a lot of our
graphs in the repository have their edges sorted numerically, which will not be representative
of real-life evolving graphs when being streamed. The format of the command to run is as follows:

$ ./shuffle.sh [input file] [temp_directory]

After the shuffling, the output graph will be written to the same directory as the input graph. 
In addition,the shuffled graph will have the suffix xxxx.shuffle.txt appended to it. 
'
# A Function to display usage instructions and exit with an error.
usage() {
  echo "Usage: $(basename "$0") <input_file> <temp_directory>"
  echo ""
  echo "This tool shuffles the lines of a graph edgelist file randomly."
  echo "The output is saved to <input_file>.shuffle.txt."
  echo ""
  echo "Required Parameters:"
  echo "  <input_file>      The path to the graph edgelist file (e.g., data.txt)."
  echo "  <temp_directory>  A directory for sort to use for temporary files (e.g., /home/user/tmp)."
  exit 1
}

# Get the input filename from the user
if [ $# -eq 2 ] 
then 
	inputFileName=$1
	dumpDir=$2
else
	echo "ERROR: Incorrect number of arguments provided." >&2
	usage
fi

# Check if the input file exists.
if [[ ! -f "$inputFileName" ]]; then
  echo "ERROR: Input file not found at '$inputFileName'." >&2
  exit 1
fi

# Check if the dump directory exists.
if [[ ! -d "$dumpDir" ]]; then
  echo "ERROR: Temporary directory not found at '$dumpDir'." >&2
  exit 1
fi

echo ""
echo "Starting shuffle for '$inputFileName'..."

# Shuffle the contents of the edgelist and write them out to a file (with suffix .shuffle.txt)
outputFileName="${inputFileName%.*}.shuffle.txt"
cat ${inputFileName} | awk 'BEGIN{srand();}{print rand()"\t"$0}' | sort -k1 -g -T ${dumpDir}| cut -f2- > ${outputFileName}

echo "Shuffling complete. Output saved to '$outputFileName'."
