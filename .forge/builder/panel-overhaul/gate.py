# The ES5 / callback-contract gate the audit used, as one command.
#   python .forge/builder/panel-overhaul/gate.py
# 1. extracts the panel's script block and runs `node --check` on it
# 2. greps it for ES2015+ syntax CEF 88 would choke on
# 3. lists every sketchup.* call in the JS and every add_action_callback in
#    main.rb, and fails if the two sets differ
import os, re, subprocess, sys
ROOT = "C:/Users/bento/OneDrive/Documents/Claude/Sketchup/WhisperRoom-SketchUp"
WT = ROOT + "/scripts/wr_tools"
html = open(WT + "/panel.html", encoding="utf-8").read()
m = re.search(r"<script>\n(.*?)</script>", html, re.S)
js = m.group(1)
out = ROOT + "/.forge/builder/panel-overhaul/panel-script.js"
open(out, "w", encoding="utf-8").write(js)
r = subprocess.run(["node", "--check", out], capture_output=True, text=True)
print("node --check:", "clean" if r.returncode == 0 else r.stderr)
bad = []
for i, line in enumerate(js.splitlines(), 1):
    code = line.split("//")[0]
    if "=>" in code: bad.append((i, "arrow"))
    if "`" in code: bad.append((i, "template literal"))
    if re.search(r"\b(const|let)\s+[A-Za-z_$]", code): bad.append((i, "const/let"))
    if "?." in code: bad.append((i, "optional chaining"))
    if "??" in code: bad.append((i, "nullish"))
    if re.search(r"\.includes\(", code): bad.append((i, "Array.includes"))
print("ES2015+ syntax:", bad or "none")
calls = sorted(set(re.findall(r"sketchup\.([a-z]+)\(", js)))
rb = open(WT + "/main.rb", encoding="utf-8").read()
cbs = sorted(set(re.findall(r"add_action_callback\('([a-z]+)'", rb)))
print("JS calls   (%d): %s" % (len(calls), " ".join(calls)))
print("Ruby cbs   (%d): %s" % (len(cbs), " ".join(cbs)))
missing = [c for c in calls if c not in cbs]
unused = [c for c in cbs if c not in calls]
print("called but not registered:", missing or "none")
print("registered but never called:", unused or "none")
sys.exit(1 if (r.returncode or bad or missing or unused) else 0)
