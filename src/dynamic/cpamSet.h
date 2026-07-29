#ifndef CPAMSET_H_
#define CPAMSET_H_

#include <iostream>
#include <unordered_map>
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
    void collectVertex(const Edge& e, bool source,
                        std::unordered_map<NodeID, std::vector<T>>& out_batches,
                        std::unordered_map<NodeID, std::vector<T>>& in_batches);

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
 * Accumulates a neighbor entry for e.source or e.destination into this
 * batch's per-vertex staging maps, instead of inserting into the tree
 * immediately. update() below flushes each touched vertex's staged
 * entries with ONE multi_insert call per vertex per update() call,
 * rather than one multi_insert call per edge.
 *
 * Why this is worth doing: multi_insert's own cost (sort_remove_duplicates
 * + multi_insert_sorted) is amortized much better over a real batch than
 * over repeated size-1 batches — CPAM is designed around bulk construction,
 * and a real per-vertex batch is what actually exercises that path.
 *
 * NOTE on weighted graphs: for T=NodeWeight, cpam_edge_entry::comp uses
 * NodeWeight::operator<, which compares (node, weight) as a pair — two
 * entries with the same destination node but different weight are NOT
 * treated as duplicate keys by CPAM's sort_remove_duplicates. So if a
 * single batch contains two edges to the same neighbor with different
 * weights, both survive as separate tree entries (inflating degree by
 * one) rather than the newer weight replacing the older one. This is a
 * pre-existing property of the same comparator abslBtreeSet<NodeWeight>
 * uses too, not something batching introduces — but batching increases
 * the odds of it showing up within a single update() call, so it's worth
 * knowing about when comparing degree counts against another structure.
 * **/
template <typename T>
void cpamSet<T>::collectVertex(const Edge& e, bool source,
                                std::unordered_map<NodeID, std::vector<T>>& out_batches,
                                std::unordered_map<NodeID, std::vector<T>>& in_batches)
{
    NodeID index = source ? e.source : e.destination;

    if (source || (!source && !directed)) {
        NodeID dest = source ? e.destination : e.source;
        T neighbor;
        neighbor.setInfo(dest, e.weight);
        out_batches[index].push_back(neighbor);
    }
    else if (!source && directed) {
        T neighbor;
        neighbor.setInfo(e.source, e.weight);
        in_batches[index].push_back(neighbor);
    }
}

/**
 * Process a batch of edges. Bookkeeping (vertexExists, self-loop handling)
 * is unchanged from the per-edge version. The difference: neighbor entries
 * are staged per-vertex in out_batches/in_batches during the loop, then
 * flushed with one multi_insert call per touched vertex afterward — so a
 * vertex that receives, say, 40 new edges within this single update() call
 * gets ONE multi_insert(tree, batch_of_40) instead of 40 separate
 * multi_insert(tree, batch_of_1) calls.
 * **/
template <typename T>
void cpamSet<T>::update(const EdgeList& el)
{
    std::unordered_map<NodeID, std::vector<T>> out_batches;
    std::unordered_map<NodeID, std::vector<T>> in_batches;

    for (auto it = el.begin(); it != el.end(); ++it) {
        Edge e = *it;
        bool isSelfLoop = (e.source == e.destination);

        vertexExists(e, true);
        collectVertex(e, true, out_batches, in_batches);

        if (isSelfLoop) {
            e.destExists = true;
        }

        vertexExists(e, false);
        collectVertex(e, false, out_batches, in_batches);
    }

    for (auto& kv : out_batches) {
        NodeID index = kv.first;
        parlay::sequence<T> batch(kv.second.begin(), kv.second.end());
        out_neighbors[index] = edge_tree::multi_insert(out_neighbors[index], batch);
    }
    for (auto& kv : in_batches) {
        NodeID index = kv.first;
        parlay::sequence<T> batch(kv.second.begin(), kv.second.end());
        in_neighbors[index] = edge_tree::multi_insert(in_neighbors[index], batch);
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