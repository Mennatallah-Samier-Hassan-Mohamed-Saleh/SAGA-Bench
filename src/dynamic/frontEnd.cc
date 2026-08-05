#include <unistd.h>

#include <algorithm>
#include <cstddef>
#include <cstdint>
#include <fstream>
#include <iostream>
#include <random>
#include <vector>

#include <omp.h>

#include "topDataStruc.h"
#include "parser.h"
#include "pigo.hpp"
#include "../common/timer.h"
#include "topAlg.h"

using namespace pigo;

int main(int argc, char* argv[])
{
    cmd_args opts = parse(argc, argv);
    Timer t;

    /* Step 1: Graph reading. */
    t.Start();
    Graph g{opts.filename};
    t.Stop();

    std::cout << "Time to load graph: " << t.Seconds() << " seconds" << std::endl;
    std::cout << "number of vertices: " << g.n() << std::endl;
    std::cout << "number of edges: " << g.m() << std::endl;

    /* Step 2: Convert PIGO CSR to EdgeList. */
    std::cout << "Converting to edgelist format..." << std::endl;

    const std::size_t vertex_count = static_cast<std::size_t>(g.n());
    const std::size_t edge_count = static_cast<std::size_t>(g.m());
    const bool weighted = opts.weighted;

    std::mt19937 rng(kRandSeed);
    std::uniform_int_distribution<Weight> uweight(
        opts.min_weight,
        opts.max_weight
    );

    EdgeList allEdges;
    t.Start();

    if (!weighted) {
        std::vector<std::size_t> degrees(vertex_count, 0);

        #pragma omp parallel for schedule(static)
        for (std::size_t u = 0; u < vertex_count; ++u) {
            std::size_t degree = 0;
            for (auto v : g.neighbors(static_cast<uint32_t>(u))) {
                (void)v;
                ++degree;
            }
            degrees[u] = degree;
        }

        std::vector<std::size_t> offsets(vertex_count + 1, 0);
        const int maximum_threads = omp_get_max_threads();
        std::vector<std::size_t> block_sums(
            static_cast<std::size_t>(maximum_threads),
            0
        );

        #pragma omp parallel
        {
            const int thread_id = omp_get_thread_num();
            const int team_size = omp_get_num_threads();

            const std::size_t block_begin =
                (vertex_count * static_cast<std::size_t>(thread_id)) /
                static_cast<std::size_t>(team_size);

            const std::size_t block_end =
                (vertex_count * static_cast<std::size_t>(thread_id + 1)) /
                static_cast<std::size_t>(team_size);

            std::size_t local_sum = 0;

            for (std::size_t u = block_begin; u < block_end; ++u) {
                local_sum += degrees[u];
                offsets[u + 1] = local_sum;
            }

            block_sums[static_cast<std::size_t>(thread_id)] = local_sum;

            #pragma omp barrier

            #pragma omp single
            {
                std::size_t prefix = 0;
                for (int block = 0; block < team_size; ++block) {
                    const std::size_t block_total =
                        block_sums[static_cast<std::size_t>(block)];
                    block_sums[static_cast<std::size_t>(block)] = prefix;
                    prefix += block_total;
                }
            }

            const std::size_t block_offset =
                block_sums[static_cast<std::size_t>(thread_id)];

            for (std::size_t u = block_begin; u < block_end; ++u) {
                offsets[u + 1] += block_offset;
            }
        }

        if (offsets[vertex_count] != edge_count) {
            std::cerr << "ERROR: Parallel conversion counted "
                      << offsets[vertex_count]
                      << " edges, but PIGO reported "
                      << edge_count
                      << " edges."
                      << std::endl;
            return 1;
        }

        allEdges.resize(edge_count);

        #pragma omp parallel for schedule(static)
        for (std::size_t u = 0; u < vertex_count; ++u) {
            std::size_t position = offsets[u];

            for (auto v : g.neighbors(static_cast<uint32_t>(u))) {
                Edge edge;
                edge.source = static_cast<NodeID>(u);
                edge.destination = static_cast<NodeID>(v);
                edge.weight = 1;
                allEdges[position++] = edge;
            }
        }
    } else {
        /* Keep weighted conversion serial for deterministic weight assignment. */
        allEdges.reserve(edge_count);

        for (uint32_t u = 0; u < g.n(); ++u) {
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

    /* Step 3: Keep the original serial shuffle for comparability. */
    std::cout << "Shuffling edges..." << std::endl;
    t.Start();
    std::shuffle(allEdges.begin(), allEdges.end(), rng);
    t.Stop();
    std::cout << "Time to shuffle edges: " << t.Seconds() << " seconds" << std::endl;
    std::cout << "Shuffle complete" << std::endl;

    /* Step 4: Reassign existence flags after shuffling. */
    std::vector<bool> nodeSeen(vertex_count, false);

    for (Edge& edge : allEdges) {
        edge.sourceExists = nodeSeen[static_cast<std::size_t>(edge.source)];
        edge.destExists = nodeSeen[static_cast<std::size_t>(edge.destination)];
        nodeSeen[static_cast<std::size_t>(edge.source)] = true;
        nodeSeen[static_cast<std::size_t>(edge.destination)] = true;
    }

    /* Step 5: Create data structure and algorithm. */
    dataStruc* struc = createDataStruc(
        opts.type,
        opts.weighted,
        opts.directed,
        static_cast<int64_t>(g.n()),
        opts.num_threads
    );

    Algorithm alg(opts.algorithm, struc, opts.type, opts.verbose);

    /* Step 6: Slice into batches, update, and run algorithm inline. */
    const int64_t start_batch_size =
        (opts.initial_batch_size != 0)
            ? opts.initial_batch_size
            : opts.batch_size;

    if (start_batch_size <= 0 || opts.batch_size <= 0) {
        std::cerr << "ERROR: Batch sizes must be positive." << std::endl;
        return 1;
    }

    const std::size_t total = allEdges.size();
    const std::size_t initial_batch_size =
        static_cast<std::size_t>(start_batch_size);
    const std::size_t dynamic_batch_size =
        static_cast<std::size_t>(opts.batch_size);

    if (initial_batch_size > total) {
        std::cerr << "ERROR: Initial batch size exceeds total edge count."
                  << std::endl;
        return 1;
    }

    std::size_t offset = 0;
    std::size_t batch_id = 0;

    while (offset < total) {
        const std::size_t requested_batch_size =
            (batch_id == 0)
                ? initial_batch_size
                : dynamic_batch_size;

        const std::size_t remaining = total - offset;
        const std::size_t batch_length =
            std::min(requested_batch_size, remaining);
        const std::size_t end = offset + batch_length;

        /* Keep the successful parallel EdgeList materialization. */
        EdgeList el(batch_length);

        #pragma omp parallel for schedule(static)
        for (std::size_t i = 0; i < batch_length; ++i) {
            el[i] = allEdges[offset + i];
        }

        t.Start();
        struc->update(el);
        t.Stop();

        {
            std::ofstream out("Update.csv", std::ios_base::app);
            if (!out) {
                std::cerr << "ERROR: Could not open Update.csv." << std::endl;
                return 1;
            }
            out << t.Seconds() << std::endl;
        }

        std::cout << "Updated batch: " << batch_id << std::endl;
        alg.performAlg();

        offset = end;
        ++batch_id;
    }

    std::cout << "Total batches processed: " << batch_id << std::endl;
    struc->print();

    return 0;
}
