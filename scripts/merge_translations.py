#!/usr/bin/env python3
"""把 /tmp/l10n/out/*.tsv（key + 26 语言）合并进 Localizable.xcstrings。

TSV 列顺序固定，第一列是 key，其余 26 列依次对应 LANGS。
缺失语言或占位符不一致会直接报错，不写盘。
"""
import json, os, re, sys, glob, collections

LANGS = ["en-GB","es","es-419","fr","fr-CA","de","it","pt-PT","nl","pl","sv","da",
         "nb","fi","ru","uk","tr","ar","he","hi","id","ms","vi","th","ko","zh-Hant"]

BASE = "/Volumes/my_data/qr-scan"
XC = f"{BASE}/LeitorQR/Resources/Localizable.xcstrings"
OUT = "/tmp/l10n/out"
PH = re.compile(r"%(?:\d+\$)?[@d]")

def main():
    todo = {i["k"]: i for i in json.load(open("/tmp/l10n/todo.json"))}
    produced = {}
    files = sorted(glob.glob(f"{OUT}/*.tsv"))
    if not files:
        sys.exit("no tsv files")
    for path in files:
        for ln, line in enumerate(open(path, encoding="utf-8-sig"), 1):
            line = line.rstrip("\n")
            if not line.strip():
                continue
            cols = line.split("\t")
            if len(cols) != len(LANGS) + 1:
                sys.exit(f"{path}:{ln} 列数 {len(cols)} != {len(LANGS)+1}")
            key, vals = cols[0], cols[1:]
            if key not in todo:
                sys.exit(f"{path}:{ln} 未知 key {key!r}")
            if key in produced:
                sys.exit(f"{path}:{ln} 重复 key {key!r}")
            for lang, v in zip(LANGS, vals):
                if not v.strip():
                    sys.exit(f"{path}:{ln} {key} [{lang}] 为空")
            # 占位符必须与 en 完全一致
            en_ph = sorted(PH.findall(todo[key]["en"]))
            for lang, v in zip(LANGS, vals):
                ph = sorted(PH.findall(v))
                if ph != en_ph:
                    sys.exit(f"{path}:{ln} {key} [{lang}] 占位符 {ph} != {en_ph}")
            produced[key] = {l: v.replace("\\n", "\n") for l, v in zip(LANGS, vals)}

    missing = sorted(set(todo) - set(produced))
    if missing:
        print(f"⚠️  未覆盖 {len(missing)} 条（先只合并已有部分）:", file=sys.stderr)
        for k in missing[:20]:
            print("   ", k, file=sys.stderr)

    d = json.load(open(XC), object_pairs_hook=collections.OrderedDict)
    added = 0
    for key, per_lang in produced.items():
        entry = d["strings"].setdefault(key, collections.OrderedDict(
            [("extractionState", "manual"), ("localizations", collections.OrderedDict())]))
        locs = entry["localizations"]
        for lang, val in per_lang.items():
            locs[lang] = collections.OrderedDict([
                ("stringUnit", collections.OrderedDict([("state", "translated"), ("value", val)]))
            ])
            added += 1
    # 语言按字母序稳定排列
    for entry in d["strings"].values():
        locs = entry.get("localizations")
        if locs:
            entry["localizations"] = collections.OrderedDict(sorted(locs.items()))
    with open(XC, "w", encoding="utf-8") as f:
        json.dump(d, f, ensure_ascii=False, indent=2)
    print(f"OK: 合并 {len(produced)} 条 key / {added} 条译文；未覆盖 {len(missing)} 条")

if __name__ == "__main__":
    main()
