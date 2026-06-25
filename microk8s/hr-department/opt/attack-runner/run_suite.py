#!/usr/bin/env python3
import json
import os
import random
import shlex
import subprocess
import time
import uuid
from datetime import datetime, timezone


TESTS_PATH = os.getenv("TESTS_PATH", "/opt/tests.json")
GT_PATH = os.getenv("GT_PATH", "/opt/out/gt.jsonl")
SAMPLES_PER_RUN = int(os.getenv("SAMPLES_PER_RUN", "20"))
WAIT_AFTER_S = float(os.getenv("WAIT_AFTER_S", "8"))


def now_iso():
    return datetime.now(timezone.utc).isoformat(timespec="milliseconds")


def load_tests(path):
    with open(path, "r", encoding="utf-8") as f:
        return json.load(f)


def choose_tests(tests, n):
    if n <= len(tests):
        selected = tests[:]
        random.shuffle(selected)
        return selected[:n]

    return [random.choice(tests) for _ in range(n)]


def run_test(test):
    test_id = str(uuid.uuid4())[:8]

    cmd = test["cmd"].replace("{TEST_ID}", test_id)
    timeout_s = int(test.get("timeout_s", 60))

    start_ts = now_iso()

    print(f"[test] {test.get('class')} | {test.get('tool')} | {test.get('variant')}")
    print(f"[cmd] {cmd}")

    try:
        result = subprocess.run(
            cmd,
            shell=True,
            timeout=timeout_s,
            stdout=subprocess.DEVNULL,
            stderr=subprocess.DEVNULL,
        )
        exit_code = result.returncode
        error = None

    except subprocess.TimeoutExpired:
        exit_code = 124
        error = "timeout"

    except Exception as e:
        exit_code = 1
        error = str(e)

    end_ts = now_iso()

    gt = {
        "test_id": test_id,
        "tool": test.get("tool"),
        "variant": test.get("variant"),
        "class": test.get("class"),
        "target": test.get("target"),
        "target_label": test.get("target_label"),
        "ports": test.get("ports", []),
        "proto": test.get("proto"),
        "cmd": cmd,
        "timeout_s": timeout_s,
        "start_ts": start_ts,
        "end_ts": end_ts,
        "exit_code": exit_code,
    }

    if error:
        gt["error"] = error

    with open(GT_PATH, "a", encoding="utf-8") as f:
        f.write(json.dumps(gt, ensure_ascii=False) + "\n")

    print(f"[done] exit_code={exit_code} test_id={test_id}")

    if WAIT_AFTER_S > 0:
        time.sleep(WAIT_AFTER_S)


def main():
    os.makedirs(os.path.dirname(GT_PATH), exist_ok=True)

    tests = load_tests(TESTS_PATH)
    selected = choose_tests(tests, SAMPLES_PER_RUN)

    print(f"[suite] tests_path={TESTS_PATH}")
    print(f"[suite] gt_path={GT_PATH}")
    print(f"[suite] samples={len(selected)}")
    print(f"[suite] wait_after_s={WAIT_AFTER_S}")

    for i, test in enumerate(selected, 1):
        print(f"[suite] running {i}/{len(selected)}")
        run_test(test)

    print("[suite] completed")


if __name__ == "__main__":
    main()
