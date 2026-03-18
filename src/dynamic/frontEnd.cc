#include <unistd.h>
#include <fstream>
#include <cstring>
#include <mutex>
#include <thread>

#include "builder.h"
#include "fileReader.h"
#include "topDataStruc.h"
#include "parser.h"
#include "pigo.hpp"
#include "../common/timer.h"
#include <random>

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
    vector<Edge> edgelist;
    edgelist.reserve(g.m());

    bool weighted = opts.weighted;
    t.Start();
    for (uint32_t u = 0; u < g.n(); u++) {
        for (auto v : g.neighbors(u)) {
            Edge e;
            e.source      = u;
            e.destination = v;
            e.weight      = weighted ? 1.0 : 0.0;  // default weight; replace if real weights available
            e.sourceExists = true;   // nodes exist since we're loading from a complete graph
            e.destExists   = true;
            edgelist.push_back(e);
        }
    }
    t.Stop();

    cout << "Time to convert to edgelist: " << t.Seconds() << " seconds" << endl;
    cout << "Results in: " << edgelist.size() << " edges" << endl;

    /*Step 3: Shuffle the edge list in memory. */
    cout << "Shuffling edges..." << endl;
    t.Start();
    mt19937 rng(42);
    shuffle(edgelist.begin(), edgelist.end(), rng);
    t.Stop();
    cout << "Time to shuffle edges: " << t.Seconds() << " seconds" << endl;
    cout << "Shuffle complete" << endl;

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