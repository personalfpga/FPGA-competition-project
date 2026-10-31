#!/usr/bin/env python3
"""Compare the R peaks printed by the simulation (RPEAK lines) with the bit-exact software model
on the same ROM samples. usage: python check_rom_replay.py r8.txt ecg_rom.v.counts.csv [slot]"""
import re, sys, csv
import numpy as np
def hw_peaks(x):
    x = np.asarray(x, dtype=np.int64); n = len(x); s = np.zeros(n, dtype=np.int64)
    for d in range(1, 5): s[d:] += x[:n - d]
    f = np.zeros(n, dtype=np.int64); f[1:] = s[:-1] >> 2
    pk, last = [], -10**9
    for i in np.flatnonzero(f > 2500):
        if i >= last + 251: pk.append(i); last = i
    return np.array(pk)
SLOT = sys.argv[3] if len(sys.argv) > 3 else "0"
sim = [int(a) for a in re.findall(r"RPEAK ms=(\d+)", open(sys.argv[1]).read())]
c = np.array([int(r["counts"]) for r in csv.DictReader(open(sys.argv[2])) if r["slot"] == SLOT])
last_ms = max(sim)
mp = hw_peaks(np.tile(c, last_ms // len(c) + 2)); mp = mp[mp <= last_ms]
n = min(len(mp), len(sim))
off = set(int(s - p) for s, p in zip(sim[:n], mp[:n]))
ok = (len(sim) == len(mp)) and len(off) == 1
print(f"RPEAK_CHECK: sim={len(sim)} model={len(mp)} offsets_ms={sorted(off)} -> {'PASS' if ok else 'FAIL'}")
sys.exit(0 if ok else 1)
