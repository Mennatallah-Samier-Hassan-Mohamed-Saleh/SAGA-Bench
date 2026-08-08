# EPIC-Bench

**Scalable Benchmarking of Modern Data Structures for Dynamic-Graph Analytics**

EPIC-Bench extends [SAGA-Bench](https://github.com/abasak24/SAGA-Bench) to support scalable evaluation of dynamic-graph workloads across three main dimensions:

- **Compute model:** incremental computation and recomputation from scratch
- **Batch size:** configurable dynamic-update sizes
- **Graph data structure:** serial-update, concurrent-update, and batch-parallel data structures

EPIC-Bench adds parallel graph ingestion using
[PIGO](https://github.com/GT-TDAlab/PIGO), in-memory preprocessing and
batch generation, configurable base-graph construction, and support for
batch-parallel data structures such as CPAM.

The implementation used for the EPIC-Bench experiments is maintained on the:

**`development_with_PIGO` branch**

Repository:

https://github.com/Mennatallah-Samier-Hassan-Mohamed-Saleh/SAGA-Bench


## Building EPIC-Bench

Clone the repository and switch to the EPIC-Bench branch:

```bash
git clone https://github.com/Mennatallah-Samier-Hassan-Mohamed-Saleh/SAGA-Bench.git
cd SAGA-Bench
git checkout development_with_PIGO
git submodule update --init --recursive
./scripts/build.sh
```

A successful build produces the executable:

```text
./frontEnd
```

in the repository root.


## Requirements

EPIC-Bench is implemented in C++17 and uses shared-memory parallelism.

The paper experiments use:

- GCC 9.2.0
- C++17
- OpenMP
- PIGO
- ParlayLib
- 128 CPU cores on a single compute node

The repository uses Git submodules. Make sure to run:

```bash
git submodule update --init --recursive
```

before building.


### Key Dependencies

EPIC-Bench builds on several external libraries and systems:

- [PIGO](https://github.com/GT-TDAlab/PIGO) for high-throughput parallel graph input.
- [ParlayLib](https://github.com/cmuparlay/parlaylib) for shared-memory parallel primitives.
- [Abseil](https://abseil.io/) for the Abseil B-tree implementation.
- CPAM / PaC-tree for the batch-parallel data structure evaluated in the paper.

Dependencies included as Git submodules are obtained using:

```bash
git submodule update --init --recursive
```


## Repository Structure

The main directories relevant to EPIC-Bench are:

```text
SAGA-Bench/
├── src/
│   ├── dynamic/        Core benchmark, algorithms, and data structures
│   └── common/         Shared utility code
├── scripts/            Build, graph-generation, and experiment scripts
├── inputResource/      Legacy SAGA-Bench input-processing utilities
├── pcmResource/        Legacy SAGA-Bench Intel PCM utilities
└── frontEnd            Benchmark executable after compilation
```

### `src/dynamic`

The main EPIC-Bench implementation is under `src/dynamic`.

Important files include:

- `frontEnd.cc` — graph loading, preprocessing, deterministic shuffling, batch generation, graph updates, and algorithm execution
- `parser.cc` / `parser.h` — command-line parsing and help
- `topDataStruc.h` — registration and creation of graph data structures
- `topAlg.h` — registration of graph algorithms
- data-structure implementation files — adjacency-list, STINGER, Abseil B-tree, CPAM, and other inherited SAGA-Bench structures

EPIC-Bench uses PIGO to load the input graph and converts the resulting graph representation into an in-memory edge list. The edge list is deterministically shuffled before being divided into the base graph and dynamic-update batches.


## Scripts

Build, graph-generation, and experiment utilities are available in:

https://github.com/Mennatallah-Samier-Hassan-Mohamed-Saleh/SAGA-Bench/tree/development_with_PIGO/scripts

The main build command is:

```bash
./scripts/build.sh
```

The repository also contains the RMAT graph generator used for the paper experiments:

```bash
python3 scripts/rmat_generator.py <output_file>
```

See the `scripts/` directory for additional experiment and utility scripts.


## Supported Data Structures

Run:

```bash
./frontEnd -help
```

for the authoritative list supported by the current build.

The current EPIC-Bench branch includes:

| Command-line name | Description |
|---|---|
| `adList` | Single-threaded adjacency list |
| `adListShared` | Multithreaded shared adjacency list |
| `adListChunked` | Multithreaded chunked adjacency list |
| `degAwareRHH` | Multithreaded degree-aware structure |
| `stinger` | Multithreaded STINGER |
| `abslBtreeSet` | Single-threaded Abseil B-tree |
| `abslBtreeSetShared` | Multithreaded shared Abseil B-tree |
| `cpamSet` | Single-threaded CPAM |
| `cpamSetShared` | Batch-parallel CPAM |

The EPIC-Bench paper focuses on four representative structures:

- Shared adjacency list
- STINGER
- Abseil B-tree
- CPAM


## Supported Algorithms

Each evaluated graph algorithm has incremental and from-scratch variants.

| Algorithm | From scratch | Incremental |
|---|---|---|
| PageRank (PR) | `prfromscratch` | `prdyn` |
| Connected Components (CC) | `ccfromscratch` | `ccdyn` |
| Max Computation (MC) | `mcfromscratch` | `mcdyn` |
| Breadth-First Search (BFS) | `bfsfromscratch` | `bfsdyn` |
| Single-Source Shortest Path (SSSP) | `ssspfromscratch` | `ssspdyn` |
| Single-Source Widest Path (SSWP) | `sswpfromscratch` | `sswpdyn` |

The benchmark also provides:

```text
traverse
```


## Command-Line Interface

Display the current command-line interface with:

```bash
./frontEnd -help
```

Basic usage:

```text
./frontEnd -f <file> -b <batch-size> -w <0|1> -d <0|1> [options]
```

### Required Options

| Option | Description |
|---|---|
| `-f <file>` | Input graph file |
| `-b <size>` | Dynamic batch size |
| `-w <0\|1>` | `0` = unweighted, `1` = weighted |
| `-d <0\|1>` | `0` = undirected, `1` = directed |

### Optional Options

| Option | Description |
|---|---|
| `-s <structure>` | Graph data structure (default: `adList`) |
| `-a <algorithm>` | Graph algorithm (default: `traverse`) |
| `-t <threads>` | Number of threads (default: 16) |
| `-n <vertices>` | Maximum number of vertices |
| `-i <edges>` | Initial/base-graph size |
| `-r <vertex>` | Fixed source vertex for BFS, SSSP, and SSWP |
| `-l <weight>` | Minimum random edge weight (default: 2) |
| `-u <weight>` | Maximum random edge weight (default: 2) |
| `-v <0\|1>` | Print algorithm output: `0` = no, `1` = yes |
| `-h` | Display help |


## Base Graph and Dynamic Batches

EPIC-Bench separates base-graph construction from subsequent dynamic updates.

Let:

- `m` = total number of graph edges
- `k` = number of dynamic batches
- `b` = number of edges per dynamic batch
- `i` = initial/base-graph size

The initial graph size is calculated as:

```text
i = m - (k * b)
```

The value `i` is passed through:

```text
-i <edges>
```

while the dynamic batch size is passed through:

```text
-b <edges>
```

The experiments reported in the EPIC-Bench paper use:

```text
k = 10
```

dynamic batches.

For example, the Twitter graph used in the paper contains:

```text
m = 2,405,026,092 edges
```

For a dynamic batch size of:

```text
b = 100,000
```

the initial graph size is:

```text
i = 2,405,026,092 - (10 * 100,000)
  = 2,404,026,092
```


## Example: Twitter BFS with CPAM

Incremental BFS on Twitter using CPAM, 128 threads, and dynamic batches of 100,000 edges can be launched as:

```bash
./frontEnd \
  -d 0 \
  -w 0 \
  -f <tw.txt> \
  -b 100000 \
  -s cpamSetShared \
  -a bfsdyn \
  -t 128 \
  -n 61578415 \
  -i 2404026092 \
  -r 36501842
```

Here:

- `-d 0` specifies an undirected graph
- `-w 0` specifies an unweighted graph
- `-b 100000` sets the dynamic batch size
- `-i 2404026092` constructs the mostly-full base graph
- `-r 36501842` fixes the BFS source vertex
- `-t 128` uses 128 threads


## Datasets

The EPIC-Bench paper evaluates the following graphs:

| Dataset | Type | Vertices | Edges |
|---|---|---:|---:|
| LiveJournal | Directed | 4,847,571 | 68,993,773 |
| Com-Orkut | Undirected | 3,072,441 | 117,185,083 |
| RMAT | Directed | 32,118,308 | 500,000,000 |
| Erdős–Rényi | Undirected | 10,000,000 | 1,000,009,380 |
| Twitter | Undirected | 61,578,415 | 2,405,026,092 |

### LiveJournal and Com-Orkut

LiveJournal and Com-Orkut are available from the Stanford Large Network Dataset Collection (SNAP):

https://snap.stanford.edu/data/

### Erdős–Rényi and Twitter

The ER and Twitter graphs used in the paper experiments are available from the dataset repository:

https://www.dropbox.com/scl/fo/dqf7inwxprea4pr4rc191/AC17NzPUkFQuaDdOGGoOC1U?rlkey=3lsfu7a49di6qbgey5f2msjh2&dl=0

### RMAT

The RMAT graph is generated using SNAP with:

```text
N = 2^25 requested vertices
M = 500,000,000 edges
a = 0.5
b = 0.1
c = 0.1
d = 0.3
```

Generate it with:

```bash
python3 scripts/rmat_generator.py <output_file>
```

The number of vertices present in the resulting edge list may be smaller than the requested `N`; the paper reports the graph size observed by the benchmark after loading the generated graph.


## Fixed Source Vertices

Source-based algorithms use `-r` to keep the source vertex fixed across preprocessing and shuffling implementations.

The paper experiments use:

| Dataset | Source vertex |
|---|---:|
| LiveJournal | `967794` |
| Com-Orkut | `614044` |
| RMAT | `6406224` |
| Erdős–Rényi | `2001011` |
| Twitter | `36501842` |

Use these values for BFS, SSSP, and SSWP when reproducing the paper experiments.


## Weighted Algorithms

SSSP and SSWP require weighted graphs.

Use:

```text
-w 1
```

for these algorithms.

Random edge weights are generated using the configured minimum and maximum weights:

```text
-l <weight>
-u <weight>
```

The default values are:

```text
-l 2
-u 2
```

Other algorithms in the paper are run as unweighted workloads with:

```text
-w 0
```


## Output

Each experiment produces two CSV files:

- **`Update.csv`** — per-batch graph-update times, in seconds.
- **`Alg.csv`** — per-batch algorithm compute times, in seconds.

For an experiment with 10 dynamic batches, these files contain the timing measurements used to calculate the steady-state update and compute results reported in the paper.

The benchmark also prints execution information to standard output, including graph loading, edge-list conversion, deterministic shuffling, batch updates, algorithm execution, and the total number of batches processed.

Timing results are appended to the CSV files. Move, rename, or remove existing `Update.csv` and `Alg.csv` files before starting a new experiment set if separate output files are desired.


## Reproducing the EPIC-Bench Paper Experiments

The paper experiments use:

```text
Dynamic batches: 10
Batch sizes:     10^0, 10^1, 10^2, 10^3, 10^4, 10^5, 10^6 edges
Threads:         128
Runs:            3 per configuration
```

For every batch size `b`, calculate:

```text
i = m - (10 * b)
```

and pass the result through `-i`.

For each configuration, EPIC-Bench:

1. loads the graph using PIGO,
2. converts the graph to an in-memory edge list,
3. deterministically shuffles the edges,
4. constructs the base graph from the first `i` edges,
5. applies the remaining edges as dynamic batches, and
6. runs the selected algorithm after each update.

The reported paper timings are averages over three runs. Update and compute times are averaged over the ten dynamic batches using `Update.csv` and `Alg.csv`, respectively.

Use the fixed source vertices listed above for BFS, SSSP, and SSWP.


## Experiment Configuration Summary

The graph-direction values used in the paper are:

| Dataset | `-d` |
|---|---:|
| LiveJournal | `1` |
| Com-Orkut | `0` |
| RMAT | `1` |
| Erdős–Rényi | `0` |
| Twitter | `0` |

where:

```text
-d 0 = undirected
-d 1 = directed
```

For BFS, CC, PR, and MC:

```text
-w 0
```

For SSSP and SSWP:

```text
-w 1
```

The paper experiments use:

```text
-t 128
```


## Third-Party Software and References

EPIC-Bench builds on several open-source projects. Please cite the corresponding work when appropriate.

### PIGO

EPIC-Bench uses [PIGO](https://github.com/GT-TDAlab/PIGO) for parallel graph input.

> K. Gabert and Ü. V. Çatalyürek,  
> **“PIGO: A Parallel Graph Input/Output Library,”**  
> 2021 IEEE International Parallel and Distributed Processing Symposium Workshops (IPDPSW), pp. 276–279, 2021.

### ParlayLib

EPIC-Bench uses [ParlayLib](https://github.com/cmuparlay/parlaylib) for shared-memory parallel primitives.

> G. E. Blelloch, D. Anderson, and L. Dhulipala,  
> **“Brief Announcement: ParlayLib — A Toolkit for Parallel Algorithms on Shared-Memory Multicore Machines,”**  
> Proceedings of the 32nd ACM Symposium on Parallelism in Algorithms and Architectures (SPAA), pp. 507–509, 2020.

### Abseil

EPIC-Bench uses the [Abseil C++ library](https://abseil.io/) for the Abseil B-tree implementation.

### CPAM / PaC-trees

EPIC-Bench integrates CPAM as its batch-parallel data structure. CPAM builds on the PaC-tree design.

> L. Dhulipala, G. E. Blelloch, Y. Gu, and Y. Sun,  
> **“PaC-trees: Supporting Parallel and Compressed Purely-Functional Collections,”**  
> Proceedings of the 43rd ACM SIGPLAN International Conference on Programming Language Design and Implementation (PLDI), pp. 108–121, 2022.


## Original SAGA-Bench

EPIC-Bench builds on the original SAGA-Bench benchmark:

> A. Basak, J. Lin, R. Lorica, X. Xie, Z. Chishti, A. Alameldeen, and Y. Xie,  
> **“SAGA-Bench: Software and Hardware Characterization of Streaming Graph Analytics Workloads,”**  
> IEEE International Symposium on Performance Analysis of Systems and Software (ISPASS), pp. 12–23, 2020.

Original repository:

https://github.com/abasak24/SAGA-Bench

The original SAGA-Bench repository contains additional information about its producer/consumer ingestion pipeline and Intel PCM hardware-characterization infrastructure.

Those instructions describe the original SAGA-Bench workflow and should not be confused with the PIGO-based EPIC-Bench pipeline in the `development_with_PIGO` branch.


## Citation

If you use EPIC-Bench, please cite the EPIC-Bench paper.

<!-- Add the final EPIC-Bench BibTeX entry here once publication metadata is available. -->

Please also cite the relevant third-party systems used by your experiment, including SAGA-Bench, PIGO, and CPAM/PaC-trees, where appropriate.


## Issues and Contributions

For bugs, reproduction questions, or feature requests, please open a GitHub issue:

https://github.com/Mennatallah-Samier-Hassan-Mohamed-Saleh/SAGA-Bench/issues

Contributions that add new graph data structures, algorithms, datasets, or experiment configurations are welcome.
