#ifndef CPAMSETSHARED_H_
#define CPAMSETSHARED_H_

#include <iostream>
#include <mutex>
#include <unordered_map>
#include "cpam/cpam.h"
#include "parlay/sequence.h"

#include "abstract_data_struc.h"
#include "print.h"
#include "cpamSet.h"      // reuses cpam_edge_entry<T> to avoid a duplicate
                          // definition when both cpamSet.h and this file
                          // are included together (topDataStruc.h does).
#include "stinger_atomics.h"

bool compare_and_swap(bool &x, const bool &old_val, const bool &new_val);

/**
 * IMPORTANT — this structure is only safe to build at all because
 * external/CPAM's allocator (parlay::type_allocator -> block_allocator)
 * indexes a per-worker memory pool by parlay::worker_id(). Without
 * -DPARLAY_OPENMP in the Makefile, parlay falls back to its own homegrown
 * scheduler's worker_id(), which is a thread_local defaulting to 0 for any
 * thread parlay itself didn't spawn — meaning every OpenMP thread would
 * collide on allocator slot 0. Confirmed empirically: the same concurrent
 * multi_insert pattern used below, compiled WITHOUT -DPARLAY_OPENMP,
 * produced heap corruption (`free(): invalid size`, `munmap_chunk():
 * invalid pointer`, SEGV) in 4 of 5 runs. WITH -DPARLAY_OPENMP (which
 * makes parlay::worker_id() == omp_get_thread_num()), 10/10 runs were
 * clean. If this file is ever built without that flag, treat every
 * result as untrustworthy regardless of whether it happens to not crash.
 *
 * TWO-PHASE DESIGN (replaces an earlier "parallel over edges, mutex per
 * edge" version after measurement showed it was ~3.6x slower than
 * abslBtreeSetShared even at matched, equal thread counts — the earlier
 * version paid multi_insert's sort_remove_duplicates overhead on every
 * single edge, batch-of-1, instead of amortizing it like cpamSet.h does):
 *
 * Phase 1 (sequential): walk the edge list once, do bookkeeping, and
 * group each edge's neighbor entry into out_batches/in_batches, keyed by
 * vertex. This is cheap relative to the tree work in phase 2 — it's the
 * same grouping cpamSet.h does, just not yet parallelized itself.
 *
 * Phase 2 (parallel over vertices, not edges): flush each touched
 * vertex's full accumulated batch with ONE multi_insert call. This is
 * safe WITHOUT locking out_neighbors[index]/in_neighbors[index]: because
 * out_batches/in_batches are keyed by NodeID in an unordered_map, each
 * key — and therefore each vertex index touched in this loop — appears
 * exactly once. No two parallel iterations can touch the same array
 * slot, so there's nothing to race on. out_mutex/in_mutex are kept only
 * for in_degree()/out_degree() (called from algorithm code after update()
 * has fully returned, never concurrently with a write), not used during
 * update() itself.
 * **/
template <typename T>
class cpamSetShared: public dataStruc {
public:
    using edge_tree = cpam::pam_set<cpam_edge_entry<T>, 64>;

private:
    void processMetaData(const Edge& e, bool source);
    void collectVertex(const Edge& e, bool source,
                        std::unordered_map<NodeID, std::vector<T>>& out_batches,
                        std::unordered_map<NodeID, std::vector<T>>& in_batches);

    std::vector<std::unique_ptr<std::mutex>> in_mutex, out_mutex;

public:
    std::vector<edge_tree> out_neighbors;
    std::vector<edge_tree> in_neighbors;

    cpamSetShared(bool w, bool d, int64_t _num_nodes_max);
    void update(const EdgeList& el) override;
    void print() override;
    int64_t in_degree(NodeID n) override;
    int64_t out_degree(NodeID n) override;
};

template <typename T>
cpamSetShared<T>::cpamSetShared(bool w, bool d, int64_t _num_nodes_max)
    : dataStruc(w, d, _num_nodes_max)
{
    std::cout << "Creating cpamSetShared" << std::endl;
    property.resize(num_nodes_max, -1);
    affected.resize(num_nodes_max);
    affected.fill(false);

    out_neighbors.resize(num_nodes_max);
    in_neighbors.resize(num_nodes_max);

    out_mutex.resize(num_nodes_max);
    in_mutex.resize(num_nodes_max);
    for (unsigned int k = 0; k < num_nodes_max; k++) {
        out_mutex[k].reset(new std::mutex());
        in_mutex[k].reset(new std::mutex());
    }
}

template <typename T>
void cpamSetShared<T>::processMetaData(const Edge& e, bool source)
{
    bool exists = source ? e.sourceExists : e.destExists;
    NodeID v = source ? e.source : e.destination;

    bool aff = affected[v];
    if (!aff) {
        compare_and_swap(affected[v], aff, true);
    }

    if (exists) {
        stinger_int64_fetch_add(&num_edges, 1);
    } else {
        stinger_int64_fetch_add(&num_nodes, 1);
        stinger_int64_fetch_add(&num_edges, 1);
    }
}

/**
 * Same accumulation role as cpamSet<T>::collectVertex: stage a neighbor
 * entry into this batch's per-vertex map instead of inserting immediately.
 * **/
template <typename T>
void cpamSetShared<T>::collectVertex(const Edge& e, bool source,
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
 * See the class-level comment for the two-phase design. Self-loops are
 * skipped entirely here, matching abslBtreeSetShared's behavior (not
 * cpamSet's self-loop accounting) — a pre-existing ST/MT inconsistency
 * in this codebase, not something introduced here.
 * **/
template <typename T>
void cpamSetShared<T>::update(const EdgeList& el)
{
    std::unordered_map<NodeID, std::vector<T>> out_batches;
    std::unordered_map<NodeID, std::vector<T>> in_batches;

    // Phase 1: sequential bookkeeping + grouping.
    for (unsigned int k = 0; k < el.size(); k++) {
        if (el[k].source == el[k].destination) continue;  // skip self-loops entirely
        processMetaData(el[k], true);
        collectVertex(el[k], true, out_batches, in_batches);

        processMetaData(el[k], false);
        collectVertex(el[k], false, out_batches, in_batches);
    }

    // Phase 2: parallel flush, one multi_insert per touched vertex.
    // Flatten to vectors first so OpenMP has something index-addressable
    // to parallelize over.
    std::vector<std::pair<NodeID, std::vector<T>>> out_flat(out_batches.begin(), out_batches.end());
    std::vector<std::pair<NodeID, std::vector<T>>> in_flat(in_batches.begin(), in_batches.end());

    #pragma omp parallel for schedule(dynamic)
    for (size_t i = 0; i < out_flat.size(); i++) {
        NodeID index = out_flat[i].first;
        parlay::sequence<T> batch(out_flat[i].second.begin(), out_flat[i].second.end());
        out_neighbors[index] = edge_tree::multi_insert(out_neighbors[index], batch);
    }

    #pragma omp parallel for schedule(dynamic)
    for (size_t i = 0; i < in_flat.size(); i++) {
        NodeID index = in_flat[i].first;
        parlay::sequence<T> batch(in_flat[i].second.begin(), in_flat[i].second.end());
        in_neighbors[index] = edge_tree::multi_insert(in_neighbors[index], batch);
    }
}

template <typename T>
int64_t cpamSetShared<T>::in_degree(NodeID n)
{
    if (directed) {
        std::lock_guard<std::mutex> guard(*in_mutex[n]);
        return in_neighbors[n].size();
    } else {
        std::lock_guard<std::mutex> guard(*out_mutex[n]);
        return out_neighbors[n].size();
    }
}

template <typename T>
int64_t cpamSetShared<T>::out_degree(NodeID n)
{
    std::lock_guard<std::mutex> guard(*out_mutex[n]);
    return out_neighbors[n].size();
}

template <typename T>
void cpamSetShared<T>::print()
{
    std::cout << " numNodes: " << num_nodes
              << " numEdges: " << num_edges
              << " weighted: " << weighted
              << " directed: " << directed
              << std::endl;
}

#endif  // CPAMSETSHARED_H_