from pathlib import Path
import json,re
root=Path(__file__).resolve().parents[2]
def val(text,label):
    m=re.search(r'\|\s*'+re.escape(label)+r'\s*\|\s*([0-9.]+)',text)
    if not m:raise ValueError(label)
    return float(m[1])
rows={}
for tag in ('baseline','fsm_only','gated','adc','mode8','mode9'):
    folder=root/'build/reports'/tag
    util=(folder/'utilization.rpt').read_text();power=(folder/'power_estimate.rpt').read_text()
    proof=(folder/'release_checks.txt').read_text()
    assert 'vivado=2025.2' in proof and 'debug_cells=0' in proof and 'DRC_errors=0' in proof
    rows[tag]={'luts':val(util,'Slice LUTs'),'registers':val(util,'Slice Registers'),'bram':val(util,'Block RAM Tile'),'dsp':val(util,'DSPs'),'dynamic_w':val(power,'Dynamic (W)'),'total_w':val(power,'Total On-Chip Power (W)')}
out=root/'report';out.mkdir(exist_ok=True)
(out/'resource_power_values.json').write_text(json.dumps(rows,indent=2))
print('REPORT_VALUES_RECALCULATED',len(rows))
