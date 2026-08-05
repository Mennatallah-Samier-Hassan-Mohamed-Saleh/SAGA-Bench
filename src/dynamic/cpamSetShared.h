#ifndef CPAMSETSHARED_H_
#define CPAMSETSHARED_H_

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <iostream>
#include <utility>
#include <vector>
#include <omp.h>

#include "cpam/cpam.h"
#include "parlay/sequence.h"
#include "parlay/primitives.h"

#include "abstract_data_struc.h"
#include "print.h"
#include "cpamSet.h"

bool compare_and_swap(bool &x, const bool &old_val, const bool &new_val);
/**
 * cpamSetShared: adaptive CSR batching with optimized tiny-batch updates.
 *
 * Large batches:
 *   degree count -> prefix sum -> scatter -> sort/deduplicate each CSR row
 *   -> direct from_sorted() for empty trees
 *   -> multi_insert_sorted() for non-empty trees
 *
 * Tiny dynamic batches:
 *   process edges sequentially and update each affected adjacency tree
 *   directly with a one-element multi_insert_sorted() call. This avoids
 *   OpenMP setup, record construction, sorting, grouping, and temporary
 *   batch buffers for batches containing at most 100 edges.
 *
 * Other small and medium batches:
 *   compact -> sort by (vertex, neighbor), using std::sort for small record
 *   arrays and Parlay parallel sort for record arrays of at least 100,000
 *   entries -> copy once into one contiguous neighbor buffer -> deduplicate
 *   each vertex range in place -> zero-allocation per-range views passed to
 *   the sorted CPAM API
 *
 * Important:
 *   - No unordered_map preprocessing.
 *   - No global sort of all edges for the large-batch path.
 *   - No generic multi_insert() in either path.
 *   - No per-vertex batch allocation or copy in either flush path.
 *   - No per-vertex mutex is needed because each flush iteration owns one tree.
 *   - BYO-aligned sorted update policy: generic replace lambda plus direct
 *     multi_insert_sorted(), while retaining zero-copy CSR row views and
 *     std::move ownership transfer for SAGA-Bench.
 *
 * Build requirements:
 *   -fopenmp -DPARLAY_OPENMP
 */
template <typename T>
class cpamSetShared : public dataStruc {
public:
    using edge_tree = cpam::pam_set<cpam_edge_entry<T>, 64>;

private:
    /** Lightweight mutable view accepted by CPAM's public sorted APIs. */
    template <typename U>
    struct array_view {
        U* ptr;
        std::size_t length;

        U* data() noexcept { return ptr; }
        U* data() const noexcept { return ptr; }
        U* begin() noexcept { return ptr; }
        U* begin() const noexcept { return ptr; }
        U* end() noexcept { return ptr + length; }
        U* end() const noexcept { return ptr + length; }
        std::size_t size() const noexcept { return length; }
    };

    struct batch_record {
        NodeID vertex;
        T neighbor;
    };

    /**
     * Selects between sparse sorted batching and linear CSR batching.
     *
     * Updates generating at most 2,000,000 adjacency records use the
     * sparse path. Larger updates use the linear CSR path.
     *
     * The strict comparison in update_direction() keeps the largest tested
     * undirected dynamic batch (1,000,000 edges = 2,000,000 adjacency
     * records) on the sparse path, while larger initial graph batches use
     * the CSR path.
     */
    static constexpr std::size_t TINY_BATCH_THRESHOLD = 100;
    static constexpr std::size_t PARALLEL_SORT_THRESHOLD = 500'000;
    static constexpr std::size_t CSR_BATCH_THRESHOLD = 2'000'000;

    static bool neighbor_less(const T& a, const T& b) {
        return a < b;
    }

    static bool neighbor_equal_key(const T& a, const T& b) {
        return !neighbor_less(a, b) && !neighbor_less(b, a);
    }

    static bool record_less(const batch_record& a, const batch_record& b) {
        if (a.vertex != b.vertex) return a.vertex < b.vertex;
        return neighbor_less(a.neighbor, b.neighbor);
    }

    // Same replacement policy used by the BYO CPAM wrapper.  Keeping this
    // generic avoids depending on pam_set's internal parlay::empty value type.
    static auto replace_value() {
        return [] (const auto& old_value, const auto& new_value) {
            (void)old_value;
            return new_value;
        };
    }

    void update_metadata(const EdgeList& el);
    void update_one_edge_metadata(const Edge& e);
    void update_one_edge_direct(const Edge& e);
    void update_tiny_batch_direct(const EdgeList& el);
    void insert_one_sorted(edge_tree& tree, T& neighbor);
    void update_direction(const EdgeList& el, bool incoming);
    void update_direction_linear_csr(const EdgeList& el, bool incoming);
    void update_direction_sparse(const EdgeList& el, bool incoming);

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
    property.resize(num_nodes_max, -1);
    affected.resize(num_nodes_max);
    affected.fill(false);

    out_neighbors.resize(num_nodes_max);
    if (directed) in_neighbors.resize(num_nodes_max);
}

template <typename T>
void cpamSetShared<T>::update_metadata(const EdgeList& el)
{
    int64_t edge_delta = 0;
    int64_t node_delta = 0;

    #pragma omp parallel for reduction(+:edge_delta,node_delta) schedule(static)
    for (std::size_t k = 0; k < el.size(); ++k) {
        const Edge& e = el[k];
        if (e.source == e.destination) continue;

        edge_delta += 2;
        node_delta += static_cast<int64_t>(!e.sourceExists);
        node_delta += static_cast<int64_t>(!e.destExists);

        bool source_affected = affected[e.source];
        if (!source_affected) {
            compare_and_swap(affected[e.source], source_affected, true);
        }

        bool dest_affected = affected[e.destination];
        if (!dest_affected) {
            compare_and_swap(affected[e.destination], dest_affected, true);
        }
    }

    num_edges += edge_delta;
    num_nodes += node_delta;
}

/**
 * Sequential metadata path for exactly one edge.
 *
 * This avoids launching an OpenMP region for a one-edge batch.
 * It preserves the same metadata semantics as update_metadata().
 */
template <typename T>
void cpamSetShared<T>::update_one_edge_metadata(const Edge& e)
{
    if (e.source == e.destination) return;

    bool source_affected = affected[e.source];
    if (!source_affected) {
        compare_and_swap(affected[e.source], source_affected, true);
    }

    bool dest_affected = affected[e.destination];
    if (!dest_affected) {
        compare_and_swap(affected[e.destination], dest_affected, true);
    }

    num_edges += 2;
    num_nodes += static_cast<int64_t>(!e.sourceExists);
    num_nodes += static_cast<int64_t>(!e.destExists);
}

template <typename T>
void cpamSetShared<T>::insert_one_sorted(edge_tree& tree, T& neighbor)
{
    array_view<T> one{&neighbor, 1};
    const auto replace = replace_value();

    if (tree.is_empty()) {
        tree = edge_tree::from_sorted(one);
    } else {
        tree = edge_tree::multi_insert_sorted(
            std::move(tree), one, replace);
    }
}

/**
 * Direct path for exactly one input edge.
 *
 * This deliberately uses a one-element sorted CPAM update instead of the
 * member insert() API. The member insert() path previously showed instability
 * in this integration, while multi_insert_sorted() is already known to be
 * correct and supports the same weighted replacement policy as larger batches.
 *
 * The path is sequential, so there is no race even when an undirected edge
 * updates both endpoint trees. No mutex or OpenMP region is needed.
 */
template <typename T>
void cpamSetShared<T>::update_one_edge_direct(const Edge& e)
{
    if (e.source == e.destination) return;

    if (directed) {
        T out_neighbor;
        out_neighbor.setInfo(e.destination, e.weight);
        insert_one_sorted(
            out_neighbors[static_cast<std::size_t>(e.source)],
            out_neighbor);

        T in_neighbor;
        in_neighbor.setInfo(e.source, e.weight);
        insert_one_sorted(
            in_neighbors[static_cast<std::size_t>(e.destination)],
            in_neighbor);
    } else {
        T forward_neighbor;
        forward_neighbor.setInfo(e.destination, e.weight);
        insert_one_sorted(
            out_neighbors[static_cast<std::size_t>(e.source)],
            forward_neighbor);

        T reverse_neighbor;
        reverse_neighbor.setInfo(e.source, e.weight);
        insert_one_sorted(
            out_neighbors[static_cast<std::size_t>(e.destination)],
            reverse_neighbor);
    }
}


/**
 * Direct path for tiny batches.
 *
 * The batch is processed sequentially to avoid OpenMP startup and to ensure
 * that two edges targeting the same vertex tree cannot race.
 *
 * Each non-self-loop edge receives the same metadata handling and direct
 * one-element sorted CPAM updates used by the single-edge path.
 */
template <typename T>
void cpamSetShared<T>::update_tiny_batch_direct(const EdgeList& el)
{
    for (std::size_t k = 0; k < el.size(); ++k) {
        const Edge& e = el[k];

        if (e.source == e.destination) continue;

        update_one_edge_metadata(e);
        update_one_edge_direct(e);
    }
}

template <typename T>
void cpamSetShared<T>::update_direction(const EdgeList& el, bool incoming)
{
    const std::size_t multiplier = (!directed && !incoming) ? 2 : 1;
    const std::size_t estimated_records = el.size() * multiplier;

    if (estimated_records > CSR_BATCH_THRESHOLD) {
        update_direction_linear_csr(el, incoming);
    } else {
        update_direction_sparse(el, incoming);
    }
}

/**
 * Linear-time CSR preprocessing for large batches.
 *
 * The scatter only groups entries by owner vertex. The row_sort stage then
 * sorts and removes duplicate CPAM keys inside every CSR row. The flush passes
 * each row directly to CPAM without allocating a per-row parlay::sequence.
 */
template <typename T>
void cpamSetShared<T>::update_direction_linear_csr(
    const EdgeList& el, bool incoming)
{
    const std::size_t vertex_count = static_cast<std::size_t>(num_nodes_max);

    std::vector<std::size_t> counts(vertex_count, 0);

    #pragma omp parallel for schedule(static)
    for (std::size_t k = 0; k < el.size(); ++k) {
        const Edge& e = el[k];
        if (e.source == e.destination) continue;

        if (incoming) {
            #pragma omp atomic update
            counts[static_cast<std::size_t>(e.destination)] += 1;
        } else if (directed) {
            #pragma omp atomic update
            counts[static_cast<std::size_t>(e.source)] += 1;
        } else {
            #pragma omp atomic update
            counts[static_cast<std::size_t>(e.source)] += 1;
            #pragma omp atomic update
            counts[static_cast<std::size_t>(e.destination)] += 1;
        }
    }

    std::vector<std::size_t> offsets(vertex_count + 1, 0);
    std::vector<NodeID> touched_vertices;
    touched_vertices.reserve(std::min<std::size_t>(vertex_count, el.size()));

    for (std::size_t v = 0; v < vertex_count; ++v) {
        offsets[v + 1] = offsets[v] + counts[v];
        if (counts[v] != 0) {
            touched_vertices.push_back(static_cast<NodeID>(v));
        }
    }

    const std::size_t record_count = offsets[vertex_count];
    if (record_count == 0) return;

    parlay::sequence<T> endpoints(record_count);
    std::vector<std::size_t> cursor(offsets.begin(), offsets.end() - 1);

    #pragma omp parallel for schedule(static)
    for (std::size_t k = 0; k < el.size(); ++k) {
        const Edge& e = el[k];
        if (e.source == e.destination) continue;

        if (incoming) {
            const std::size_t v = static_cast<std::size_t>(e.destination);
            std::size_t pos;
            #pragma omp atomic capture
            { pos = cursor[v]; cursor[v]++; }

            T neighbor;
            neighbor.setInfo(e.source, e.weight);
            endpoints[pos] = std::move(neighbor);
        } else if (directed) {
            const std::size_t v = static_cast<std::size_t>(e.source);
            std::size_t pos;
            #pragma omp atomic capture
            { pos = cursor[v]; cursor[v]++; }

            T neighbor;
            neighbor.setInfo(e.destination, e.weight);
            endpoints[pos] = std::move(neighbor);
        } else {
            const std::size_t source = static_cast<std::size_t>(e.source);
            const std::size_t destination = static_cast<std::size_t>(e.destination);

            std::size_t out_pos;
            #pragma omp atomic capture
            { out_pos = cursor[source]; cursor[source]++; }

            T out_neighbor;
            out_neighbor.setInfo(e.destination, e.weight);
            endpoints[out_pos] = std::move(out_neighbor);

            std::size_t reverse_pos;
            #pragma omp atomic capture
            { reverse_pos = cursor[destination]; cursor[destination]++; }

            T reverse_neighbor;
            reverse_neighbor.setInfo(e.source, e.weight);
            endpoints[reverse_pos] = std::move(reverse_neighbor);
        }
    }

    // Number of sorted, unique CPAM keys retained in each row.
    std::vector<std::size_t> unique_sizes(touched_vertices.size(), 0);

    #pragma omp parallel for schedule(dynamic, 256)
    for (std::size_t i = 0; i < touched_vertices.size(); ++i) {
        const std::size_t v = static_cast<std::size_t>(touched_vertices[i]);
        T* first = endpoints.data() + offsets[v];
        T* last = endpoints.data() + offsets[v + 1];

        std::sort(first, last, neighbor_less);
        T* unique_end = std::unique(first, last, neighbor_equal_key);
        unique_sizes[i] = static_cast<std::size_t>(unique_end - first);
    }

    std::vector<edge_tree>& trees = incoming ? in_neighbors : out_neighbors;
    const auto replace = replace_value();

    #pragma omp parallel for schedule(dynamic, 256)
    for (std::size_t i = 0; i < touched_vertices.size(); ++i) {
        const std::size_t v = static_cast<std::size_t>(touched_vertices[i]);
        const std::size_t unique_count = unique_sizes[i];
        if (unique_count == 0) continue;

        array_view<T> row{
            endpoints.data() + offsets[v],
            unique_count
        };

        if (trees[v].is_empty()) {
            // Direct linear build. Requires sorted, duplicate-free input.
            trees[v] = edge_tree::from_sorted(row);
        } else {
            // Direct sorted update: bypasses Build::sort_remove_duplicates().
            trees[v] = edge_tree::multi_insert_sorted(
                std::move(trees[v]), row, replace);
        }
    }

}

/**
 * Sparse path for tiny dynamic batches.
 *
 * The records are globally sorted only because this path is used below the
 * threshold. Each vertex range is already sorted by neighbor, so this path
 * deduplicates once and calls CPAM's sorted API directly.
 */
template <typename T>
void cpamSetShared<T>::update_direction_sparse(
    const EdgeList& el, bool incoming)
{
    const bool duplicate_for_undirected = !directed && !incoming;
    const int thread_count = omp_get_max_threads();

    std::vector<std::size_t> thread_counts(thread_count, 0);

    #pragma omp parallel
    {
        const int tid = omp_get_thread_num();
        std::size_t local = 0;

        #pragma omp for schedule(static)
        for (std::size_t k = 0; k < el.size(); ++k) {
            if (el[k].source != el[k].destination) {
                ++local;
            }
        }

        thread_counts[tid] = local;
    }

    std::vector<std::size_t> thread_offsets(thread_count + 1, 0);

    for (int t = 0; t < thread_count; ++t) {
        thread_offsets[t + 1] =
            thread_offsets[t] + thread_counts[t];
    }

    const std::size_t valid_edges = thread_offsets[thread_count];
    const std::size_t record_count =
        duplicate_for_undirected ? 2 * valid_edges : valid_edges;

    if (record_count == 0) return;

    std::vector<batch_record> records(record_count);

    #pragma omp parallel
    {
        const int tid = omp_get_thread_num();
        std::size_t pos = thread_offsets[tid];

        #pragma omp for schedule(static)
        for (std::size_t k = 0; k < el.size(); ++k) {
            const Edge& e = el[k];

            if (e.source == e.destination) continue;

            if (incoming) {
                T neighbor;
                neighbor.setInfo(e.source, e.weight);

                records[pos++] = batch_record{
                    e.destination,
                    std::move(neighbor)
                };
            } else {
                T neighbor;
                neighbor.setInfo(e.destination, e.weight);

                records[pos] = batch_record{
                    e.source,
                    std::move(neighbor)
                };

                if (duplicate_for_undirected) {
                    T reverse_neighbor;
                    reverse_neighbor.setInfo(e.source, e.weight);

                    records[valid_edges + pos] = batch_record{
                        e.destination,
                        std::move(reverse_neighbor)
                    };
                }

                ++pos;
            }
        }
    }

    if (record_count >= PARALLEL_SORT_THRESHOLD) {
        parlay::sort_inplace(records, record_less);
    } else {
        std::sort(
            records.begin(),
            records.end(),
            record_less
        );
    }

    struct range {
        NodeID vertex;
        std::size_t begin;
        std::size_t end;
    };

    std::vector<range> ranges;
    ranges.reserve(record_count);

    std::size_t begin = 0;

    while (begin < record_count) {
        std::size_t end = begin + 1;

        while (end < record_count &&
               records[end].vertex == records[begin].vertex) {
            ++end;
        }

        ranges.push_back(range{
            records[begin].vertex,
            begin,
            end
        });

        begin = end;
    }

    parlay::sequence<T> neighbors(record_count);

    #pragma omp parallel for schedule(static)
    for (std::size_t i = 0; i < record_count; ++i) {
        neighbors[i] = std::move(records[i].neighbor);
    }

    std::vector<std::size_t> unique_sizes(ranges.size(), 0);

    #pragma omp parallel for schedule(dynamic, 256)
    for (std::size_t i = 0; i < ranges.size(); ++i) {
        const range& r = ranges[i];

        T* first = neighbors.data() + r.begin;
        T* last = neighbors.data() + r.end;

        T* unique_end =
            std::unique(first, last, neighbor_equal_key);

        unique_sizes[i] =
            static_cast<std::size_t>(unique_end - first);
    }

    std::vector<edge_tree>& trees =
        incoming ? in_neighbors : out_neighbors;

    const auto replace = replace_value();

    /*
     * Sparse ranges often contain only one record, but the corresponding
     * existing CPAM trees can differ greatly in size. A chunk size of 256
     * can therefore cause load imbalance on skewed graphs such as Orkut.
     *
     * Dynamic scheduling with one range per task distributes expensive
     * persistent-tree updates more evenly across worker threads.
     */
    #pragma omp parallel for schedule(dynamic, 1)
    for (std::size_t i = 0; i < ranges.size(); ++i) {
        const std::size_t unique_count = unique_sizes[i];

        if (unique_count == 0) continue;

        const range& r = ranges[i];
        const std::size_t v =
            static_cast<std::size_t>(r.vertex);

        array_view<T> row{
            neighbors.data() + r.begin,
            unique_count
        };

        if (trees[v].is_empty()) {
            trees[v] = edge_tree::from_sorted(row);
        } else {
            trees[v] = edge_tree::multi_insert_sorted(
                std::move(trees[v]),
                row,
                replace
            );
        }
    }
}

template <typename T>
void cpamSetShared<T>::update(const EdgeList& el)
{
    if (el.empty()) return;

    if (el.size() <= TINY_BATCH_THRESHOLD) {
        update_tiny_batch_direct(el);
        return;
    }

    update_metadata(el);
    update_direction(el, false);

    if (directed) {
        update_direction(el, true);
    }
}

template <typename T>
int64_t cpamSetShared<T>::in_degree(NodeID n)
{
    if (directed) {
        return in_neighbors[static_cast<std::size_t>(n)].size();
    }
    return out_neighbors[static_cast<std::size_t>(n)].size();
}

template <typename T>
int64_t cpamSetShared<T>::out_degree(NodeID n)
{
    return out_neighbors[static_cast<std::size_t>(n)].size();
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
