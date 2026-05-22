import json
import os

with open('graphify-out/.graphify_prompts.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

chunk = next(c for c in data if c['chunk_num'] == 4)
lines = chunk['prompt'].split('Files (chunk 4 of 22):\n')[1].split('\n\nRules:')[0].strip().split('\n')

for line in lines:
    fpath = line.strip()
    print(f"### {fpath}")
    if os.path.exists(fpath):
        with open(fpath, 'r', encoding='utf-8', errors='replace') as src:
            print(src.read()[:200])
    else:
        print("MISSING")
