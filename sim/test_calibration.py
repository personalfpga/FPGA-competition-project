import importlib.util
import json
from pathlib import Path
root=Path(__file__).resolve().parents[1]
spec=importlib.util.spec_from_file_location('cal',root/'scripts/calibrate_adc.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
def rows(r=120,t=20,n=5):
    return [{'raw_code':1475+d,'region':label} for label,d in [('baseline',0),('baseline',0),('R',r),('R',r+3),('T',t),('noise',n)]]
a=m.calibrate(rows(),1.5)
assert a['predicted_weakest_R']>4000 and a['predicted_max_T_noise']<=2500
assert a['target_2000_counts_per_mV_gain_q8']==6400
for bad in [rows(r=30,t=25), [{'raw_code':4095,'region':'baseline'}],rows(r=-10),rows()[:-1]]:
    try:m.calibrate(bad)
    except ValueError:pass
    else:raise AssertionError('bad input accepted')
# Compare all feasible integer settings against actual RTL rounding for edge cases.
for r,t in [(120,20),(102,50),(100,50),(409,1),(20,0)]:
    try:a=m.calibrate(rows(r,t,0))
    except ValueError:
        assert not any(1000+(r*g+128)//256>4000 and 1000+(t*g+128)//256<=2500 for g in range(65536))
        continue
    for g in (a['gain_q8_min'],a['gain_q8_max']):
        assert 1000+(r*g+128)//256>4000 and 1000+(t*g+128)//256<=2500
print('CALIBRATION_TOOL_PASS feasible_gain_bounds=PASS rounding_boundaries=PASS invalid_inputs=PASS')
(root/'reports').mkdir(exist_ok=True)
(root/'reports/calibration_tool_test.txt').write_text('CALIBRATION_TOOL_PASS feasible_gain_bounds=PASS rounding_boundaries=PASS invalid_inputs=PASS\nSynthetic test vectors only; no generator measurements.\n',encoding='utf-8')
