import json

with open('graphify-out/.graphify_detect.json', 'r', encoding='utf-8-sig') as f:
    d = json.load(f)

# Filter out .pio
new_files = {}
for cat, files in d.get('files', {}).items():
    new_files[cat] = [f for f in files if '.pio' not in f]

d['files'] = new_files
d['total_files'] = sum(len(v) for v in new_files.values())
# We don't have exact word counts per file to subtract, but we can proceed
# if total_files is reasonable, or we can just run detect() again using an ignore list if supported.
# But detect might not have ignore list in the script unless we write a .graphifyignore
with open('graphify-out/.graphify_detect.json', 'w', encoding='utf-8') as f:
    json.dump(d, f, ensure_ascii=False)

print(f"Filtered corpus: {d['total_files']} files remaining.")
