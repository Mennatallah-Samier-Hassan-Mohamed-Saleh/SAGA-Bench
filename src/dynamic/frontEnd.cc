#include <unistd.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <limits>
#include <random>
#include <vector>

#include <omp.h>

#include "topDataStruc.h"
#include "parser.h"
#include "pigo.hpp"
#include "../common/timer.h"
#include "topAlg.h"

using namespace pigo;

/*
 * Deterministic parallel global permutation.
 *
 * This uses a 32-bit Feistel permutation followed by cycle walking over
 * [0, n). Every input index maps to exactly one output index, so no edges
 * are lost or duplicated and the permutation is deterministic for a fixed
 * seed.
 *
 * IMPORTANT:
 * - This is a pseudorandom global permutation, not the same permutation
 *   distribution as std::shuffle.
 * - It requires one additional EdgeList of the same size during shuffling.
 * - It supports edge counts up to UINT32_MAX.
 */

static inline std::uint16_t feistel_round(
    std::uint16_t value,
    std::uint64_t seed,
    unsigned int round)
{
    std::uint32_t x = static_cast<std::uint32_t>(value);

    const std::uint32_t round_key =
        static_cast<std::uint32_t>(
            (seed >> ((round % 4U) * 16U)) ^
            (0x9e3779b9U * (round + 1U))
        );

    x ^= round_key;
    x *= 0x85ebca6bU;
    x ^= x >> 13U;
    x *= 0xc2b2ae35U;
    x ^= x >> 16U;

    return static_cast<std::uint16_t>(x & 0xffffU);
}

static inline std::uint32_t feistel_permute_32(
    std::uint32_t value,
    std::uint64_t seed)
{
    std::uint16_t left =
        static_cast<std::uint16_t>(value >> 16U);

    std::uint16_t right =
        static_cast<std::uint16_t>(value & 0xffffU);

    // An even number of rounds makes the construction easy to invert and
    // provides sufficient mixing for benchmark randomization.
    for (unsigned int round = 0; round < 8U; ++round) {
        const std::uint16_t next_left = right;

        const std::uint16_t next_right =
            static_cast<std::uint16_t>(
                left ^ feistel_round(right, seed, round)
            );

        left = next_left;
        right = next_right;
    }

    return
        (static_cast<std::uint32_t>(left) << 16U) |
        static_cast<std::uint32_t>(right);
}

static inline std::uint32_t permute_index(
    std::uint32_t index,
    std::uint32_t range_size,
    std::uint64_t seed)
{
    std::uint32_t value = index;

    // Cycle walking restricts the 32-bit permutation to [0, range_size).
    do {
        value = feistel_permute_32(value, seed);
    } while (value >= range_size);

    return value;
}

int main(int argc, char* argv[])
{
    cmd_args opts = parse(argc, argv);

    Timer t;

    /* Step 1: Graph reading. */
    t.Start();
    Graph g{opts.filename};
    t.Stop();

    std::cout << "Time to load graph: "
              << t.Seconds()
              << " seconds"
              << std::endl;

    std::cout << "number of vertices: "
              << g.n()
              << std::endl;

    std::cout << "number of edges: "
              << g.m()
              << std::endl;

    const bool algorithm_requires_source =
        opts.algorithm == "bfsdyn" ||
        opts.algorithm == "bfsfromscratch" ||
        opts.algorithm == "ssspdyn" ||
        opts.algorithm == "ssspfromscratch" ||
        opts.algorithm == "sswpdyn" ||
        opts.algorithm == "sswpfromscratch";

    if (algorithm_requires_source && opts.source != -1) {
        if (opts.source < 0 ||
            static_cast<std::size_t>(opts.source) >=
                static_cast<std::size_t>(g.n())) {

            std::cerr
                << "ERROR: Source vertex "
                << opts.source
                << " is outside the valid range [0, "
                << g.n()
                << ")."
                << std::endl;

            return 1;
        }
    }

    /* Step 2: Convert PIGO CSR to EdgeList. */
    std::cout << "Converting to edgelist format..."
              << std::endl;

    const std::size_t vertex_count =
        static_cast<std::size_t>(g.n());

    const std::size_t edge_count =
        static_cast<std::size_t>(g.m());

    const bool weighted = opts.weighted;

    // Preserve deterministic random weights for weighted runs.
    std::mt19937 rng(kRandSeed);

    std::uniform_int_distribution<Weight> uweight(
        opts.min_weight,
        opts.max_weight
    );

    EdgeList allEdges;

    t.Start();

    if (!weighted) {
        /*
         * Parallel unweighted CSR-to-EdgeList conversion.
         */
        std::vector<std::size_t> degrees(
            vertex_count,
            0
        );

        #pragma omp parallel for schedule(static)
        for (std::size_t u = 0; u < vertex_count; ++u) {
            std::size_t degree = 0;

            for (auto v :
                 g.neighbors(static_cast<std::uint32_t>(u))) {
                (void)v;
                ++degree;
            }

            degrees[u] = degree;
        }

        std::vector<std::size_t> offsets(
            vertex_count + 1,
            0
        );

        const int maximum_threads =
            omp_get_max_threads();

        std::vector<std::size_t> block_sums(
            static_cast<std::size_t>(maximum_threads),
            0
        );

        #pragma omp parallel
        {
            const int thread_id =
                omp_get_thread_num();

            const int team_size =
                omp_get_num_threads();

            const std::size_t block_begin =
                (vertex_count *
                 static_cast<std::size_t>(thread_id)) /
                static_cast<std::size_t>(team_size);

            const std::size_t block_end =
                (vertex_count *
                 static_cast<std::size_t>(thread_id + 1)) /
                static_cast<std::size_t>(team_size);

            std::size_t local_sum = 0;

            for (std::size_t u = block_begin;
                 u < block_end;
                 ++u) {
                local_sum += degrees[u];
                offsets[u + 1] = local_sum;
            }

            block_sums[
                static_cast<std::size_t>(thread_id)
            ] = local_sum;

            #pragma omp barrier

            #pragma omp single
            {
                std::size_t prefix = 0;

                for (int block = 0;
                     block < team_size;
                     ++block) {
                    const std::size_t block_total =
                        block_sums[
                            static_cast<std::size_t>(block)
                        ];

                    block_sums[
                        static_cast<std::size_t>(block)
                    ] = prefix;

                    prefix += block_total;
                }
            }

            const std::size_t block_offset =
                block_sums[
                    static_cast<std::size_t>(thread_id)
                ];

            for (std::size_t u = block_begin;
                 u < block_end;
                 ++u) {
                offsets[u + 1] += block_offset;
            }
        }

        if (offsets[vertex_count] != edge_count) {
            std::cerr
                << "ERROR: Parallel conversion counted "
                << offsets[vertex_count]
                << " edges, but PIGO reported "
                << edge_count
                << " edges."
                << std::endl;

            return 1;
        }

        allEdges.resize(edge_count);

        #pragma omp parallel for schedule(static)
        for (std::size_t u = 0;
             u < vertex_count;
             ++u) {
            std::size_t position = offsets[u];

            for (auto v :
                 g.neighbors(static_cast<std::uint32_t>(u))) {
                Edge edge;

                edge.source =
                    static_cast<NodeID>(u);

                edge.destination =
                    static_cast<NodeID>(v);

                edge.weight = 1;

                allEdges[position++] = edge;
            }
        }
    }
    else {
        /*
         * Keep weighted conversion serial so weight generation remains
         * deterministic and race-free.
         */
        allEdges.reserve(edge_count);

        for (std::uint32_t u = 0; u < g.n(); ++u) {
            for (auto v : g.neighbors(u)) {
                Edge edge;

                edge.source = u;
                edge.destination = v;
                edge.weight = uweight(rng);

                allEdges.push_back(edge);
            }
        }
    }

    t.Stop();

    std::cout << "Time to convert to edgelist: "
              << t.Seconds()
              << " seconds"
              << std::endl;

    std::cout << "Results in: "
              << allEdges.size()
              << " edges"
              << std::endl;

    /*
     * Step 3: Deterministic parallel global permutation.
     */
    std::cout << "Parallel shuffling edges..."
              << std::endl;

    if (edge_count == 0) {
        std::cout << "Time to parallel shuffle edges: 0 seconds"
                  << std::endl;
        std::cout << "Parallel shuffle complete"
                  << std::endl;
    }
    else {
        if (edge_count >
            static_cast<std::size_t>(
                std::numeric_limits<std::uint32_t>::max()
            )) {

            std::cerr
                << "ERROR: Parallel shuffle currently supports at most "
                << std::numeric_limits<std::uint32_t>::max()
                << " edges, but the graph has "
                << edge_count
                << "."
                << std::endl;

            return 1;
        }

        const std::uint32_t permutation_size =
            static_cast<std::uint32_t>(edge_count);

        const std::uint64_t shuffle_seed =
            static_cast<std::uint64_t>(kRandSeed);

        t.Start();

        {
            EdgeList shuffled(edge_count);

            #pragma omp parallel for schedule(static)
            for (std::size_t input_index = 0;
                 input_index < edge_count;
                 ++input_index) {

                const std::uint32_t output_index =
                    permute_index(
                        static_cast<std::uint32_t>(input_index),
                        permutation_size,
                        shuffle_seed
                    );

                shuffled[
                    static_cast<std::size_t>(output_index)
                ] = allEdges[input_index];
            }

            allEdges.swap(shuffled);
        }

        t.Stop();

        std::cout << "Time to parallel shuffle edges: "
                  << t.Seconds()
                  << " seconds"
                  << std::endl;

        std::cout << "Parallel shuffle complete"
                  << std::endl;
    }

    /*
     * Step 4: Reassign existence flags after shuffling.
     */
    std::vector<bool> nodeSeen(
        vertex_count,
        false
    );

    for (Edge& edge : allEdges) {
        edge.sourceExists =
            nodeSeen[
                static_cast<std::size_t>(edge.source)
            ];

        edge.destExists =
            nodeSeen[
                static_cast<std::size_t>(edge.destination)
            ];

        nodeSeen[
            static_cast<std::size_t>(edge.source)
        ] = true;

        nodeSeen[
            static_cast<std::size_t>(edge.destination)
        ] = true;
    }

    /*
     * Step 5: Create data structure and algorithm.
     */
    dataStruc* struc = createDataStruc(
        opts.type,
        opts.weighted,
        opts.directed,
        static_cast<std::int64_t>(g.n()),
        opts.num_threads
    );

    Algorithm alg(
        opts.algorithm,
        struc,
        opts.type,
        opts.verbose,
        static_cast<NodeID>(opts.source)
    );

    /*
     * Step 6: Validate batch sizes.
     */
    const std::int64_t start_batch_size =
        (opts.initial_batch_size != 0)
            ? opts.initial_batch_size
            : opts.batch_size;

    if (start_batch_size <= 0 ||
        opts.batch_size <= 0) {

        std::cerr
            << "ERROR: Batch sizes must be positive."
            << std::endl;

        return 1;
    }

    const std::size_t total =
        allEdges.size();

    const std::size_t initial_batch_size =
        static_cast<std::size_t>(
            start_batch_size
        );

    const std::size_t dynamic_batch_size =
        static_cast<std::size_t>(
            opts.batch_size
        );

    if (initial_batch_size > total) {
        std::cerr
            << "ERROR: Initial batch size "
            << initial_batch_size
            << " exceeds total edge count "
            << total
            << "."
            << std::endl;

        return 1;
    }

    /*
     * Step 7: Slice into batches, update, and run the algorithm.
     */
    std::size_t offset = 0;
    std::size_t batch_id = 0;

    std::ofstream update_output(
        "Update.csv",
        std::ios_base::app
    );

    if (!update_output) {
        std::cerr
            << "ERROR: Could not open Update.csv."
            << std::endl;

        return 1;
    }

    while (offset < total) {
        const std::size_t requested_batch_size =
            (batch_id == 0)
                ? initial_batch_size
                : dynamic_batch_size;

        const std::size_t remaining =
            total - offset;

        const std::size_t batch_length =
            std::min(
                requested_batch_size,
                remaining
            );

        const std::size_t end =
            offset + batch_length;

        /*
         * Parallel EdgeList batch materialization. The update mechanism is
         * unchanged.
         */
        EdgeList el(batch_length);

        #pragma omp parallel for schedule(static)
        for (std::size_t i = 0;
             i < batch_length;
             ++i) {
            el[i] = allEdges[offset + i];
        }

        t.Start();
        struc->update(el);
        t.Stop();

        update_output
            << t.Seconds()
            << '\n';

        std::cout << "Updated batch: "
                  << batch_id
                  << std::endl;

        alg.performAlg();

        offset = end;
        ++batch_id;
    }

    std::cout << "Total batches processed: "
              << batch_id
              << std::endl;

    struc->print();

    return 0;
}
