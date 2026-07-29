#ifndef CPAMSET_H_
#define CPAMSET_H_

#include <iostream>
#include "cpam/cpam.h"
#include "parlay/sequence.h"

#include "abstract_data_struc.h"
#include "print.h"

// T must define operator< (used by cpam_edge_entry::comp for ordering)
// and setInfo/getNodeID/getWeight, same contract as abslBtreeSet<T>.
template <typename T>
struct cpam_edge_entry {
    using key_t = T;
    static inline bool comp(const key_t& a, const key_t& b) { return a < b; }
};

template <typename T>
class cpamSet: public dataStruc {
public:
    // pam_set<Entry, BlockSize>: BlockSize=64 matches the block size used
    // in BYO's run_vector_cpam.cc reference wrapper. Public (not private,
    // unlike abslBtreeSet's private helpers) because traversal.h's iterator
    // specialization needs this type to call edge_tree::entries().
    using edge_tree = cpam::pam_set<cpam_edge_entry<T>, 64>;

private:
    bool vertexExists(const Edge& e, bool source);
    void updateVertex(const Edge& e, bool source);

public:
    std::vector<edge_tree> out_neighbors;
    std::vector<edge_tree> in_neighbors;

    cpamSet(bool w, bool d, int64_t _num_nodes_max);
    void update(const EdgeList& el) override;
    void print() override;
    int64_t in_degree(NodeID n) override;
    int64_t out_degree(NodeID n) override;
};

template <typename T>
cpamSet<T>::cpamSet(bool w, bool d, int64_t _num_nodes_max)
    : dataStruc(w, d, _num_nodes_max)
{
    std::cout << "Creating cpamSet" << std::endl;
    property.resize(num_nodes_max, -1);
    affected.resize(num_nodes_max);
    affected.fill(false);

    // Default-constructed edge_tree is an empty persistent tree (root = NULL).
    out_neighbors.resize(num_nodes_max);
    in_neighbors.resize(num_nodes_max);
}

/**
 * Same bookkeeping role as abslBtreeSet<T>::vertexExists:
 * check existence from the Edge's flags, bump counters, mark affected.
 * **/
template <typename T>
bool cpamSet<T>::vertexExists(const Edge& e, bool source)
{
    bool exists = source ? e.sourceExists : e.destExists;
    NodeID index = source ? e.source : e.destination;

    if (exists) {
        num_edges++;
        affected[index] = 1;
        return true;
    } else {
        num_nodes++;
        num_edges++;
        affected[index] = 1;
        return false;
    }
}

/**
 * Insert/update a neighbor for vertex e.source or e.destination.
 *
 * Two things differ from abslBtreeSet here, both discovered by actually
 * compiling and running against real CPAM headers:
 *
 * 1. insert-or-replace: CPAM's insert already replaces the value on a
 *    duplicate key (map.h: the `replace` lambda returns the *new* value).
 *    absl::btree_set has no such semantics, which is why abslBtreeSet.h
 *    needs a separate updateForNewVertex/updateForExistingVertex split
 *    (find -> erase -> insert). One call covers both cases here.
 *
 * 2. edge_tree::insert() itself is unsafe: pam_set's single-element
 *    instance `.insert()` reliably crashes (assertion `tot >= B` in
 *    basic_node_helpers.h) on the *second* insert into the same tree —
 *    confirmed with a minimal reproduction outside SAGA-Bench entirely.
 *    `multi_insert(tree, batch)` — CPAM's actual designed bulk-insert
 *    path — does not have this problem, even with a batch of size 1.
 *    So every insert here goes through multi_insert with a single-element
 *    parlay::sequence, which is functionally a single insert but avoids
 *    the buggy code path.
 * **/
template <typename T>
void cpamSet<T>::updateVertex(const Edge& e, bool source)
{
    NodeID index = source ? e.source : e.destination;

    if (source || (!source && !directed)) {
        NodeID dest = source ? e.destination : e.source;
        T neighbor;
        neighbor.setInfo(dest, e.weight);
        parlay::sequence<T> batch = {neighbor};
        out_neighbors[index] = edge_tree::multi_insert(out_neighbors[index], batch);
    }
    else if (!source && directed) {
        T neighbor;
        neighbor.setInfo(e.source, e.weight);
        parlay::sequence<T> batch = {neighbor};
        in_neighbors[index] = edge_tree::multi_insert(in_neighbors[index], batch);
    }
}

/**
 * Process a batch of edges. Structurally identical to abslBtreeSet<T>::update,
 * including the self-loop handling: for a self-loop the source-side pass
 * already accounts for the node, so the destination-side pass is forced to
 * treat it as "existing" to avoid double counting.
 * **/
template <typename T>
void cpamSet<T>::update(const EdgeList& el)
{
    for (auto it = el.begin(); it != el.end(); ++it) {
        Edge e = *it;
        bool isSelfLoop = (e.source == e.destination);

        vertexExists(e, true);
        updateVertex(e, true);

        if (isSelfLoop) {
            e.destExists = true;
        }

        vertexExists(e, false);
        updateVertex(e, false);
    }
}

template <typename T>
int64_t cpamSet<T>::in_degree(NodeID n)
{
    if (directed)
        return in_neighbors[n].size();
    else
        return out_neighbors[n].size();
}

template <typename T>
int64_t cpamSet<T>::out_degree(NodeID n)
{
    return out_neighbors[n].size();
}

template <typename T>
void cpamSet<T>::print()
{
    std::cout << " numNodes: " << num_nodes
              << " numEdges: " << num_edges
              << " weighted: " << weighted
              << " directed: " << directed
              << std::endl;
}

#endif  // CPAMSET_H_
