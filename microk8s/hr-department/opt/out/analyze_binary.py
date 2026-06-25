
#!/usr/bin/env python3
import json, sys, re
from datetime import datetime, timedelta
from collections import defaultdict

def parse_ts(s):
    m = re.search(r'([+-]\d{2})(\d{2})$', s)
    if m and ":" not in s[-6:]:
        s = s[:-5] + f"{m.group(1)}:{m.group(2)}"
    return datetime.fromisoformat(s)

def load_jsonl(path):
    with open(path) as f:
        for line in f:
            line=line.strip()
            if line:
                try: yield json.loads(line)
                except: pass

def analyze_binary(gt_path, eve_path, slack_s=12, include_failed=False, target=None):
    gt = [t for t in load_jsonl(gt_path)]
    if target:
        gt = [t for t in gt if t.get("target")==target]
    alerts = [e for e in load_jsonl(eve_path) if e.get("event_type")=="alert"]

    idx = defaultdict(list)
    for e in alerts:
        try: ts = parse_ts(e["timestamp"])
        except: continue
        try: k = (e.get("dest_ip"), int(e.get("dest_port", -1)))
        except: continue
        idx[k].append(ts)

    slack = timedelta(seconds=slack_s)
    cm = {"TP":0,"FP":0,"TN":0,"FN":0}
    per = {"malicious":{"N":0,"hit":0}, "benign":{"N":0,"hit":0}}

    for t in gt:
        if not include_failed and int(t.get("exit_code", 0)) != 0:
            continue
        label = "benign" if str(t.get("class","")).startswith("benign:") else "malicious"
        target_ip = t.get("target")
        ports = [int(p) for p in t.get("ports",[])]
        start = parse_ts(t["start_ts"]); end = parse_ts(t["end_ts"]) + slack
        hit = any(any(start <= ts <= end for ts in idx.get((target_ip, p), [])) for p in ports)
        per[label]["N"] += 1
        per[label]["hit"] += 1 if hit else 0
        if label=="malicious":
            cm["TP" if hit else "FN"] += 1
        else:
            cm["FP" if hit else "TN"] += 1

    def safe(a,b): return a/b if b else 0.0
    acc = safe(cm["TP"]+cm["TN"], sum(cm.values()))
    prec= safe(cm["TP"], cm["TP"]+cm["FP"])
    rec = safe(cm["TP"], cm["TP"]+cm["FN"])
    f1  = safe(2*prec*rec, prec+rec) if (prec+rec)>0 else 0.0

    print("Counts:", cm)
    print("Per-label:", per)
    print(f"accuracy={acc:.3f} precision={prec:.3f} recall={rec:.3f} f1={f1:.3f}")

if __name__ == "__main__":
    if len(sys.argv) < 3:
        print("Usage: analyze_binary.py <gt.jsonl> <eve_attacker.jsonl> [slack_s] [target_ip]")
        sys.exit(1)
    gt, eve = sys.argv[1], sys.argv[2]
    slack = int(sys.argv[3]) if len(sys.argv)>3 else 12
    target = sys.argv[4] if len(sys.argv)>4 else None
    analyze_binary(gt, eve, slack_s=slack, target=target)
