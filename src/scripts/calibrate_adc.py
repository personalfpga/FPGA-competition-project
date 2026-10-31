"""Check gain feasibility from SIGNAL-GENERATOR samples, not human recordings.

CSV columns: raw_code,region; region is baseline/R/T/noise.
Each raw_code must be a real 12-bit ADC reading before digital conditioning.
Output is a provisional Q8 setting. Validate it again with the DC tracker and
the core's four-sample filter enabled before building a final bitstream.
"""
import argparse
import csv
import json
import math
from pathlib import Path
from statistics import median

def calibrate(rows, input_r_mv=None):
    groups={k:[] for k in ('baseline','R','T','noise')}
    for row in rows:
        code=int(row['raw_code'])
        if not 0<=code<=4095: raise ValueError('raw_code must be 0..4095')
        region=row['region'].strip()
        if region not in groups: raise ValueError('region must be baseline/R/T/noise')
        groups[region].append(code)
    if any(not v for v in groups.values()): raise ValueError('All four regions are required')
    if any(c in (0,4095) for v in groups.values() for c in v):
        raise ValueError('Raw ADC clips at 0/4095; correct the analog path first')
    baseline=median(groups['baseline'])
    # Use weakest tagged R amplitude and largest positive T/noise deviation.
    r_delta=min(groups['R'])-baseline
    interference=max(0,max(groups['T']+groups['noise'])-baseline)
    if r_delta<=0: raise ValueError('R wave must be positive relative to baseline')
    # Match RTL symmetric rounding: output >4000 => round(delta*g)>=3001.
    low=max(1,math.ceil(3000.5*256/r_delta))
    high=65535 if interference==0 else min(65535, math.ceil(1500.5*256/interference)-1)
    if low>high: raise ValueError('No Q8 gain can satisfy R>4000 and T/noise<=2500 for these samples')
    chosen=low
    def mapped(delta):
        v=delta*chosen/256
        rounded=math.floor(v+0.5) if v>=0 else -math.floor(-v+0.5)
        return max(0,min(4095,1000+rounded))
    result={'baseline_raw':baseline, 'weakest_r_delta_raw':r_delta,
            'max_t_noise_delta_raw':interference, 'gain_q8_min':low, 'gain_q8_max':high,
            'recommended_ADC_GAIN_Q8':chosen, 'gain_multiplier':chosen/256,
            'predicted_weakest_R':mapped(r_delta), 'predicted_max_T_noise':mapped(interference),
            'status':'candidate_requires_generator_validation',
            'warning':'Extrema labels must cover R peaks and T/noise maxima; account for tracker drift, filter attenuation and margin.'}
    if input_r_mv is not None:
        if not math.isfinite(input_r_mv) or input_r_mv<=0: raise ValueError('input_r_mv must be positive')
        counts_per_mv=r_delta/input_r_mv
        q8=round(2000/counts_per_mv*256)
        result.update({'measured_raw_counts_per_mV':counts_per_mv,
                       'target_2000_counts_per_mV_gain_q8':q8,
                       'target_2000_within_peak_bounds':low<=q8<=high})
    return result

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('csv',type=Path)
    ap.add_argument('--input-r-mv',type=float,help='Known generator R amplitude in mV at front-end input')
    ap.add_argument('--out',type=Path)
    a=ap.parse_args()
    try:
        with a.csv.open(encoding='utf-8-sig',newline='') as f:
            result=calibrate(csv.DictReader(f), a.input_r_mv)
    except (ValueError,KeyError,OSError) as e: ap.error(str(e))
    text=json.dumps(result,ensure_ascii=False,indent=2)
    print(text)
    if a.out: a.out.write_text(text,encoding='utf-8')

if __name__=='__main__': main()
