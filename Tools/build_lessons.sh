#!/bin/sh
set -e
cd "$(dirname "$0")/.."
OUT=Sources/Resources/lessons.json
python3 Tools/svg_to_lesson.py "$OUT.tmp" Lessons/src/*.svg
python3 - "$OUT.tmp" Sources/Resources/catalog.json <<'PY'
import json, sys
lessons = {l["id"]: l for l in json.load(open(sys.argv[1]))}
for course in json.load(open(sys.argv[2]))["courses"]:
    for ref in course["lessons"]:
        l = lessons.get(ref["lessonId"])
        assert l, f"catalog references missing lesson {ref['lessonId']}"
        assert l["version"] == ref["contentVersion"], f"version mismatch for {ref['lessonId']}"
print("  catalog OK")
PY
mv "$OUT.tmp" "$OUT"
echo "wrote $OUT"
