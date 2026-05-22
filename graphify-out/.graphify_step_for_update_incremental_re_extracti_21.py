import sys, json
from graphify.build import build_from_json
from networkx.readwrite import json_graph
import networkx as nx
from pathlib import Path

existing_data = json.loads(Path('graphify-out/graph.json').read_text(encoding="utf-8"))
G_existing = json_graph.node_link_graph(existing_data, edges='links')

new_extraction = json.loads(Path('graphify-out/.graphify_extract.json').read_text(encoding="utf-8"))
G_new = build_from_json(new_extraction)

incremental = json.loads(Path('graphify-out/.graphify_incremental.json').read_text(encoding="utf-8"))
deleted = set(incremental.get('deleted_files', []))
if deleted:
    to_remove = [n for n, d in G_existing.nodes(data=True) if d.get('source_file') in deleted]
    G_existing.remove_nodes_from(to_remove)
    if to_remove:
        print(f'Pruned {len(to_remove)} ghost node(s) from {len(deleted)} deleted file(s) — drift detected and corrected.')
    else:
        print(f'{len(deleted)} file(s) deleted since last run, but no ghost nodes were present in the graph — no drift.')

G_existing.update(G_new)
print(f'Merged: {G_existing.number_of_nodes()} nodes, {G_existing.number_of_edges()} edges')

from graphify.detect import save_manifest
save_manifest(incremental['files'])
print('[graphify update] Manifest saved.')

nodes = [{'id': n, **d} for n, d in G_existing.nodes(data=True)]
edges = [{'source': u, 'target': v, **d} for u, v, d in G_existing.edges(data=True)]
Path('graphify-out/.graphify_extract.json').write_text(json.dumps({'nodes': nodes, 'edges': edges}, ensure_ascii=False), encoding='utf-8')
