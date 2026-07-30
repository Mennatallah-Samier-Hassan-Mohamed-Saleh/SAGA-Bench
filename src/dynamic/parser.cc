#include "parser.h"

#include <unistd.h>
#include <algorithm>
#include <string>
#include <iostream>
#include <cstring>
#include <array>

std::string getSuffix(std::string filename)
{
    size_t suff_pos = filename.rfind('.');
    if (suff_pos == std::string::npos) {
	std::cout << "Couldn't find suffix of "
		  << filename << std::endl;
	exit(-1);
    }
    return filename.substr(suff_pos);  
}

bool supportedAlg(const std::string& alg)
{
    std::array<std::string, 13> algs = {
	"traverse",
	"prfromscratch", "prdyn",
	"ccfromscratch", "ccdyn",
	"mcfromscratch", "mcdyn",
	"ssspfromscratch", "ssspdyn",
	"bfsfromscratch", "bfsdyn",
	"sswpfromscratch", "sswpdyn"
    };	
    return std::find(algs.begin(), algs.end(), alg) != algs.end();
}

bool supportedDataStruc(const std::string &type)
{
    return (type== "adList" || type == "adListShared" || type == "degAwareRHH" || type == "stinger" || type == "adListChunked" || type == "abslBtreeSet" || type == "abslBtreeSetShared" || type == "cpamSet"|| type == "cpamSetShared");
}

void printUsage()
{
    std::cout << "Arguments:  -f filename -b batchSize -w weighted"
	" -d directed -s dataStructure -n numNodes -a algorithm -t number of threads -i initial batchSize -l weight_min -u weight_max\n"
	      << "First four arguments are required\n"
	      << "-f filename       	\n"
	      << "-b batchSize      	suggestion = 100K\n"
	      << "-w weighted       	0=unweighted   1=weighted\n"
	      << "-d directed       	0=undirected   1=directed\n"
	      << "-s dataStructure  	data structure to use (default: adList)\n"
		  << "-n nodes       	  	max number of nodes  to initialize with\n"
	      << "-a algorithm       	algorithm to run (default: traverse)\n"
	      << "-t number of threads    (default: 16)\n"
		  << "-i initial batchSize    initial batch size (optional for scalability tests)\n"
		  << "-l weight_min       	min weight for random weight generation (default: 2)\n"
	      << "-u weight_max       	max weight for random weight generation (default: 2)\n"
		  << "-v verbose            print algorithms' output 0=don't print, 1=print\n"
	      << "  DATA STRUCTURE OPTIONS:\n"
		  << "               	1) adList (single-threaded) \n"		  
	      << "               	2) adListShared (multihtreaded shared style) \n"
		  << "               	3) adListChunked (multithreaded chunk style) \n"
	      << "               	4) degAwareRHH (multithreaded chunk style) \n"
	      << "               	5) stinger (multihtreaded shared style) \n"
		  << "                6) abslBtreeSet (single-threaded) \n"
		  << "                7) abslBtreeSetShared (multihtreaded shared style) \n"
		  << "                8) cpamSet (single-threaded) \n"
		  << "                9) cpamSetShared (multihtreaded shared style) \n"
	      << "  ALGORITHM OPTIONS: \n"
	      << "               	1) traverse\n"
	      << "               	2) prfromscratch\n"
	      << "               	3) prdyn\n"
	      << "               	4) ccfromscratch\n"
	      << "               	5) ccdyn\n"
	      << "               	6) mcfromscratch\n"
	      << "               	7) mcdyn \n"    
	      << "               	8) bfsfromscratch\n"
	      << "               	9) bfspdyn\n"
	      << "               	10) ssspfromscratch\n"
	      << "               	11) ssspdyn\n"
	      << "               	12) sswpfromscratch\n"
	      << "               	13) sswpdyn"
	      << std::endl; 
}

cmd_args parse(int argc, char *argv[])
{
    cmd_args args;
    int opt = 0;
    while(-1 != (opt = getopt(argc, argv, "f:b:w:d:s:n:a:t:i:l:u:v:h"))) {
        switch(opt) {
	case 'f':               
	    args.flags |= 8;
	    args.filename = optarg;
	    break;
	case 'b':
	    args.flags |= 4;
	    args.batch_size = atoi(optarg);
	    break;
	case 'w':
	    args.flags |= 2;     
	    if(atoi(optarg) == 1) {
		args.weighted = true;
	    } else if (atoi(optarg) == 0) {
		args.weighted = false;            
	    } else {
		std::cout << "Weighted only takes 0 or 1 " << std::endl;
		printUsage();
		exit(-1);
	    }
	    break;
	case 'd':
	    args.flags |= 1;
	    if(atoi(optarg) == 1) {
		args.directed = true;
	    } else if (atoi(optarg) == 0) {
		args.directed = false;            
	    } else {
		std::cout << "Directed only takes 0 or 1" << std::endl;
		printUsage();
		exit(-1);
	    }                
	    break;
	case 's':
	    args.type = optarg;
	    if (!supportedDataStruc(args.type)) {
		std::cout << "Unsupported data structure!" << std::endl;
		printUsage();
		exit(-1);
	    }
	    break;
	case 'n':
	    args.num_nodes = atoi(optarg);	    
	    break;
	case 't':
	    args.num_threads = atoi(optarg);    
	    break;
	case 'a':
	    args.algorithm = optarg;                  
	    if (!supportedAlg(args.algorithm)) {
		std::cout << "Unsupported Algorithm" << std::endl;
		printUsage();
		exit(-1);
	    }
	    break;
	case 'i':
	    args.initial_batch_size = atoi(optarg);	    
	    break;
	case 'l':
	    args.min_weight = atol(optarg);
	    break;
	case 'u':
	    args.max_weight = atol(optarg);
	    break;
	case 'v':
	if (atoi(optarg) == 1) {
	    args.verbose = true;
	} else if (atoi(optarg) == 0) {
	    args.verbose = false;
	} else {
	    std::cout << "Verbose only takes 0 or 1" << std::endl;
	    printUsage();
		exit(-1);
	}
		break;
	case 'h':
	    std::cout << "Printing help" << std::endl;
	    printUsage();
	    exit(0);
	    break;
	}
}
    bool quit = false;
    if ((args.flags & 0x1) == 0) {
        std::cout << "Missing direction" << std::endl;
        quit = true;
    }
    if ((args.flags & 0x2) == 0) {
	std::cout << "Missing weight" << std::endl;
	quit = true;
    }
    if ((args.flags & 0x4) == 0) {
	std::cout << "Missing batch size" << std::endl;
	quit = true;
    }
    if ((args.flags & 0x8) == 0) {
	std::cout << "Missing file" << std::endl;
	quit = true;
    }
    if (quit) {
	exit(0);
    }
    if (optind < argc) {
        std::cout << "Too many extra arguments!" << std::endl;
        printUsage();
        exit(0);
    }    
	/*
    if ((args.num_nodes == 0)) {
	std::cout << "ERROR! Every data structure requires max number of nodes to be specified" << std::endl;
	printUsage();
	exit(-1);
    }
	*/

    std::array<std::string, 4> reqs = {
	"ssspdyn", "ssspfromscratch", "sswpdyn", "sswpfromscratch"};
    bool requires_weighted = std::find(reqs.begin(), reqs.end(), args.algorithm) != reqs.end();
    if (!args.weighted && requires_weighted) {
        std::cout << "ERROR! " << args.algorithm << " requires weighted graph " << std::endl;
        exit(-1);
    }
    return args;
}
