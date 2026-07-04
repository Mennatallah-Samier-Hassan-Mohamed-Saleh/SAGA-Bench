#ifndef ABSLBTREESET_H_
#define ABSLBTREESET_H_

#include <iostream>
#include "absl/container/btree_set.h"

#include "abstract_data_struc.h"
#include "print.h"

// T must define operator< for btree_set ordering and setInfo method
template <typename T>
class abslBtreeSet: public dataStruc {
private:
    bool vertexExists(const Edge& e, bool source);
    void updateForNewVertex(const Edge& e, bool source);
    void updateForExistingVertex(const Edge& e, bool source);

public:
    std::vector<absl::btree_set<T>> out_neighbors;
    std::vector<absl::btree_set<T>> in_neighbors;

    abslBtreeSet(bool w, bool d, int64_t _num_nodes_max);
    void update(const EdgeList& el) override;
    void print() override;
    int64_t in_degree(NodeID n) override;
    int64_t out_degree(NodeID n) override;
};

template <typename T>
abslBtreeSet<T>::abslBtreeSet(bool w, bool d, int64_t _num_nodes_max)
    : dataStruc(w, d, _num_nodes_max) 
{ 
    std::cout << "Creating abslBtreeSet" << std::endl;
    property.resize(num_nodes_max, -1);    
    affected.resize(num_nodes_max); 
    affected.fill(false);

    out_neighbors.resize(num_nodes_max);    
    in_neighbors.resize(num_nodes_max);
}


/**
 * check if vertex exists based on Edge flags
 * update number of nodes and edges
 * mark vertex as affected
 * return true if vertex exists, false otherwise
 * **/
template <typename T>
bool abslBtreeSet<T>::vertexExists(const Edge& e, bool source)
{
    bool exists = source ? e.sourceExists : e.destExists;
    NodeID index = source ? e.source : e.destination;
    
    if (exists) {
        num_edges++;
        affected[index] = 1;  // CHANGED: Use index directly instead of push_back
        return true;
    } else {
        num_nodes++;
        num_edges++;
        affected[index] = 1;  // CHANGED: Use index directly instead of push_back
        return false;
    }
}

/**
 * update data structures for a new vertex
 * add new neighbor to out_neighbors or in_neighbors based on source flag
 * add empty neighbor set for the other direction if directed   
 * requires T to define operator< for ordering and setInfo for setting neighbor info
 * makes use of absl::btree_set to maintain ordered unique neighbors
 * more efficient for moderate number of neighbors compared to vector + sort + unique
 * **/
template <typename T>
void abslBtreeSet<T>::updateForNewVertex(const Edge& e, bool source)
{
    NodeID index = source ? e.source : e.destination;  // ADDED: Calculate index
    
    // REMOVED: property.push_back(-1) - already pre-allocated with -1
    
    if (source || (!source && !directed)) {
        T neighbor;
        if (source) neighbor.setInfo(e.destination, e.weight);
        else neighbor.setInfo(e.source, e.weight);

        // CHANGED: Use index instead of push_back
        // out_neighbors[index] is already an empty btree_set from resize
        out_neighbors[index].insert(neighbor);
        
        // REMOVED: No need to push empty in_neighbors - already pre-allocated
    }
    else if (!source && directed) {
        T neighbor;
        neighbor.setInfo(e.source, e.weight);

        // CHANGED: Use index instead of push_back
        // in_neighbors[index] is already an empty btree_set from resize
        in_neighbors[index].insert(neighbor);
        
        // REMOVED: No need to push empty out_neighbors - already pre-allocated
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
void abslBtreeSet<T>::updateForExistingVertex(const Edge& e, bool source)
{
    NodeID index = source ? e.source : e.destination;

    if (source || (!source && !directed)) {
        NodeID dest = source ? e.destination : e.source;
        T neighbor; 
        neighbor.setInfo(dest, e.weight);
        auto& neighbors = out_neighbors[index];

        auto it = neighbors.find(neighbor);
        if (it != neighbors.end()) {
            T updatedNeighbor = *it;
            updatedNeighbor.setInfo(dest, e.weight);
            neighbors.erase(it);
            neighbors.insert(updatedNeighbor);
        } else {
            neighbors.insert(neighbor);
        }
    }
    else if (!source && directed) {
        T neighbor; 
        neighbor.setInfo(e.source, e.weight);
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

/**
 * Process a batch of edges to update the graph
 * For each edge, check and update both source and destination vertices
 * Calls vertexExists to check existence and update counts
 * Calls updateForNewVertex or updateForExistingVertex as needed    
 * **/
template <typename T>
void abslBtreeSet<T>::update(const EdgeList& el)
{
    for (auto it = el.begin(); it != el.end(); ++it) {
        Edge e = *it;  // local mutable copy
        bool isSelfLoop = (e.source == e.destination);

        // Process source vertex
        bool exists = vertexExists(e, true);
        if (!exists)
            updateForNewVertex(e, true);
        else
            updateForExistingVertex(e, true);

        // For a self-loop, the node was just accounted for above —
        // force the second pass to treat it as "existing" so num_nodes
        // isn't incremented twice for the same node.
        if (isSelfLoop) {
            e.destExists = true;
        }

        // Process destination vertex
        bool exists1 = vertexExists(e, false);
        if (!exists1)
            updateForNewVertex(e, false);
        else
            updateForExistingVertex(e, false);
    }
}

template <typename T>
int64_t abslBtreeSet<T>::in_degree(NodeID n)
{
    if (directed)
        return in_neighbors[n].size();
    else
        return out_neighbors[n].size();
}

template <typename T>
int64_t abslBtreeSet<T>::out_degree(NodeID n)
{
    return out_neighbors[n].size();
}

template <typename T>
void abslBtreeSet<T>::print()
{
    std::cout << " numNodes: " << num_nodes
              << " numEdges: " << num_edges
              << " weighted: " << weighted
              << " directed: " << directed
              << std::endl;
}

#endif  // ABSLBTREESET_H_