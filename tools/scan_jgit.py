import zipfile, os, sys, json
roots = ["/work/ide/pycharm-2026.2.4"]
hits = []
scanned = 0
failed = []
for root in roots:
    for dirpath, dirnames, filenames in os.walk(root):
        for fn in filenames:
            if not fn.endswith(".jar"):
                continue
            p = os.path.join(dirpath, fn)
            try:
                with zipfile.ZipFile(p) as z:
                    scanned += 1
                    names = z.namelist()
            except Exception as e:
                failed.append((p, str(e)))
                continue
            jgit = [n for n in names if "jgit" in n.lower()]
            if jgit:
                hits.append((p, len(jgit), jgit[:5]))
print(json.dumps({"scanned": scanned, "failed": failed, "hits": hits}, indent=1))
