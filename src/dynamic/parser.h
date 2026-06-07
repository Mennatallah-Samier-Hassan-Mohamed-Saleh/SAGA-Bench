#ifndef PARSER_H
#define PARSER_H

#include <string>

struct cmd_args {
    int batch_size = 0;
    bool directed = false;
    bool weighted = false;
    int64_t num_nodes = 0;
    std::string filename;
    std::string type = "adList";
    std::string algorithm = "traverse";
    int8_t flags = 0;
    int64_t num_threads = 16; // default
    int64_t initial_batch_size = 0; // Optional field for initial batch size for scalability tests.

    //Assign start and end weights for random weight generation in case of weighted graph. Default is 2, which means all weights will be 2.
    int64_t min_weight = 2;
    int64_t max_weight = 2;

    bool verbose = false; // Optional field to print algorithms output, default is false.
};

std::string getSuffix(std::string filename);
bool supportedAlg(const std::string &alg);
bool supportedDataStruc(const std::string &type);
void printUsage();
cmd_args parse(int argc, char *argv[]);

#endif
