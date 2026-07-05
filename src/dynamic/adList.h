#ifndef ADLIST_H_
#define ADLIST_H_

#include <iostream>

#include "abstract_data_struc.h"
#include "print.h"

// T can be either node or nodeweight
template <typename T>
class adList : public dataStruc
{
private:
    bool vertexExists(const Edge &e, bool source);
    void updateForNewVertex(const Edge &e, bool source);
    void updateForExistingVertex(const Edge &e, bool source);

public:
    std::vector<std::vector<T>> out_neighbors;
    std::vector<std::vector<T>> in_neighbors;
    adList(bool w, bool d, int64_t _num_nodes);
    void update(const EdgeList &el) override;
    void print() override;
    int64_t in_degree(NodeID n) override;
    int64_t out_degree(NodeID n) override;
};

template <typename T>
adList<T>::adList(bool w, bool d, int64_t _num_nodes) : dataStruc(w, d, _num_nodes)
{
    std::cout << "Creating AdList" << std::endl;
    // initialize 1) property 2) affected 3) vertices vectors
    property.resize(num_nodes_max, -1);
    affected.resize(num_nodes_max);
    affected.fill(false);
    out_neighbors.resize(num_nodes_max);
    in_neighbors.resize(num_nodes_max);
}

template <typename T>
bool adList<T>::vertexExists(const Edge &e, bool source)
{
    bool exists = source ? e.sourceExists : e.destExists;
    NodeID index = source ? e.source : e.destination;

    if (exists)
    {
        num_edges++;
        affected[index] = 1; // Use index directly
        return true;
    }
    else
    {
        num_nodes++;
        num_edges++;
        affected[index] = 1; // Use index directly, NOT push_back
        return false;
    }
}

template <typename T>
void adList<T>::updateForNewVertex(const Edge &e, bool source)
{
    NodeID index = source ? e.source : e.destination;
    // property.push_back(-1);     //already pre allocated
    if (source || (!source && !directed))
    {
        // update out_neighbors with meaningful data
        // std::vector<T> edge_data;
        T neighbor;
        if (source)
            neighbor.setInfo(e.destination, e.weight);
        else
            neighbor.setInfo(e.source, e.weight);

        // Use index instead of push_back
        out_neighbors[index].push_back(neighbor);
    }
    else if (!source && directed)
    {
        // update in_neighbors with meaningful data
        T neighbor;
        neighbor.setInfo(e.source, e.weight);

        // Use index instead of push_back
        in_neighbors[index].push_back(neighbor);
    }
}

template <typename T>
void adList<T>::updateForExistingVertex(const Edge &e, bool source)
{
    NodeID index;
    if (source)
        index = e.source;
    else
        index = e.destination;
    if (source || (!source && !directed))
    {
        NodeID dest;
        if (source)
            dest = e.destination;
        else
            dest = e.source;
        // search for the edge first in out_neighbors
        bool found = false;
        for (unsigned int i = 0; i < out_neighbors[index].size(); i++)
        {
            if (out_neighbors[index][i].getNodeID() == dest)
            {
                // std::cout << "Found repeating edges: source: " << index << " dest: " << dest << " new weight: "
                //<< e.weight << std::endl;
                // std::cout << "old weight " << out_neighbors[index][i].getWeight() << std::endl;
                out_neighbors[index][i].setInfo(dest, e.weight);
                // std::cout << "new weight " << out_neighbors[index][i].getWeight() << std::endl;
                found = true;
                break;
            }
        }
        if (!found)
        {
            T neighbor;
            neighbor.setInfo(dest, e.weight);
            out_neighbors[index].push_back(neighbor);
        }
    }
    else if (!source && directed)
    {
        // in_neighbors
        // search for the edge first in in_neighbors
        bool found = false;
        for (unsigned int i = 0; i < in_neighbors[index].size(); i++)
        {
            if (in_neighbors[index][i].getNodeID() == e.source)
            {
                in_neighbors[index][i].setInfo(e.source, e.weight);
                found = true;
                break;
            }
        }
        if (!found)
        {
            T neighbor;
            neighbor.setInfo(e.source, e.weight);
            in_neighbors[index].push_back(neighbor);
        }
    }
}

template <typename T>
void adList<T>::update(const EdgeList &el)
{
    for (auto it = el.begin(); it != el.end(); it++)
    {
        Edge e = *it; // local mutable copy
        bool isSelfLoop = (e.source == e.destination);
        // Self-loop: sourceExists/destExists come from the same nodeSeen slot in
        // main.cpp and are always equal. Treat the destination-side check as
        // already-existing so a first-time self-loop only counts its node once.
        if (isSelfLoop)
        {
            e.destExists = true;
        }

        // examine source vertex
        bool exists = vertexExists(e, true);
        if (!exists)
            updateForNewVertex(e, true);
        else
            updateForExistingVertex(e, true);

        // examine destination vertex
        bool exists1 = vertexExists(e, false);
        if (!exists1)
            updateForNewVertex(e, false);
        else
            updateForExistingVertex(e, false);
    }

    /*Sort neighbors to match absl::btree_set order*/
    /*
    for (NodeID n = 0; n < num_nodes; n++) {
        std::sort(out_neighbors[n].begin(), out_neighbors[n].end());
        if (directed)
            std::sort(in_neighbors[n].begin(), in_neighbors[n].end());
    }
    */
}

template <typename T>
int64_t adList<T>::in_degree(NodeID n)
{
    if (directed)
        return in_neighbors[n].size();
    else
        return out_neighbors[n].size();
}

template <typename T>
int64_t adList<T>::out_degree(NodeID n)
{
    return out_neighbors[n].size();
}

template <typename T>
void adList<T>::print()
{
    std::cout << " numNodes: " << num_nodes << " numEdges: " << num_edges << " weighted: " << weighted << " directed: " << directed << std::endl;

    /*cout << "Property: "; printVector(property);
    cout << "out_neighbors: " << endl; printVecOfVecOfNodes(out_neighbors);
    cout << "in_neighbors: " << endl; printVecOfVecOfNodes(in_neighbors);*/
}
#endif // ADLIST_H_
