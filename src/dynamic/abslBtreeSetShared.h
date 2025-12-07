#ifndef ABSLBTREESETSHARED_H_
#define ABSLBTREESETSHARED_H_

#include <iostream>
#include "absl/container/btree_set.h"

#include <thread>
#include <stdlib.h>
#include <mutex>

#include <cassert>
#include "x86_full_empty.h"
#include "stinger_atomics.h"

#include "abstract_data_struc.h"
#include "print.h"

bool compare_and_swap(bool &x, const bool &old_val, const bool &new_val);

// T can be either node or nodeweight
template <typename T>
class abslBtreeSetShared: public dataStruc {
private: 
    void processMetaData(const Edge& e, bool source);
    void updateForExistingVertex(const Edge& e, bool source);
    

    std::vector<std::unique_ptr<std::mutex>> in_mutex, out_mutex;
    int64_t num_nodes_initialize;

public:
    std::vector<absl::btree_set<T>> out_neighbors;
    std::vector<absl::btree_set<T>> in_neighbors;

    abslBtreeSetShared(bool w, bool d,int64_t _num_nodes);
    void update(const EdgeList& el) override;
    void print() override;
    int64_t in_degree(NodeID n) override;
    int64_t out_degree(NodeID n) override;
};

template <typename T>
abslBtreeSetShared<T>::abslBtreeSetShared(bool w, bool d,int64_t _num_nodes): dataStruc(w, d), num_nodes_initialize(_num_nodes) { 
    std::cout << "Creating abslBtreeSetShared" << std::endl;
    property.resize(num_nodes_initialize, -1);    
    affected.resize(num_nodes_initialize); affected.fill(false);

    out_neighbors.resize(num_nodes_initialize);    
    in_neighbors.resize(num_nodes_initialize);
    
    // Malloc for mutex.
    out_mutex.resize(num_nodes_initialize);
    in_mutex.resize(num_nodes_initialize);
    for  (unsigned int k = 0; k< num_nodes_initialize; k++){
        out_mutex[k].reset(new std::mutex());
        in_mutex[k].reset(new std::mutex());
    }
}

template <typename T>
void abslBtreeSetShared<T>::processMetaData(const Edge& e, bool source) {
    bool exists;
    if(source) exists = e.sourceExists;
    else exists = e.destExists;

     // choose vertex id depending on source/destination
    NodeID v = source ? e.source : e.destination;

    bool aff = affected[v];

    if(!aff){
        compare_and_swap(affected[v], aff, true);
    }
    
    if(exists){       
        stinger_int64_fetch_add(&num_edges, 1);                 
    }
    else{
        stinger_int64_fetch_add(&num_nodes, 1); 
        stinger_int64_fetch_add(&num_edges, 1);            
    }  
}

 /** 
  * Update data structures for an existing vertex
  * if neighbor exists, erase and re-insert with updated info
  * if neighbor does not exist, 
        *simply insert this ensures no duplicate neighbors and keeps the set ordered
  * requires T to define operator< for ordering
  * and setInfo for updating neighbor information
  * this approach is efficient for moderate number of neighbors
  * **/
template <typename T>
void abslBtreeSetShared<T>::updateForExistingVertex(const Edge& e, bool source)
{
    NodeID index = source ? e.source : e.destination;

    if (source || (!source && !directed)) {
        NodeID dest = source ? e.destination : e.source;
        T neighbor; 
        neighbor.setInfo(dest, e.weight);

        // protect this vertex’s adjacency set
        std::lock_guard<std::mutex> guard(*out_mutex[index]);
        auto& neighbors = out_neighbors[index];

        // find existing
        auto it = neighbors.find(neighbor);

        if (it != neighbors.end()) {
             // Erase old and insert updated version
            T updatedNeighbor = *it;
            updatedNeighbor.setInfo(dest, e.weight);
            neighbors.erase(it);
            neighbors.insert(updatedNeighbor);
        } else {
             // Insert new neighbor
            neighbors.insert(neighbor);
        }
    }
    else if (!source && directed) {
        T neighbor; 
        neighbor.setInfo(e.source, e.weight);

        std::lock_guard<std::mutex> guard(*in_mutex[index]);
        auto& neighbors = in_neighbors[index];

        auto it = neighbors.find(neighbor);
        if (it != neighbors.end()) {
            T updatedNeighbor = *it;
            updatedNeighbor.setInfo(e.source, e.weight);
            neighbors.erase(it);
            neighbors.insert(updatedNeighbor);
        } else {
            neighbors.insert(neighbor);
        }
    }
}

template <typename T>
void abslBtreeSetShared<T>::update(const EdgeList& el)
{
    # pragma omp parallel for 
    for (unsigned int k = 0; k < el.size(); k ++) {
        processMetaData(el[k], true);
        updateForExistingVertex(el[k], true);

        processMetaData(el[k], false);
        updateForExistingVertex(el[k], false); 
    }               
}

template <typename T>
int64_t abslBtreeSetShared<T>::in_degree(NodeID n)
{
    if(directed) {
        std::lock_guard<std::mutex> guard(*in_mutex[n]);
	    return in_neighbors[n].size(); }
    else {
        std::lock_guard<std::mutex> guard(*out_mutex[n]);
	    return out_neighbors[n].size(); }
}

template <typename T>
int64_t abslBtreeSetShared<T>::out_degree(NodeID n)
{
    std::lock_guard<std::mutex> guard(*out_mutex[n]);
    return out_neighbors[n].size();   
}

template <typename T>
void abslBtreeSetShared<T>::print()
{
    std::cout << " numNodes: " << num_nodes
              << " numEdges: " << num_edges
              << " weighted: " << weighted
              << " directed: " << directed
              << std::endl;
}

#endif  // ABSLBTREESETSHARED_H_
