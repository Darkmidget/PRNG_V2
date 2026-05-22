import json

with open('graphify-out/.graphify_detect.json', 'r', encoding='utf-8-sig') as f:
    d = json.load(f)

files = d.get('files', {})
code_files = len(files.get('code', []))
doc_files = len(files.get('document', []))
paper_files = len(files.get('paper', []))
image_files = len(files.get('image', []))
video_files = len(files.get('video', []))

total_files = d.get('total_files', sum(len(v) for v in files.values()))
total_words = d.get('total_words', 0)
skipped = d.get('skipped_sensitive', [])

print(f"Corpus: {total_files} files · ~{total_words} words")
if code_files > 0: print(f"  code:     {code_files} files")
if doc_files > 0: print(f"  docs:     {doc_files} files")
if paper_files > 0: print(f"  papers:   {paper_files} files")
if image_files > 0: print(f"  images:   {image_files} files")
if video_files > 0: print(f"  video:    {video_files} files")

if len(skipped) > 0:
    print(f"Skipped {len(skipped)} sensitive files.")

print(f"__TOTAL_FILES__={total_files}")
print(f"__TOTAL_WORDS__={total_words}")

if total_files > 200 or total_words > 2000000:
    print("WARNING_LARGE_CORPUS")
    # print top 5 subdirs
    import os
    from collections import Counter
    all_files = [f for cat_files in files.values() for f in cat_files]
    dirs = Counter(os.path.dirname(f) for f in all_files if os.path.dirname(f))
    for d, c in dirs.most_common(5):
        print(f"  {d}: {c} files")

