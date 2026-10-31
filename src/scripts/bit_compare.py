from pathlib import Path
import hashlib
r=Path(__file__).resolve().parents[2]/'build/bitstreams'
assert (r/'mode7_release.bit').read_bytes()==(r/'gated_release.bit').read_bytes()
for p in sorted(r.glob('*.bit')):print(p.name,hashlib.sha256(p.read_bytes()).hexdigest())
