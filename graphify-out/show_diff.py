import json
from graphify.analyze import graph_diff
from graphify.build import build_from_json
from networkx.readwrite import json_graph
import networkx as nx
from pathlib import Path

def main():
    old_path = Path('graphify-out/.graphify_old.json')
    extract_path = Path('graphify-out/.graphify_extract.json')
    
    old_data = json.loads(old_path.read_text(encoding="utf-8-sig")) if old_path.exists() else None
    new_extract = json.loads(extract_path.read_text(encoding="utf-8-sig"))
    
    # G_new is the merged final graph, and G_old is the pre-update graph!
    # Wait, build_from_json builds the graph from the extract format.
    G_new = build_from_json(new_extract)
    
    if old_data:
        G_old = json_graph.node_link_graph(old_data, edges='links')
        # graph_diff takes pre-update graph (G_old) and post-update graph (G_new)
        diff = graph_diff(G_old, G_new)
        print("--- GRAPH UPDATE DIFF ---")
        print(diff.get('summary', 'No summary available.'))
        new_nodes = diff.get('new_nodes', [])
        if new_nodes:
            print('New nodes:', ', '.join(n.get('label', n.get('id', '')) for n in new_nodes[:10]))
        new_edges = diff.get('new_edges', [])
        if new_edges:
            print('New edges:', len(new_edges))
        print("-------------------------")
        
        # Cleanup backup
        old_path.unlink()
        print("Removed .graphify_old.json")
    else:
        print("No old graph data found to compute diff.")

if __name__ == '__main__':
    main()
