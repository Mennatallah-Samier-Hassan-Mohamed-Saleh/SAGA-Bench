#ifndef TOPALG_H
#define TOPALG_H

/*
This is the top API for performing an algorithm
*/

#include <iostream>
#include <string>

#include "dyn_traverse.h"
#include "dyn_pr.h"
#include "dyn_cc.h"
#include "dyn_mc.h"
#include "dyn_bfs.h"
#include "dyn_sssp.h"
#include "dyn_sswp.h"
#include "source_picker_dynamic.h"

class dataStruc;

class Algorithm {  
private:
    std::string alg;    
    std::string dtype;
    dataStruc* ds;    
    NodeID source;
    int batch;
	bool verbose; // whether to print algorithm output, default is false.
	bool is_adListST; // single thread adList
    bool is_adList;   // shared style multithreading
    bool is_stinger;  
    bool is_rhh; 
	bool is_adList2;   // chunk style multithreading
	bool is_abslBtreeSet; // absl btree set style (single thread)
	bool is_abslBtreeSetShared; // absl btree set style (shared multithreading)

public:    
    Algorithm(const std::string& alg_, dataStruc* ds_, const std::string& dtype_, bool verbose_) :
	alg(alg_),    
	dtype(dtype_),
	ds(ds_),     
	source(-1),
	batch(-1),
	verbose(verbose_) { 
		is_adListST = (dtype.compare("adList") == 0);           
		is_adList = (dtype.compare("adListShared") == 0);
		is_stinger = (dtype.compare("stinger") == 0);
		is_rhh = (dtype.compare("degAwareRHH") == 0);
		is_adList2 = (dtype.compare("adListChunked") == 0);
		is_abslBtreeSet = (dtype.compare("abslBtreeSet") == 0);
		is_abslBtreeSetShared = (dtype.compare("abslBtreeSetShared") == 0);
		std::cout << "Algorithm: " << alg << std::endl;
		std::cout << "Data type: " << dtype << std::endl;
    }
    
    void performAlg() {
		batch++;
		adListShared<NodeWeight> *ds0 = dynamic_cast<adListShared<NodeWeight>*>(ds);
		adListShared<Node> *ds1 = dynamic_cast<adListShared<Node>*>(ds);
		adListChunked<NodeWeight> *ds5 = dynamic_cast<adListChunked<NodeWeight>*>(ds);
		adListChunked<Node> *ds6 = dynamic_cast<adListChunked<Node>*>(ds);
		darhh<NodeWeight> *ds2 = dynamic_cast<darhh<NodeWeight>*>(ds);
		darhh<Node> *ds3 = dynamic_cast<darhh<Node>*>(ds);
		stinger *ds4 = dynamic_cast<stinger*>(ds);
		adList<NodeWeight> *ds7 = dynamic_cast<adList<NodeWeight>*>(ds);
		adList<Node> *ds8 = dynamic_cast<adList<Node>*>(ds);
		abslBtreeSet<NodeWeight> *ds9 = dynamic_cast<abslBtreeSet<NodeWeight>*>(ds);
		abslBtreeSet<Node> *ds10 = dynamic_cast<abslBtreeSet<Node>*>(ds);
		abslBtreeSetShared<NodeWeight> *ds11 = dynamic_cast<abslBtreeSetShared<NodeWeight>*>(ds);
		abslBtreeSetShared<Node> *ds12 = dynamic_cast<abslBtreeSetShared<Node>*>(ds);
	
		if (alg == "traverse") {
	 	    if (is_adList && ds->weighted)
				return traverseAlg(ds0);
	 	    else if (is_adList && !ds->weighted)
				return traverseAlg(ds1);
	 	    else if (is_rhh && ds->weighted)
				return traverseAlg(ds2);
	  	    else if (is_rhh && !ds->weighted)
				return traverseAlg(ds3);
	 	    else if (is_stinger)
				return traverseAlg(ds4);
	  	  	else if (is_adList2 && ds->weighted)
				return traverseAlg(ds5);
			else if (is_adList2 && !ds->weighted)
				return traverseAlg(ds6);	   
			else if (is_adListST && ds->weighted)
                return traverseAlg(ds7);
			else if (is_adListST && !ds->weighted) 
			    return traverseAlg(ds8);
			else if (is_abslBtreeSet && ds->weighted)
				return traverseAlg(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return traverseAlg(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)
				return traverseAlg(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return traverseAlg(ds12);
		} else if (alg == "prfromscratch") {
	    	if (is_adList && ds->weighted)
				return PRStartFromScratch(ds0);
	    	else if (is_adList && !ds->weighted)
				return PRStartFromScratch(ds1);
	    	else if (is_rhh && ds->weighted)
				return PRStartFromScratch(ds2);
	   		else if (is_rhh && !ds->weighted)
				return PRStartFromScratch(ds3);
	    	else if (is_stinger)
				return PRStartFromScratch(ds4);
	    	else if (is_adList2 && ds->weighted)
				return PRStartFromScratch(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return PRStartFromScratch(ds6);	
			else if (is_adListST && ds->weighted)
                return PRStartFromScratch(ds7);
			else if (is_adListST && !ds->weighted) 
			    return PRStartFromScratch(ds8);
			else if (is_abslBtreeSet && ds->weighted)
				return PRStartFromScratch(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return PRStartFromScratch(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)
				return PRStartFromScratch(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return PRStartFromScratch(ds12);    
		} else if (alg == "prdyn") {
	    	if (is_adList && ds->weighted)
				return dynPRAlg(ds0);
	    	else if (is_adList && !ds->weighted)
				return dynPRAlg(ds1);
	    	else if (is_rhh && ds->weighted)
				return dynPRAlg(ds2);
	    	else if (is_rhh && !ds->weighted)
				return dynPRAlg(ds3);
	    	else if (is_stinger)
				return dynPRAlg(ds4);		
	    	else if (is_adList2 && ds->weighted)
				return dynPRAlg(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return dynPRAlg(ds6);	    
			else if (is_adListST && ds->weighted)
                return dynPRAlg(ds7);
			else if (is_adListST && !ds->weighted) 
			    return dynPRAlg(ds8);
			else if (is_abslBtreeSet && ds->weighted)
				return dynPRAlg(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynPRAlg(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)
				return dynPRAlg(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynPRAlg(ds12);  
		} else if (alg == "ccfromscratch") {
	    	if (is_adList && ds->weighted)
				return CCStartFromScratch(ds0);
	    	else if (is_adList && !ds->weighted)
				return CCStartFromScratch(ds1);
	    	else if (is_rhh && ds->weighted)
				return CCStartFromScratch(ds2);
	    	else if (is_rhh && !ds->weighted)
				return CCStartFromScratch(ds3);
	    	else if (is_stinger)
				return CCStartFromScratch(ds4);
	    	else if (is_adList2 && ds->weighted)
				return CCStartFromScratch(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return CCStartFromScratch(ds6);	 
			else if (is_adListST && ds->weighted)
                return CCStartFromScratch(ds7);
			else if (is_adListST && !ds->weighted) 
			    return CCStartFromScratch(ds8);
			else if (is_abslBtreeSet && ds->weighted)
				return CCStartFromScratch(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return CCStartFromScratch(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)
				return CCStartFromScratch(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return CCStartFromScratch(ds12);     
		} else if (alg == "ccdyn") {
	    	if (is_adList && ds->weighted)
				return dynCCAlg(ds0);
	    	else if (is_adList && !ds->weighted)
				return dynCCAlg(ds1);
	    	else if (is_rhh && ds->weighted)
				return dynCCAlg(ds2);
	    	else if (is_rhh && !ds->weighted)
		  		return dynCCAlg(ds3);
	    	else if (is_stinger)
				return dynCCAlg(ds4);		
	    	else if (is_adList2 && ds->weighted)
				return dynCCAlg(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return dynCCAlg(ds6);	
			else if (is_adListST && ds->weighted)
                return dynCCAlg(ds7);
			else if (is_adListST && !ds->weighted) 
			    return dynCCAlg(ds8);    
			else if (is_abslBtreeSet && ds->weighted)
				return dynCCAlg(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynCCAlg(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)	
				return dynCCAlg(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynCCAlg(ds12);
		} else if (alg == "mcfromscratch") {
	    	if (is_adList && ds->weighted)
				return MCStartFromScratch(ds0);
	    	else if (is_adList && !ds->weighted)
				return MCStartFromScratch(ds1);
	    	else if (is_rhh && ds->weighted)
				return MCStartFromScratch(ds2);
	    	else if (is_rhh && !ds->weighted)
				return MCStartFromScratch(ds3);
	    	else if (is_stinger)
				return MCStartFromScratch(ds4);			
	    	else if (is_adList2 && ds->weighted)
				return MCStartFromScratch(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return MCStartFromScratch(ds6);   
			else if (is_adListST && ds->weighted)
                return MCStartFromScratch(ds7);
			else if (is_adListST && !ds->weighted) 
			    return MCStartFromScratch(ds8); 
			else if (is_abslBtreeSet && ds->weighted)		
				return MCStartFromScratch(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return MCStartFromScratch(ds10);  
			else if (is_abslBtreeSetShared && ds->weighted)		
				return MCStartFromScratch(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return MCStartFromScratch(ds12); 
		} else if (alg == "mcdyn") {
	    	if (is_adList && ds->weighted)
				return dynMCAlg(ds0);
	    	else if (is_adList && !ds->weighted)
				return dynMCAlg(ds1);
	    	else if (is_rhh && ds->weighted)
				return dynMCAlg(ds2);
	    	else if (is_rhh && !ds->weighted)
				return dynMCAlg(ds3);
	    	else if (is_stinger)
				return dynMCAlg(ds4);		
	    	else if (is_adList2 && ds->weighted)
				return dynMCAlg(ds5);
	    	else if (is_adList2 && !ds->weighted)
				return dynMCAlg(ds6);	   
			else if (is_adListST && ds->weighted)
                return dynMCAlg(ds7);
			else if (is_adListST && !ds->weighted) 
			    return dynMCAlg(ds8); 
			else if (is_abslBtreeSet && ds->weighted)
				return dynMCAlg(ds9);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynMCAlg(ds10);
			else if (is_abslBtreeSetShared && ds->weighted)	
				return dynMCAlg(ds11);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynMCAlg(ds12);
		} else if (alg == "bfsfromscratch") {
	    	if (source == -1) {
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
			if(source == -1)
		    	return;
	    	}
	    	if (is_adList && ds->weighted)
				return BFSStartFromScratch(ds0, source);
	    	else if (is_adList && !ds->weighted)
				return BFSStartFromScratch(ds1, source);
	    	else if (is_rhh && ds->weighted)
				return BFSStartFromScratch(ds2, source);
	    	else if (is_rhh && !ds->weighted)
				return BFSStartFromScratch(ds3, source);
	    	else if (is_stinger)
				return BFSStartFromScratch(ds4, source);			
	    	else if (is_adList2 && ds->weighted)
				return BFSStartFromScratch(ds5, source);
	    	else if (is_adList2 && !ds->weighted)
				return BFSStartFromScratch(ds6, source);   
			else if (is_adListST && ds->weighted)
                return BFSStartFromScratch(ds7, source);
			else if (is_adListST && !ds->weighted) 
			    return BFSStartFromScratch(ds8, source);
			else if (is_abslBtreeSet && ds->weighted)
				return BFSStartFromScratch(ds9, source);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return BFSStartFromScratch(ds10, source);
			else if (is_abslBtreeSetShared && ds->weighted)
				return BFSStartFromScratch(ds11, source);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return BFSStartFromScratch(ds12, source);  
		} else if (alg == "bfsdyn") {
	    	if(source == -1){
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
				if(source == -1)
		    		return;
	   		}
	    	if (is_adList && ds->weighted)
				return dynBFSAlg(ds0, source,verbose);
	    	else if (is_adList && !ds->weighted)
				return dynBFSAlg(ds1, source,verbose);
	    	else if (is_rhh && ds->weighted)
				return dynBFSAlg(ds2, source,verbose);
	    	else if (is_rhh && !ds->weighted)
				return dynBFSAlg(ds3, source,verbose);
	    	else if (is_stinger)
				return dynBFSAlg(ds4, source,verbose);	 
	    	else if (is_adList2 && ds->weighted)
				return dynBFSAlg(ds5, source,verbose);
	    	else if (is_adList2 && !ds->weighted)
				return dynBFSAlg(ds6, source,verbose);  
			else if (is_adListST && ds->weighted)
                return dynBFSAlg(ds7, source,verbose);
			else if (is_adListST && !ds->weighted) 
			    return dynBFSAlg(ds8, source,verbose);
			else if (is_abslBtreeSet && ds->weighted)
				return dynBFSAlg(ds9, source,verbose);		
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynBFSAlg(ds10, source,verbose);
			else if (is_abslBtreeSetShared && ds->weighted)	
				return dynBFSAlg(ds11, source,verbose);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynBFSAlg(ds12, source,verbose);
		} else if (alg == "ssspfromscratch") {
	    	if (source == -1) {
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
				if(source == -1)
		    	return;
	    	}
	    	if (is_adList && ds->weighted)
				return SSSPStartFromScratch(ds0, source, 1);
	    	else if (is_adList && !ds->weighted)
				return SSSPStartFromScratch(ds1, source, 1);
	   		else if (is_rhh && ds->weighted)
				return SSSPStartFromScratch(ds2, source, 1);
	    	else if (is_rhh && !ds->weighted)
				return SSSPStartFromScratch(ds3, source, 1);
	    	else if (is_stinger)
				return SSSPStartFromScratch(ds4, source, 1);	    
	    	else if (is_adList2 && ds->weighted)
				return SSSPStartFromScratch(ds5, source, 1);
	    	else if (is_adList2 && !ds->weighted)
				return SSSPStartFromScratch(ds6, source, 1);
			else if (is_adListST && ds->weighted)
                return SSSPStartFromScratch(ds7, source, 1);
			else if (is_adListST && !ds->weighted) 
			    return SSSPStartFromScratch(ds8, source, 1);
			else if (is_abslBtreeSet && ds->weighted)
				return SSSPStartFromScratch(ds9, source, 1);		
			else if (is_abslBtreeSet && !ds->weighted) 
			    return SSSPStartFromScratch(ds10, source, 1);
			else if (is_abslBtreeSetShared && ds->weighted)
				return SSSPStartFromScratch(ds11, source, 1);		
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return SSSPStartFromScratch(ds12, source, 1);
		} else if (alg == "ssspdyn") {
		    if (source == -1) {
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
				if(source == -1)
		    		return;
	    	}
	    	if (is_adList && ds->weighted)
				return dynSSSPAlg(ds0, source);
	    	else if (is_adList && !ds->weighted)
				return dynSSSPAlg(ds1, source);
	    	else if (is_rhh && ds->weighted)
				return dynSSSPAlg(ds2, source);
	    	else if (is_rhh && !ds->weighted)
				return dynSSSPAlg(ds3, source);
	    	else if (is_stinger)
				return dynSSSPAlg(ds4, source);	   
	    	else if (is_adList2 && ds->weighted)
				return dynSSSPAlg(ds5, source);
	    	else if (is_adList2 && !ds->weighted)
				return dynSSSPAlg(ds6, source);
			else if (is_adListST && ds->weighted)
                return dynSSSPAlg(ds7, source);
			else if (is_adListST && !ds->weighted) 
			    return dynSSSPAlg(ds8, source);
			else if (is_abslBtreeSet && ds->weighted)		
				return dynSSSPAlg(ds9, source);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynSSSPAlg(ds10, source);
			else if (is_abslBtreeSetShared && ds->weighted)	
				return dynSSSPAlg(ds11, source);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynSSSPAlg(ds12, source);
		} else if (alg == "sswpfromscratch") {
	    	if (source == -1) {
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
				if(source == -1)
				    return;
	    	}
	    	if (is_adList && ds->weighted)
				return SSWPStartFromScratch(ds0, source);
	    	else if (is_adList && !ds->weighted)
				return SSWPStartFromScratch(ds1, source);
	    	else if (is_rhh && ds->weighted)
				return SSWPStartFromScratch(ds2, source);
	    	else if (is_rhh && !ds->weighted)
				return SSWPStartFromScratch(ds3, source);
	    	else if (is_stinger)
				return SSWPStartFromScratch(ds4, source);	   
	    	else if (is_adList2 && ds->weighted)
				return SSWPStartFromScratch(ds5, source);
	    	else if (is_adList2 && !ds->weighted)
				return SSWPStartFromScratch(ds6, source);
			else if (is_adListST && ds->weighted)
                return SSWPStartFromScratch(ds7, source);
			else if (is_adListST && !ds->weighted) 
			    return SSWPStartFromScratch(ds8, source);
			else if (is_abslBtreeSet && ds->weighted)		
				return SSWPStartFromScratch(ds9, source);
			else if (is_abslBtreeSet && !ds->weighted) 
			    return SSWPStartFromScratch(ds10, source);
			else if (is_abslBtreeSetShared && ds->weighted)
				return SSWPStartFromScratch(ds11, source);		
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return SSWPStartFromScratch(ds12, source);
		} else if (alg == "sswpdyn") {

	    	if(source == -1) {
				DynamicSourcePicker sp(ds);
				source = sp.PickNext(); 
				std::cout << "Source in top: " << source << std::endl;
				if(source == -1)
				    return;
	    	}
	    	if (is_adList && ds->weighted)
				return dynSSWPAlg(ds0, source);
	    	else if (is_adList && !ds->weighted)
				return dynSSWPAlg(ds1, source);
	    	else if (is_rhh && ds->weighted)
				return dynSSWPAlg(ds2, source);
	    	else if (is_rhh && !ds->weighted)
				return dynSSWPAlg(ds3, source);
	    	else if (is_stinger)
				return dynSSWPAlg(ds4, source);	    
	    	else if (is_adList2 && ds->weighted)
				return dynSSWPAlg(ds5, source);
	    	else if (is_adList2 && !ds->weighted)
				return dynSSWPAlg(ds6, source);
			else if (is_adListST && ds->weighted)
                return dynSSWPAlg(ds7, source);
			else if (is_adListST && !ds->weighted) 
			    return dynSSWPAlg(ds8, source);
			else if (is_abslBtreeSet && ds->weighted)		
				return dynSSWPAlg(ds9, source);		
			else if (is_abslBtreeSet && !ds->weighted) 
			    return dynSSWPAlg(ds10, source);
			else if (is_abslBtreeSetShared && ds->weighted)	
				return dynSSWPAlg(ds11, source);
			else if (is_abslBtreeSetShared && !ds->weighted) 
			    return dynSSWPAlg(ds12, source);
		} else {
	    	std::cout << "Error! Unrecognized Algorithm!" << std::endl;
	    	exit(0);
		}
    }
};

#endif
