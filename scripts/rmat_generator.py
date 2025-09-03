import snap
import sys
import time

if len(sys.argv) < 2:
    print("Usage: rmat_generator.py <output_file_name>")
    sys.exit(1)

#Setting the parameters for R-MAT graph
filename = sys.argv[1]
N= 33554432
M= 500000000
a=0.55
b=c=0.15

# Initialize random number generator
print("Start random number generator:")
rnd_time_start=time.time()
Rnd = snap.TRnd()
rnd_time_end=time.time()
print("Random number generator initialized in", rnd_time_end - rnd_time_start, "seconds.")

# Generate R-MAT graph
print("Generating R-MAT graph with N =", N, "nodes and M =", M, "edges.")
graph_time_start=time.time()
Graph = snap.GenRMat(N, M,a,b,c, Rnd)
graph_time_end=time.time()
print("Graph generated in", graph_time_end - graph_time_start, "seconds.")

# Save the graph to an edge list file
print("Saving graph to", filename)
save_time_start=time.time()
snap.SaveEdgeList(Graph, filename)
save_time_end=time.time()
print("Graph saved in", save_time_end - save_time_start, "seconds.")

# Print total time taken
print("Total time:", (rnd_time_end - rnd_time_start) + (graph_time_end - graph_time_start) + (save_time_end - save_time_start), "seconds.")