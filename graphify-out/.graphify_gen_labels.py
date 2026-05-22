import json
from pathlib import Path

analysis = json.loads(Path('graphify-out/.graphify_analysis.json').read_text(encoding="utf-8-sig"))
labels = {}

for cid, nodes in analysis['communities'].items():
    if nodes:
        labels[int(cid)] = f"Community {cid}"
    else:
        labels[int(cid)] = f"Community {cid}"

Path('graphify-out/temp_labels.json').write_text(json.dumps(labels, ensure_ascii=False))
