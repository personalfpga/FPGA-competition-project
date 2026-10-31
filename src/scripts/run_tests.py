"""Run reproducible RTL regressions. Needs Icarus Verilog and numpy."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
from privacy import sanitize_text

ROOT = Path(__file__).resolve().parents[2]

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument('--iverilog', default=shutil.which('iverilog'))
    ap.add_argument('--vvp', default=shutil.which('vvp'))
    ap.add_argument('--build-dir', type=Path, default=ROOT/'simulation_work')
    ap.add_argument('--reuse-logs', action='store_true', help='Recheck existing logs without rerunning completed tests')
    a = ap.parse_args()
    if not a.iverilog or not a.vvp:
        ap.error('Set --iverilog and --vvp to the installed executable paths')
    a.build_dir.mkdir(parents=True, exist_ok=True)
    out = ROOT/'build/reports'/'simulation'
    out.mkdir(parents=True, exist_ok=True)
    common = [str(p) for p in sorted((ROOT/'src/rtl').glob('*.v'))]
    common += [str(ROOT/'sim/bufgce_model_sim_only.v'), str(ROOT/'sim/xadc_vpvn_sim_model.v')]
    env = dict(os.environ)
    env['PATH'] = str(Path(a.iverilog).parent) + os.pathsep + env.get('PATH', '')
    results = []
    def run(name, top, params=(), must_contain=None):
        existing=out/(name+'.log')
        if a.reuse_logs and existing.exists():
            log=existing.read_text(encoding='utf-8')
            if not re.search(r'FAIL|FATAL|ERROR',log) and must_contain in log:
                lines=[s for s in log.splitlines() if 'PASS' in s or s.startswith('MODE=') or s.startswith('CLOCK:')]
                results.append({'test':name,'status':'PASS','summary':lines})
                print(name,'PASS (rechecked existing log)',flush=True)
                return
        binary = a.build_dir/(name+'.vvp')
        tb = ROOT/'sim'/(top+('.v' if top in ('ecg_tb', 'ecg_mode_tb') else '.sv'))
        command = [a.iverilog, '-g2012', '-s', top, '-o', str(binary)]
        command += [f'-P{top}.{k}={v}' for k,v in params]
        command += [str(tb), *common]
        compile_run = subprocess.run(command, capture_output=True, text=True, env=env)
        (out/(name+'_compile.log')).write_text(sanitize_text(compile_run.stdout+compile_run.stderr), encoding='utf-8')
        compile_run.check_returncode()
        sim = subprocess.run([a.vvp, str(binary)], capture_output=True, text=True, env=env, timeout=180)
        log = sanitize_text(sim.stdout + sim.stderr)
        (out/(name+'.log')).write_text(log, encoding='utf-8')
        sim.check_returncode()
        if re.search(r'FAIL|FATAL|ERROR', log) or (must_contain and must_contain not in log):
            raise RuntimeError(name+' failed; see '+str(out/(name+'.log')))
        lines = [s for s in log.splitlines() if 'PASS' in s or s.startswith('MODE=') or s.startswith('CLOCK:')]
        results.append({'test': name, 'status': 'PASS', 'summary': lines})
        print(name, 'PASS', ' | '.join(lines), flush=True)
    run('conditioner', 'conditioner_tb', must_contain='CONDITIONER_PASS')
    run('reader', 'xadc_reader_tb', must_contain='XADC_READER_PASS')
    run('adc_integration', 'adc_integration_tb', must_contain='ADC_INTEGRATION_PASS')
    run('adc_integration_gain30', 'adc_integration_tb', [('GAIN_Q8',7680)], must_contain='ADC_INTEGRATION_PASS')
    run('power_variants', 'power_variants_tb', must_contain='POWER_VARIANTS_PASS')
    run('legacy', 'ecg_tb', must_contain='ECG_TEST_PASS')
    for mode in range(7):
        run(f'mode{mode}', 'ecg_mode_tb', [('MODE',mode)], must_contain=f'MODE={mode}')
    # Compare TWO complete loops, not just events up to the last reported peak.
    import numpy as np
    import csv
    sys.path.insert(0, str(ROOT/'src/scripts'))
    for mode in (8,9):
        run(f'mode{mode}', 'ecg_mode_tb', [('MODE',mode),('RUN_MS',62000),('PRINT_PEAKS',1)], must_contain=f'MODE={mode}')
        log = (out/f'mode{mode}.log').read_text()
        sim = np.array([int(x) for x in re.findall(r'RPEAK ms=(\d+)',log)])
        with (ROOT/'sim/ecg_rom.v.counts.csv').open() as f:
            data = np.array([int(r['counts']) for r in csv.DictReader(f) if r['slot']==str(mode-8)], dtype=np.int64)
        x = np.tile(data, 3)[:62000]
        sums = np.zeros(len(x), dtype=np.int64)
        for d in range(1,5): sums[d:] += x[:-d]
        filt = np.zeros(len(x), dtype=np.int64)
        filt[1:] = sums[:-1] >> 2
        model=[]
        for idx in np.flatnonzero(filt>2500):
            if not model or idx-model[-1]>=251: model.append(int(idx))
        offsets = sorted(set(int(s-p) for s,p in zip(sim,model)))
        reported=int(re.search(r'rpeaks=(\d+)',log).group(1))
        if reported!=len(sim):raise RuntimeError('R peak summary must count rising edges')
        if len(sim)!=len(model) or offsets!=[2]:
            raise RuntimeError(f'ROM {mode}: sim={len(sim)} model={len(model)} offsets={offsets}')
        # Explicit mode scenarios: flat must remain asleep; ROM must be active.
        summary=f'ROM_REPLAY_PASS mode={mode} sim={len(sim)} model={len(model)} constant_offset_ms={offsets[0]} duration_ms=62000'
        print(summary, flush=True)
        results.append({'test':f'rom_exact_{mode}', 'status':'PASS', 'summary':[summary]})
    for mode in range(7):
        text=(out/f'mode{mode}.log').read_text()
        summary=next(s for s in text.splitlines() if s.startswith('MODE='))
        row=dict(re.findall(r'(\w+)=(-?\d+)', summary))
        if int(row['ms'])!=20000: raise RuntimeError('Incomplete mode test')
        if mode in (4,6) and (int(row['hr_max'])!=0 or int(row['trans'])!=0):
            raise RuntimeError('Flat/noise-only signal produced HR or woke core')
        expected={0:75,1:120,2:45,5:75}.get(mode)
        if expected and (int(row['hr_min'])!=expected or int(row['hr_max'])!=expected):
            raise RuntimeError(f'Mode {mode} has unexpected HR')
    (out/'results.json').write_text(json.dumps(results, indent=2), encoding='utf-8')
    print('ALL_TESTS_PASS', flush=True)

if __name__=='__main__': main()
