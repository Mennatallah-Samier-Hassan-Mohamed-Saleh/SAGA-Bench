#include <unistd.h>
#include <fstream>
#include <cstring>
#include <mutex>
#include <thread>

#include "topDataStruc.h"
#include "parser.h"
#include "pigo.hpp"
#include "../common/timer.h"
#include <random>
#include "topAlg.h"

using namespace pigo;
/* Main thread that launches everything else */

int main(int argc, char* argv[])
{    
    cmd_args opts = parse(argc, argv);

  /*Step 1: Graph reading */
   Timer t;
   t.Start();
   Graph g{opts.filename};
   t.Stop();
   cout << "Time to load graph: " << t.Seconds() << " seconds" << endl;
   cout << "number of vertices: " << g.n() << endl;
   cout << "number of edges: " << g.m() << endl;

    /*Step 2: Change CSR to Edge List*/
    cout << "Converting to edgelist format..." << endl;
    EdgeList allEdges;
    allEdges.reserve(g.m());

    bool weighted = opts.weighted;
    // Using a fixed seed for reproducibility of random weights and shuffling
    mt19937 rng(kRandSeed);
    // If weighted, set up a uniform distribution for weights in the specified range
    std::uniform_int_distribution<Weight> uweight(opts.min_weight, opts.max_weight);  
    t.Start();
    for (uint32_t u = 0; u < g.n(); u++) {
        for (auto v : g.neighbors(u)) {
            Edge e;
            e.source      = u;
            e.destination = v;
            // If the graph is weighted, assign a random integer weight; otherwise, use 1
            e.weight      = weighted ? uweight(rng) : 1;  
            allEdges.push_back(e);
        }
    }
    t.Stop();

    cout << "Time to convert to edgelist: " << t.Seconds() << " seconds" << endl;
    cout << "Results in: " << allEdges.size() << " edges" << endl;

    /*Step 3: Shuffle the edge list in memory. */
    cout << "Shuffling edges..." << endl;
    t.Start();
    //mt19937 rng(kRandSeed);
    shuffle(allEdges.begin(), allEdges.end(), rng);
    t.Stop();
    cout << "Time to shuffle edges: " << t.Seconds() << " seconds" << endl;
    cout << "Shuffle complete" << endl;
 
    /*Solution 1: Re-assign exists flags after shuffle */
    vector<bool> nodeSeen(g.n(), false); 
    for (auto& e : allEdges) {
        e.sourceExists = nodeSeen[e.source];
        e.destExists   = nodeSeen[e.destination];
        nodeSeen[e.source] = true;
        nodeSeen[e.destination] = true;
    }

    /*Step 4: Create data structure and algorithm */
    dataStruc* struc = createDataStruc(opts.type, opts.weighted, opts.directed, g.n(), opts.num_threads);   
    Algorithm alg(opts.algorithm, struc, opts.type, opts.verbose);

    /*Step 5: Slice into batches, update, and run algorithm inline */
    int64_t start_batch_size = (opts.initial_batch_size != 0) ? opts.initial_batch_size : opts.batch_size;
    int batch_id = 0;
    size_t offset = 0;
    size_t total = allEdges.size();
    
    while (offset < total)
        {
            int64_t current_batch_size = (batch_id == 0) ? start_batch_size : opts.batch_size;
            size_t end = std::min(offset + (size_t)current_batch_size, total);

            // Slice batch from allEdges
            //EdgeList el(allEdges.begin() + offset, allEdges.begin() + end);
            const std::size_t batch_length = end - offset;

            EdgeList el(batch_length);

            #pragma omp parallel for schedule(static)
            for (std::size_t i = 0; i < batch_length; ++i) {
                el[i] = allEdges[offset + i];
            }

            // Update data structure
            t.Start();
            struc->update(el);
            t.Stop();

            ofstream out("Update.csv", std::ios_base::app);
            out << t.Seconds() << endl;
            out.close();

            cout << "Updated batch: " << batch_id << endl;

            // Run algorithm on updated graph
            alg.performAlg();

            offset = end;
            batch_id++;
    }

    cout << "Total batches processed: " << batch_id << endl;
    struc->print();
}
    /*
    ifstream file(opts.filename);
    if (!file.is_open()) {
        cout << "Couldn't open file " << opts.filename << endl;
	exit(-1);
    }    

    std::mutex q_lock;
    
    EdgeBatchQueue queue;
    bool loop = true;  
    dataStruc* struc = createDataStruc(opts.type, opts.weighted, opts.directed, opts.num_nodes, opts.num_threads);    
    std::thread t1(dequeAndInsertEdge, opts.type, struc, &queue, &q_lock, opts.algorithm, &loop);   
    
    cpu_set_t cpuset;
    CPU_ZERO(&cpuset);
    CPU_SET(1, &cpuset);

    int rc = pthread_setaffinity_np(t1.native_handle(), sizeof(cpu_set_t), &cpuset);
    
    if (rc != 0) {
        std::cerr << "Error calling pthread_setaffinity_np: " << rc << "\n";
    }

    int batch_id = 0;
    NodeID lastAssignedNodeID = -1;
    MapTable VMAP;
    // Initial batch can be different than the rest of the batches for scalability experiments
    int64_t start_batch_size = (opts.initial_batch_size!= 0) ? opts.initial_batch_size : opts.batch_size;
    while (!file.eof()) {        
        EdgeList el = readBatchFromCSV(
	    file,
	    start_batch_size,
	    batch_id,
	    opts.weighted,
	    VMAP,
	    lastAssignedNodeID);
        if (el.empty()) {
            break;
        }
	q_lock.lock();     
        queue.push(el);
	q_lock.unlock();
	batch_id++;  
    start_batch_size = opts.batch_size;        
    }
    file.close();

    bool allEmpty = false;
    while (!allEmpty) {   
        q_lock.lock();
	allEmpty = queue.empty();
	q_lock.unlock();
	sleep(20);
    }
    
    loop = false;
    t1.join();
    
    //cout << "Started printing queues " << endl;
    //printEdgeBatchQueue(queue);
    //cout << "Done printing queues " << endl;    
    struc->print();
}
*/