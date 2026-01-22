#include "pigo.hpp"
#include <iostream>
#include <fstream>
#include <string>

using namespace std;
using namespace pigo;

int main(int argc, char** argv) {
    if (argc != 3) {
        cerr << "Usage: " << argv[0] << " input_file output_edgelist" << endl;
        return 1;
    }
    
    // Load graph from PIGO format
    Graph g { argv[1] };
    cout << "number of vertices: " << g.n() << endl;
    cout << "number of edges: " << g.m() << endl;
    
    // Open output file for edgelist
    ofstream outfile(argv[2]);
    if (!outfile.is_open()) {
        cerr << "Error: Could not open output file " << argv[2] << endl;
        return 1;
    }
    
    // Convert CSR to edgelist
    cout << "Converting to edgelist format..." << endl;
    
    // Iterate through all vertices
    for (uint32_t u = 0; u < g.n(); u++) {
        // Get the neighbor range using PIGO's API
        auto start = g.neighbor_start(u);
        auto end = g.neighbor_end(u);
        
        // Iterate through all neighbors of u using the iterator
        for (auto v : g.neighbors(u)) {
            // Write edge to file
            outfile << u << " " << v << "\n";
        }
    }
    
    outfile.close();
    cout << "Edgelist written to " << argv[2] << endl;
    
    return 0;
}