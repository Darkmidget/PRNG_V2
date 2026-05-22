import json
d=json.load(open('graphify-out/graph.json', encoding='utf-8'))
nodes = {n['id']: n['label'] for n in d['nodes']}
for e in d['links']:
    s = nodes.get(e['source'], '')
    t = nodes.get(e['target'], '')
    if 'game' in s.lower() or 'game' in t.lower():
        print(f'{s} -> {e.get(\
relation\)} -> {t}')
