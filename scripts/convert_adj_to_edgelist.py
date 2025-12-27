#!/usr/bin/env python3
"""
Convert adjacency graph format to edge list format.

Input format: AdjacencyGraph followed by n_vertices, n_edges, then offsets and edges
Output format: source target (one edge per line)
"""

def adj_to_edgelist(input_file, output_file):
    """
    Convert adjacency graph format to edge list.
    
    Args:
        input_file: Path to input .adj file
        output_file: Path to output edge list file
    """
    with open(input_file, 'r') as f:
        lines = f.readlines()
    
    # Parse header
    assert lines[0].strip() == 'AdjacencyGraph', "Invalid format"
    n_vertices = int(lines[1].strip())
    n_edges = int(lines[2].strip())
    
    print(f"Vertices: {n_vertices:,}")
    print(f"Edges: {n_edges:,}")
    
    # Parse offsets (lines 3 to 3+n_vertices-1)
    offsets = []
    for i in range(3, 3 + n_vertices):
        offsets.append(int(lines[i].strip()))
    
    # Parse edges (lines 3+n_vertices onwards)
    edges = []
    for i in range(3 + n_vertices, len(lines)):
        line = lines[i].strip()
        if line:
            edges.append(int(line))
    
    assert len(edges) == n_edges, f"Expected {n_edges} edges, got {len(edges)}"
    
    # Convert to edge list
    print("Converting to edge list...")
    with open(output_file, 'w') as f:
        for src in range(n_vertices):
            start = offsets[src]
            end = offsets[src + 1] if src + 1 < n_vertices else n_edges
            
            for idx in range(start, end):
                dst = edges[idx]
                f.write(f"{src} {dst}\n")
    
    print(f"Edge list written to {output_file}")

if __name__ == "__main__":
    import sys
    import os
    
    # Base directory for datasets
    base_dir = "/scratch/ms13779/datasets/SAGAdatasets"
    
    # List of dataset files to convert
    datasets = ["co.adj", "er.adj", "lj.adj", "tw.adj", "fs.adj"]
    
    # Process each dataset
    for dataset in datasets:
        input_file = os.path.join(base_dir, dataset)
        output_file = os.path.join(base_dir, dataset.replace('.adj', '.txt'))
        
        if not os.path.exists(input_file):
            print(f"Warning: {input_file} not found, skipping...")
            continue
        
        print(f"\n{'='*60}")
        print(f"Processing: {dataset}")
        print(f"{'='*60}")
        
        try:
            adj_to_edgelist(input_file, output_file)
            print(f"✓ Successfully converted {dataset}")
        except Exception as e:
            print(f"✗ Error converting {dataset}: {e}")
    
    print(f"\n{'='*60}")
    print("Conversion complete!")