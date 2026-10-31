from pathlib import Path
import hashlib,json
root=Path(__file__).resolve().parents[2]
m=json.loads((root/'release_manifest.json').read_text())
for p,h in m['file_sha256'].items():
    assert hashlib.sha256((root/p).read_bytes()).hexdigest()==h,p
assert (root/'build/bitstreams/mode7_release.bit').read_bytes()==(root/'build/bitstreams/gated_release.bit').read_bytes()
print('PACKAGE_HASHES_AND_BIT_IDENTITY_PASS',len(m['file_sha256']))

if (root/'build/reports/simulation/results.json').is_file():
    results=json.loads((root/'build/reports/simulation/results.json').read_text())
    assert len(results)==17 and all(r['status']=='PASS' for r in results)
    for tag in ('baseline','fsm_only','gated','adc','mode8','mode9'):
        proof=(root/f'build/reports/{tag}/release_checks.txt').read_text()
        assert 'vivado=2025.2' in proof and 'debug_cells=0' in proof and 'DRC_errors=0' in proof
    print('ARCHIVED_RELEASE_CONDITIONS_PASS; no fresh synthesis or simulation claimed')
board=json.loads((root/'board/xadc_20261013/verification_result.json').read_text())
assert board['samples']==4096 and board['min_code']==4 and board['max_code']==3033
print('SAVED_BOARD_SUMMARY_SCOPE_PASS')
