#ifndef TRAVERSAL_H_
#define TRAVERSAL_H_

#include "types.h"
#include "adListShared.h"
#include "stinger.h"
#include "darhh.h"
#include "adListChunked.h"
#include "cpamSet.h"
#include "cpamSetShared.h"

#include "topDataStruc.h"

template <typename T>
class neighborhood;

template <typename T> 
class neighborhood_iter {    
public:
    neighborhood_iter(T* ds, NodeID n, bool in_neigh);
    bool operator!=(neighborhood_iter& it);
    neighborhood_iter& operator++();
    neighborhood_iter& operator++(int);
    NodeID operator*();
    Weight extractWeight();
};

template<typename U>
class neighborhood_iter<adList<U>> {    
    friend class neighborhood<adList<U>>;
private:      
    adList<U>* ds;      
    NodeID node;
    bool in_neigh;
    U* cursor;
public:
    neighborhood_iter(adList<U>* _ds, NodeID _n, bool _in_neigh): 
	ds(_ds), node(_n), in_neigh(_in_neigh){        
	if(in_neigh){        
	    bool empty = ds->in_neighbors[node].empty(); 
	    cursor = empty? 0 : &(ds->in_neighbors[node][0]);        
	}
	else{        
	    bool empty = ds->out_neighbors[node].empty(); 
	    cursor = empty? 0 : &(ds->out_neighbors[node][0]);
	}
    }

    bool operator!=(const neighborhood_iter<adList<U>>& it){
        return cursor != it.cursor;
    }

    neighborhood_iter& operator++(){
        if(in_neigh){
            int size_in_neigh = ds->in_neighbors[node].size();
            if(cursor == &(ds->in_neighbors[node][size_in_neigh-1])){
                cursor = nullptr; 
            }
            else cursor = cursor + 1;
        }else{
            int size_out_neigh = ds->out_neighbors[node].size();
            if(cursor == &(ds->out_neighbors[node][size_out_neigh-1])){
                cursor = nullptr;
            }else cursor = cursor + 1;
        }

        return *this;	      
    }

    neighborhood_iter& operator++(int){
         if(in_neigh){
             int size_in_neigh = ds->in_neighbors[node].size();
             if(cursor == &(ds->in_neighbors[node][size_in_neigh-1])){
                 cursor = nullptr; 
             }
             else cursor = cursor + 1;
         }else{
             int size_out_neigh = ds->out_neighbors[node].size();
             if(cursor == &(ds->out_neighbors[node][size_out_neigh-1])){
                 cursor = nullptr;
             }else cursor = cursor + 1;
         }

         return *this;		
    }

    NodeID operator*() {
	return cursor->getNodeID();
    }

    Weight extractWeight(){
	return cursor->getWeight();
    }
};

template <typename U>
class neighborhood_iter<adListShared<U>> {    
    friend class neighborhood<adListShared<U>>;
private:      
    adListShared<U>* ds;      
    NodeID node;
    bool in_neigh;
    U* cursor;
public:
    neighborhood_iter(adListShared<U>* _ds, NodeID _n, bool _in_neigh): 
	ds(_ds), node(_n), in_neigh(_in_neigh){        
	if(in_neigh){        
	    bool empty = ds->in_neighbors[node].empty(); 
	    cursor = empty? 0 : &(ds->in_neighbors[node][0]);        
	}
	else{        
	    bool empty = ds->out_neighbors[node].empty(); 
	    cursor = empty? 0 : &(ds->out_neighbors[node][0]);
	}
    }

    bool operator!=(const neighborhood_iter<adListShared<U>>& it){
        return cursor != it.cursor;
    }

    neighborhood_iter& operator++(){
        if(in_neigh){
            int size_in_neigh = ds->in_neighbors[node].size();
            if(cursor == &(ds->in_neighbors[node][size_in_neigh-1])){
                cursor = nullptr; 
            }
            else cursor = cursor + 1;
        }else{
            int size_out_neigh = ds->out_neighbors[node].size();
            if(cursor == &(ds->out_neighbors[node][size_out_neigh-1])){
                cursor = nullptr;
            }else cursor = cursor + 1;
        }

        return *this;	      
    }

    neighborhood_iter& operator++(int){
         if(in_neigh){
             int size_in_neigh = ds->in_neighbors[node].size();
             if(cursor == &(ds->in_neighbors[node][size_in_neigh-1])){
                 cursor = nullptr; 
             }
             else cursor = cursor + 1;
         }else{
             int size_out_neigh = ds->out_neighbors[node].size();
             if(cursor == &(ds->out_neighbors[node][size_out_neigh-1])){
                 cursor = nullptr;
             }else cursor = cursor + 1;
         }

         return *this;		
    }

    NodeID operator*() {
	return cursor->getNodeID();
    }

    Weight extractWeight(){
	return cursor->getWeight();
    }
};

//specialization for stinger

template <>
class neighborhood_iter<stinger> {    
    friend class neighborhood<stinger>;

    private:      
      stinger* ds;      
      NodeID node;
      bool in_neigh;
      stinger_edge* cursor;
      stinger_eb* curr_eb;
      stinger_vertex* sv;
      int cursor_index;

    public:
      neighborhood_iter(stinger* _ds, NodeID _n, bool _in_neigh)
      :ds(_ds), node(_n), in_neigh(_in_neigh)
      {
          sv = &(ds->vertices[node]);

          if(in_neigh){              
              bool empty = (sv->in_neighbors->numEdges == 0); 
              cursor = empty? 0 : &(sv->in_neighbors->edges[0]);
              curr_eb = sv->in_neighbors;
              if(!empty) cursor_index = 0;
          }

          else{
              bool empty = (sv->out_neighbors->numEdges == 0); 
              cursor = empty? 0 : &(sv->out_neighbors->edges[0]);
              curr_eb = sv->out_neighbors;
              if(!empty) cursor_index = 0;
          }
      }

      bool operator!=(const neighborhood_iter<stinger>& it){
          return cursor != it.cursor;
      }

      neighborhood_iter& operator++(){
          // just increment by 1 if we are in an edgeblock and more edges left           
          if(cursor_index < (curr_eb->numEdges-1)){
              cursor = cursor + 1;
              cursor_index++;
          }

          else if(cursor_index == (curr_eb->numEdges-1)){
              // We are done with current edgeblock 
              if(curr_eb->next != nullptr){                  
                  // move to next one, if there is one
                  curr_eb = curr_eb->next;
                  cursor = &(curr_eb->edges[0]);
                  cursor_index = 0;
              }else{
                  // there is no further, end of traversal
                  cursor = nullptr;
              }              
          }        

          return *this;          
      }

      neighborhood_iter& operator++(int){
          // just increment by 1 if we are in an edgeblock and more edges left           
          if(cursor_index < (curr_eb->numEdges-1)){              
              cursor = cursor + 1;
              cursor_index++;
          }

          else if(cursor_index == (curr_eb->numEdges-1)){
              // We are done with current edgeblock 
              if(curr_eb->next != nullptr){                  
                  // move to next one, if there is one
                  curr_eb = curr_eb->next;
                  cursor = &(curr_eb->edges[0]);
                  cursor_index = 0;
              }else{                  
                  // there is no further, end of traversal
                  cursor = nullptr;
              }              
          }        

          return *this; 
      }      

      NodeID operator*(){
          assert(cursor->neighbor != -1);
          return cursor->neighbor;
      }

      Weight extractWeight(){
          return cursor->weight;
      }
};

// // ------------------------------adList_chunk----------------------------------
template <typename U>
class neighborhood_iter<adListChunked<U>> {    
    friend class neighborhood<adListChunked<U>>;
private:      
    adListChunked<U>* ds;      
    NodeID node;
    bool in_neigh;
    U* cursor;

    int64_t part_idx; 
    int64_t sub_idx;
    
public:
    neighborhood_iter(adListChunked<U>* _ds, NodeID _n, bool _in_neigh): 
	ds(_ds), node(_n), in_neigh(_in_neigh){   
        // part_idx = _n % (ds->num_partitions); 
        // sub_idx = (int) _n/(ds->num_partitions);
        part_idx = ds->pt_hash(_n); 
        sub_idx =  ds->hash_within_chunk(_n);
	    if(in_neigh){      
	        bool empty = ds->in[part_idx]->partAdList->neighbors[sub_idx].empty(); 
    	    cursor = empty? nullptr : &(ds->in[part_idx]->partAdList->neighbors[sub_idx][0]);
	    } 
        else{      
	        bool empty = ds->out[part_idx]->partAdList->neighbors[sub_idx].empty(); 
	        cursor = empty? nullptr : &(ds->out[part_idx]->partAdList->neighbors[sub_idx][0]);
	    }
    }

    bool operator!=(const neighborhood_iter<adListChunked<U>>& it){
        return cursor != it.cursor;
    }

    neighborhood_iter& operator++(){
        if(in_neigh){
            int size_in_neigh = ds->in[part_idx]->partAdList->neighbors[sub_idx].size();
            if(cursor == &(ds->in[part_idx]->partAdList->neighbors[sub_idx][size_in_neigh-1]))
                cursor = nullptr; 
            else
                cursor = cursor + 1;
        }
        else{
            int size_out_neigh = ds->out[part_idx]->partAdList->neighbors[sub_idx].size();
            if(cursor == &(ds->out[part_idx]->partAdList->neighbors[sub_idx][size_out_neigh-1]))
                cursor = nullptr;
            else 
                cursor = cursor + 1;
        }

        return *this;	      
    }

    neighborhood_iter& operator++(int){
        if(in_neigh){
            int size_in_neigh = ds->in[part_idx]->partAdList->neighbors[sub_idx].size();
            if(cursor == &(ds->in[part_idx]->partAdList->neighbors[sub_idx][size_in_neigh-1]))
                cursor = nullptr; 
            else
                cursor = cursor + 1;
        }
        else{
            int size_out_neigh = ds->out[part_idx]->partAdList->neighbors[sub_idx].size();
            if(cursor == &(ds->out[part_idx]->partAdList->neighbors[sub_idx][size_out_neigh-1]))
                cursor = nullptr;
            else 
                cursor = cursor + 1;
        }

         return *this;		
    }

    NodeID operator*() {
	    return cursor->getNodeID();
    }

    Weight extractWeight(){
	    return cursor->getWeight();
    }
};

template <typename U>
class neighborhood_iter<darhh<U>> {    
    friend class neighborhood<darhh<U>>;
private:
    hd_rhh<U> *hd;
    ld_rhh<U> *ld;
    typename hd_rhh<U>::iter hd_iter;
    typename ld_rhh<U>::iter ld_iter;
    bool low_degree;
public:
    inline neighborhood_iter& operator=(neighborhood_iter const &it);
    inline bool operator!=(neighborhood_iter const &it);
    neighborhood_iter& operator++();
    neighborhood_iter& operator++(int);
    inline NodeID operator*();
    inline Weight extractWeight();
    void set_begin(darhh<U> *ds, NodeID n, bool in);
    void set_end();
};

template <typename U>
void neighborhood_iter<darhh<U>>::set_begin(darhh<U> *ds, NodeID src, bool in)
{
    if (in) {
	ld = ds->in[ds->pt_hash(src)]->ld;
	hd = ds->in[ds->pt_hash(src)]->hd;
    } else {	
	ld = ds->out[ds->pt_hash(src)]->ld;
	hd = ds->out[ds->pt_hash(src)]->hd;
    }
    low_degree = ld->get_degree(src);
    if (low_degree)
	ld_iter = ld->begin(src);
    else
	hd_iter = hd->begin(src);
}

template <typename U>
void neighborhood_iter<darhh<U>>::set_end()
{
    ld_iter.cursor = nullptr;
    hd_iter.cursor = nullptr;
}

template <typename U>
neighborhood_iter<darhh<U>>&
neighborhood_iter<darhh<U>>::operator=(neighborhood_iter const &other)
{
    hd = other.hd;
    ld = other.ld;
    hd_iter = other.hd_iter;
    ld_iter = other.ld_iter;
    low_degree = other.low_degree;
    return *this;
}

template <typename U>
bool neighborhood_iter<darhh<U>>::operator!=(neighborhood_iter const &it)
{
    if (low_degree) 
	return ld_iter != it.ld_iter;
    else
	return hd_iter != it.hd_iter;
}

template <typename U>
neighborhood_iter<darhh<U>>& neighborhood_iter<darhh<U>>::operator++()
{
    if (low_degree)
        ++ld_iter;
    else
	++hd_iter;
    return *this;
}

template <typename U>
neighborhood_iter<darhh<U>>& neighborhood_iter<darhh<U>>::operator++(int)
{
    if (low_degree)
        ++ld_iter;
    else
	++hd_iter;
    return *this;
}

template <typename U>
NodeID neighborhood_iter<darhh<U>>::operator*()
{
    if (low_degree)
        return ld_iter.cursor->getNodeID();
    else
	return hd_iter.cursor->getNodeID();   
}

template <typename U>
Weight neighborhood_iter<darhh<U>>::extractWeight()
{
    if (low_degree)
	return ld_iter.cursor->getWeight();
    else
	return hd_iter.cursor->getWeight();
}

template <typename T>
class neighborhood {
private:
    T* ds;
    NodeID node;
    bool in_neigh; 
public:
    neighborhood(NodeID _node, T* _ds, bool _in_neigh):
	ds(_ds),
	node(_node),
	in_neigh(_in_neigh) {}
    neighborhood_iter<T> begin() {
	return neighborhood_iter<T>(ds, node, in_neigh);
    } 
    neighborhood_iter<T> end() {
        neighborhood_iter<T> n = neighborhood_iter<T>(ds, node, in_neigh);
        n.cursor = nullptr;
        return n;
    }
};

template <typename U>
class neighborhood<darhh<U>> {    
private:
    using iter = neighborhood_iter<darhh<U>>;
    NodeID src;
    darhh<U> *ds;
    bool in;
public:
    neighborhood(NodeID src, darhh<U> *ds, bool in): src(src), ds(ds), in(in) {}
    iter begin() {
	iter it;
	it.set_begin(ds, src, in);
	return it;
    } 
    iter end() {
        iter it;
	it.set_end();
        return it;
    }
};

// Specialization for abslBtreeSet<U>
template <typename U>
class neighborhood<abslBtreeSet<U>> {    
private:
    using iter = neighborhood_iter<abslBtreeSet<U>>;
    NodeID src;
    abslBtreeSet<U> *ds;
    //Flag to indicate whether to iterate over in-neighbors or out-neighbors
    bool in;
public:
    neighborhood(NodeID src, abslBtreeSet<U> *ds, bool in): src(src), ds(ds), in(in) {}
    
    // CALL THE ITERATOR'S SPECIALIZED begin() METHOD
    iter begin() {
        return iter(ds, src, in);
    } 

    // CALL THE ITERATOR'S SPECIALIZED end() METHOD
    iter end() {
        iter it(ds, src, in);
        return it.end(); // This calls the specialized end() method from neighborhood_iter<abslBtreeSet<U>>
    }
};

// Specialization for abslBtreeSetShared<U>
template <typename U>
class neighborhood<abslBtreeSetShared<U>> {    
private:
    using iter = neighborhood_iter<abslBtreeSetShared<U>>;
    NodeID src;
    abslBtreeSetShared<U> *ds;
    //Flag to indicate whether to iterate over in-neighbors or out-neighbors
    bool in;
public:
    neighborhood(NodeID src, abslBtreeSetShared<U> *ds, bool in): src(src), ds(ds), in(in) {}
    
    // CALL THE ITERATOR'S SPECIALIZED begin() METHOD
    iter begin() {
        return iter(ds, src, in);
    } 

    // CALL THE ITERATOR'S SPECIALIZED end() METHOD
    iter end() {
        iter it(ds, src, in);
        return it.end(); // This calls the specialized end() method from neighborhood_iter<abslBtreeSet<U>>
    }
};
/**
 * A function to return an iterable object for in-neighbors of a node
 * If the data structure is undirected, it returns out-neighbors
 * @param n The node whose in-neighbors are to be iterated over
 * @param ds The data structure
 * @return An iterable object for in-neighbors of node n
 * If ds is undirected, it returns out-neighbors
 * **/
template<typename U>
class neighborhood_iter<abslBtreeSet<U>> {    
    friend class neighborhood<abslBtreeSet<U>>;
private:      
    abslBtreeSet<U>* ds;      
    NodeID node;
    bool in_neigh;
    typename absl::btree_set<U>::iterator cursor;
    typename absl::btree_set<U>::iterator end_cursor;
public:
    neighborhood_iter(abslBtreeSet<U>* _ds, NodeID _n, bool _in_neigh)
        : ds(_ds), node(_n), in_neigh(_in_neigh) {
        // Initialize cursor and end_cursor based on in_neigh
        if (in_neigh) {
            cursor = ds->in_neighbors[node].begin();
            end_cursor = ds->in_neighbors[node].end();
        } else {
            cursor = ds->out_neighbors[node].begin();
            end_cursor = ds->out_neighbors[node].end();
        }
    }

    //Compare iterators for inequality
    bool operator!=(const neighborhood_iter& it) const {
        return cursor != it.cursor;
    }

    // Increment the iterator to the next element
    neighborhood_iter& operator++() {
        ++cursor;
        return *this;
    }

    // Advances the iterator to the next neighbor and 
    //returns the previous iterator state (standard post-increment semantics).
    neighborhood_iter operator++(int) {
        neighborhood_iter tmp = *this;
        ++cursor;
        return tmp;
    }
    
    // Dereference the iterator to get the current neighbor's NodeID
    NodeID operator*() const {
        return cursor->getNodeID();
    }

    // Extract the weight of the current neighbor
    Weight extractWeight() const {
        return cursor->getWeight();
    }
    
    //Returns an iterator representing the end of the neighborhood
    neighborhood_iter<abslBtreeSet<U>> end(){
        neighborhood_iter<abslBtreeSet<U>> n(ds, node, in_neigh);
        if (in_neigh)
            n.cursor = ds->in_neighbors[node].end();
        else
            n.cursor = ds->out_neighbors[node].end();
        return n;
    }
};

/**
* A function to return an iterable object for in-neighbors of a node
* If the data structure is undirected, it returns out-neighbors
* @param n The node whose in-neighbors are to be iterated over
* @param ds The data structure
* @return An iterable object for in-neighbors of node n
* If ds is undirected, it returns out-neighbors
* **/
template<typename U>
class neighborhood_iter<abslBtreeSetShared<U>> {   
   friend class neighborhood<abslBtreeSetShared<U>>;
private:     
   abslBtreeSetShared<U>* ds;     
   NodeID node;
   bool in_neigh;
   typename absl::btree_set<U>::iterator cursor;
   typename absl::btree_set<U>::iterator end_cursor;
public:
   neighborhood_iter(abslBtreeSetShared<U>* _ds, NodeID _n, bool _in_neigh)
       : ds(_ds), node(_n), in_neigh(_in_neigh) {
       // Initialize cursor and end_cursor based on in_neigh
       if (in_neigh) {
           cursor = ds->in_neighbors[node].begin();
           end_cursor = ds->in_neighbors[node].end();
       } else {
           cursor = ds->out_neighbors[node].begin();
           end_cursor = ds->out_neighbors[node].end();
       }
   }


   //Compare iterators for inequality
   bool operator!=(const neighborhood_iter& it) const {
       return cursor != it.cursor;
   }


   // Increment the iterator to the next element
   neighborhood_iter& operator++() {
       ++cursor;
       return *this;
   }


   // Advances the iterator to the next neighbor and
   //returns the previous iterator state (standard post-increment semantics).
   neighborhood_iter operator++(int) {
       neighborhood_iter tmp = *this;
       ++cursor;
       return tmp;
   }
  
   // Dereference the iterator to get the current neighbor's NodeID
   NodeID operator*() const {
       return cursor->getNodeID();
   }


   // Extract the weight of the current neighbor
   Weight extractWeight() const {
       return cursor->getWeight();
   }
  
   //Returns an iterator representing the end of the neighborhood
   neighborhood_iter<abslBtreeSetShared<U>> end(){
       neighborhood_iter<abslBtreeSetShared<U>> n(ds, node, in_neigh);
       if (in_neigh)
           n.cursor = ds->in_neighbors[node].end();
       else
           n.cursor = ds->out_neighbors[node].end();
       return n;
   }
};

// Specialization for cpamSet<U>
template <typename U>
class neighborhood<cpamSet<U>> {
private:
    using iter = neighborhood_iter<cpamSet<U>>;
    NodeID src;
    cpamSet<U> *ds;
    bool in;
public:
    neighborhood(NodeID src, cpamSet<U> *ds, bool in): src(src), ds(ds), in(in) {}

    iter begin() {
        return iter(ds, src, in);
    }

    // Calls the cheap end-tag constructor directly (this class is a
    // friend of neighborhood_iter<cpamSet<U>>) instead of building a
    // full iterator via entries() just to overwrite it — unlike the
    // begin()-then-.end() pattern used elsewhere in this file, that
    // pattern would cost a second, wasted materialization here.
    iter end() {
        return iter(ds, src, in, true);
    }
};

/**
 * neighborhood_iter<cpamSet<U>>
 *
 * cpam::pam_set has no STL-style begin()/end() (unlike absl::btree_set) —
 * it only exposes callback/bulk-extraction APIs (iterate_seq, entries()).
 * So unlike abslBtreeSet's iterator, which wraps the container's own
 * iterator directly, this one materializes the neighbor set once via
 * edge_tree::entries() into a parlay::sequence<U> (already key-sorted,
 * since pam_set is a balanced BST) and walks that by index — the same
 * "snapshot into a buffer, then iterate the buffer" approach adList uses
 * over its raw std::vector, just with an owned copy instead of a raw
 * pointer, since the tree offers no addressable contiguous storage.
 *
 * The end-tag constructor below is private but reachable from
 * neighborhood<cpamSet<U>> (a friend): it just asks the tree for
 * .size() instead of paying for another entries() call.
 * **/
template<typename U>
class neighborhood_iter<cpamSet<U>> {
    friend class neighborhood<cpamSet<U>>;
private:
    using edge_tree = typename cpamSet<U>::edge_tree;

    cpamSet<U>* ds;
    NodeID node;
    bool in_neigh;
    parlay::sequence<U> buffer;
    size_t idx;

    // Cheap end-sentinel constructor: skips materializing entries(),
    // just needs buffer.size() to compare equal against.
    neighborhood_iter(cpamSet<U>* _ds, NodeID _n, bool _in_neigh, bool /*end_tag*/)
        : ds(_ds), node(_n), in_neigh(_in_neigh), idx(0) {
        idx = in_neigh ? ds->in_neighbors[node].size()
                        : ds->out_neighbors[node].size();
    }

public:
    neighborhood_iter(cpamSet<U>* _ds, NodeID _n, bool _in_neigh)
        : ds(_ds), node(_n), in_neigh(_in_neigh), idx(0) {
        buffer = in_neigh ? edge_tree::entries(ds->in_neighbors[node])
                           : edge_tree::entries(ds->out_neighbors[node]);
    }

    bool operator!=(const neighborhood_iter& it) const {
        return idx != it.idx;
    }

    neighborhood_iter& operator++() {
        ++idx;
        return *this;
    }

    neighborhood_iter& operator++(int) {
        ++idx;
        return *this;
    }

    NodeID operator*() const {
        return buffer[idx].getNodeID();
    }

    Weight extractWeight() const {
        return buffer[idx].getWeight();
    }

    neighborhood_iter<cpamSet<U>> end() {
        return neighborhood_iter<cpamSet<U>>(ds, node, in_neigh, true);
    }
};

// Specialization for cpamSetShared<U>
// Identical approach to cpamSet<U> above (same underlying edge_tree type,
// same "materialize via entries() into a buffer" strategy, since pam_set
// has no STL iterator either way) — this is a straight duplication with
// the type swapped, not a new design. As with abslBtreeSetShared's own
// traversal specialization, no locking happens here: traversal runs after
// the update phase for a batch completes, not concurrently with it.
template <typename U>
class neighborhood<cpamSetShared<U>> {
private:
    using iter = neighborhood_iter<cpamSetShared<U>>;
    NodeID src;
    cpamSetShared<U> *ds;
    bool in;
public:
    neighborhood(NodeID src, cpamSetShared<U> *ds, bool in): src(src), ds(ds), in(in) {}

    iter begin() {
        return iter(ds, src, in);
    }

    iter end() {
        return iter(ds, src, in, true);
    }
};

template<typename U>
class neighborhood_iter<cpamSetShared<U>> {
    friend class neighborhood<cpamSetShared<U>>;
private:
    using edge_tree = typename cpamSetShared<U>::edge_tree;

    cpamSetShared<U>* ds;
    NodeID node;
    bool in_neigh;
    parlay::sequence<U> buffer;
    size_t idx;

    neighborhood_iter(cpamSetShared<U>* _ds, NodeID _n, bool _in_neigh, bool /*end_tag*/)
        : ds(_ds), node(_n), in_neigh(_in_neigh), idx(0) {
        idx = in_neigh ? ds->in_neighbors[node].size()
                        : ds->out_neighbors[node].size();
    }

public:
    neighborhood_iter(cpamSetShared<U>* _ds, NodeID _n, bool _in_neigh)
        : ds(_ds), node(_n), in_neigh(_in_neigh), idx(0) {
        buffer = in_neigh ? edge_tree::entries(ds->in_neighbors[node])
                           : edge_tree::entries(ds->out_neighbors[node]);
    }

    bool operator!=(const neighborhood_iter& it) const {
        return idx != it.idx;
    }

    neighborhood_iter& operator++() {
        ++idx;
        return *this;
    }

    neighborhood_iter& operator++(int) {
        ++idx;
        return *this;
    }

    NodeID operator*() const {
        return buffer[idx].getNodeID();
    }

    Weight extractWeight() const {
        return buffer[idx].getWeight();
    }

    neighborhood_iter<cpamSetShared<U>> end() {
        return neighborhood_iter<cpamSetShared<U>>(ds, node, in_neigh, true);
    }
};

template<typename T>
neighborhood<T> in_neigh(NodeID n, T* ds)
{
    if(ds->directed)
	return neighborhood<T>(n, ds, true);         
    else
	return neighborhood<T>(n, ds, false); 
}

template<typename T>
neighborhood<T> out_neigh(NodeID n, T* ds)
{
    return neighborhood<T>(n, ds, false); 
}

#endif // TRAVERSAL_H_